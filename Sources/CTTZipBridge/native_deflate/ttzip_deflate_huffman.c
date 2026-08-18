// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_huffman.c
 * @brief RFC 1951 Canonical Huffman code generators, headers, and lookup tables.
 * @details Implements Van Leeuwen / Moffat-Katajainen in-place package merge tree
 *          generation and standard RFC 1951 dynamic header RLE stream encoding.
 */

#include "ttzip_deflate_huffman.h"
#include "../include/ttzip_huffman_inplace.h"
#include <string.h>

#if defined(__arm64__) || defined(__aarch64__)
static inline uint32_t ttzip_reverse_bits32(uint32_t v) {
    uint32_t r;
    __asm__("rbit %w0, %w1" : "=r"(r) : "r"(v));
    return r;
}
#else
static inline uint32_t ttzip_reverse_bits32(uint32_t v) {
    v = ((v & 0x55555555U) << 1) | ((v >> 1) & 0x55555555U);
    v = ((v & 0x33333333U) << 2) | ((v >> 2) & 0x33333333U);
    v = ((v & 0x0F0F0F0FU) << 4) | ((v >> 4) & 0x0F0F0F0FU);
    v = ((v & 0x00FF00FFU) << 8) | ((v >> 8) & 0x00FF00FFU);
    return (v << 16) | (v >> 16);
}
#endif

/* Process-wide static RFC 1951 Huffman code singleton */
static ttzip_huffman_codes_t s_static_codes;
static bool s_static_initialized = false;

static void init_static_codes(void) {
    if (s_static_initialized) return;
    memset(&s_static_codes, 0, sizeof(s_static_codes));

    /* Literal/Length fixed bit lengths (RFC 1951 section 3.2.6) */
    /* 0..143: 8 bits */
    for (int i = 0; i <= 143; i++) s_static_codes.lens_litlen[i] = 8;
    /* 144..255: 9 bits */
    for (int i = 144; i <= 255; i++) s_static_codes.lens_litlen[i] = 9;
    /* 256..279: 7 bits */
    for (int i = 256; i <= 279; i++) s_static_codes.lens_litlen[i] = 7;
    /* 280..287: 8 bits */
    for (int i = 280; i <= 287; i++) s_static_codes.lens_litlen[i] = 8;

    /* Distance fixed bit lengths: 5 bits across all 32 symbols */
    for (int i = 0; i < 32; i++) s_static_codes.lens_offset[i] = 5;

    /* Generate Canonical codewords for literal/length symbols */
    uint16_t next_code[16];
    uint16_t count[16];

    memset(count, 0, sizeof(count));
    for (int i = 0; i < 288; i++) count[s_static_codes.lens_litlen[i]]++;
    uint16_t code = 0;
    count[0] = 0;
    for (int bits = 1; bits <= 15; bits++) {
        code = (code + count[bits - 1]) << 1;
        next_code[bits] = code;
    }
    for (int i = 0; i < 288; i++) {
        uint8_t len = s_static_codes.lens_litlen[i];
        if (len > 0) {
            uint32_t c = next_code[len]++;
            s_static_codes.codewords_litlen[i] = ttzip_reverse_bits32(c) >> (32 - len);
        }
    }

    /* Generate Canonical codewords for distance symbols */
    memset(count, 0, sizeof(count));
    for (int i = 0; i < 32; i++) count[s_static_codes.lens_offset[i]]++;
    code = 0;
    count[0] = 0;
    for (int bits = 1; bits <= 15; bits++) {
        code = (code + count[bits - 1]) << 1;
        next_code[bits] = code;
    }
    for (int i = 0; i < 32; i++) {
        uint8_t len = s_static_codes.lens_offset[i];
        if (len > 0) {
            uint32_t c = next_code[len]++;
            s_static_codes.codewords_offset[i] = ttzip_reverse_bits32(c) >> (32 - len);
        }
    }

    s_static_initialized = true;
}

const ttzip_huffman_codes_t *ttzip_get_static_huffman_codes(void) {
    if (!s_static_initialized) {
        init_static_codes();
    }
    return &s_static_codes;
}

/* In-Place 2-Queue length-limited Canonical Huffman construction (Van Leeuwen 1976 / Moffat-Katajainen 1995) */
void ttzip_build_canonical_huffman_tree(const uint32_t *freqs,
                                        unsigned num_syms,
                                        unsigned max_codeword_len,
                                        uint8_t *lens_out,
                                        uint32_t *codewords_out) {
    uint32_t work[320];
    uint32_t *cw = codewords_out ? codewords_out : work;
    ttzip_make_canonical_huffman_code_inplace(num_syms, max_codeword_len, freqs, lens_out, cw, true);
}

static const uint8_t s_precode_permutation[19] = {
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
};

/* Encodes RFC 1951 dynamic Huffman tree header */
void ttzip_write_dynamic_huffman_header(ttzip_bitstream_t *bs,
                                        const uint8_t *lens_litlen,
                                        unsigned num_litlen_syms,
                                        const uint8_t *lens_offset,
                                        unsigned num_offset_syms) {
    /* 1. Trim trailing zero-length codewords */
    while (num_litlen_syms > 257 && lens_litlen[num_litlen_syms - 1] == 0) {
        num_litlen_syms--;
    }
    while (num_offset_syms > 1 && lens_offset[num_offset_syms - 1] == 0) {
        num_offset_syms--;
    }

    /* Merge codeword bit length arrays */
    uint8_t combined_lens[320];
    unsigned num_combined = num_litlen_syms + num_offset_syms;
    memcpy(combined_lens, lens_litlen, num_litlen_syms);
    memcpy(combined_lens + num_litlen_syms, lens_offset, num_offset_syms);

    /* 2. Run-Length Encode (RLE) the combined code lengths */
    uint8_t rle_syms[320];
    uint8_t rle_extra_bits[320];
    uint8_t rle_extra_vals[320];
    unsigned num_rle = 0;
    uint32_t precode_freqs[19];
    memset(precode_freqs, 0, sizeof(precode_freqs));

    unsigned i = 0;
    while (i < num_combined) {
        uint8_t len = combined_lens[i];
        unsigned run = 1;
        while (i + run < num_combined && combined_lens[i + run] == len) {
            run++;
        }

        if (len == 0) {
            if (run >= 11) {
                unsigned chunk = (run > 138) ? 138 : run;
                rle_syms[num_rle] = 18;
                rle_extra_bits[num_rle] = 7;
                rle_extra_vals[num_rle] = (uint8_t)(chunk - 11);
                precode_freqs[18]++;
                num_rle++;
                i += chunk;
            } else if (run >= 3) {
                rle_syms[num_rle] = 17;
                rle_extra_bits[num_rle] = 3;
                rle_extra_vals[num_rle] = (uint8_t)(run - 3);
                precode_freqs[17]++;
                num_rle++;
                i += run;
            } else {
                rle_syms[num_rle] = 0;
                rle_extra_bits[num_rle] = 0;
                rle_extra_vals[num_rle] = 0;
                precode_freqs[0]++;
                num_rle++;
                i++;
            }
        } else {
            rle_syms[num_rle] = len;
            rle_extra_bits[num_rle] = 0;
            rle_extra_vals[num_rle] = 0;
            precode_freqs[len]++;
            num_rle++;
            i++;
            while (run > 1) {
                unsigned chunk = (run - 1 > 6) ? 6 : (run - 1);
                if (chunk >= 3) {
                    rle_syms[num_rle] = 16;
                    rle_extra_bits[num_rle] = 2;
                    rle_extra_vals[num_rle] = (uint8_t)(chunk - 3);
                    precode_freqs[16]++;
                    num_rle++;
                    i += chunk;
                    run -= chunk;
                } else {
                    rle_syms[num_rle] = len;
                    rle_extra_bits[num_rle] = 0;
                    rle_extra_vals[num_rle] = 0;
                    precode_freqs[len]++;
                    num_rle++;
                    i++;
                    run--;
                }
            }
        }
    }

    /* 3. Build Precode Canonical tree (max depth 7) */
    uint8_t precode_lens[19];
    uint32_t precode_codewords[19];
    ttzip_build_canonical_huffman_tree(precode_freqs, 19, TTZIP_DEFLATE_MAX_PRECODE_LEN, precode_lens, precode_codewords);

    /* Determine HCLEN */
    unsigned hclen = 19;
    while (hclen > 4 && precode_lens[s_precode_permutation[hclen - 1]] == 0) {
        hclen--;
    }

    /* 4. Emit dynamic tree header bits */
    /* HLIT (5 bits): num_litlen_syms - 257 */
    ttzip_bs_write_bits(bs, num_litlen_syms - 257, 5);
    /* HDIST (5 bits): num_offset_syms - 1 */
    ttzip_bs_write_bits(bs, num_offset_syms - 1, 5);
    /* HCLEN (4 bits): hclen - 4 */
    ttzip_bs_write_bits(bs, hclen - 4, 4);

    /* Emit Precode code lengths */
    for (unsigned k = 0; k < hclen; k++) {
        ttzip_bs_write_bits(bs, precode_lens[s_precode_permutation[k]], 3);
    }

    /* Emit RLE code lengths stream */
    for (unsigned k = 0; k < num_rle; k++) {
        uint8_t sym = rle_syms[k];
        ttzip_bs_write_bits(bs, precode_codewords[sym], precode_lens[sym]);
        if (rle_extra_bits[k] > 0) {
            ttzip_bs_write_bits(bs, rle_extra_vals[k], rle_extra_bits[k]);
        }
    }
}

bool ttzip_eval_huffman_bit_costs(
    const ttzip_symbol_freqs_t *freqs,
    const uint8_t *dynamic_lens_litlen,
    const uint8_t *dynamic_lens_offset,
    uint64_t *out_static_bits,
    uint64_t *out_dynamic_bits
) {
    if (!freqs) return false;

    uint64_t static_bits = 0;
    for (int i = 0; i <= 143; i++) static_bits += (uint64_t)freqs->litlen[i] * 8;
    for (int i = 144; i <= 255; i++) static_bits += (uint64_t)freqs->litlen[i] * 9;
    for (int i = 256; i <= 279; i++) static_bits += (uint64_t)freqs->litlen[i] * 7;
    for (int i = 280; i <= 285; i++) static_bits += (uint64_t)freqs->litlen[i] * 8;

    for (int i = 0; i < 30; i++) static_bits += (uint64_t)freqs->offset[i] * 5;

    uint64_t dynamic_bits = 0;
    if (dynamic_lens_litlen) {
        for (int i = 0; i < 286; i++) {
            if (freqs->litlen[i] > 0) {
                dynamic_bits += (uint64_t)freqs->litlen[i] * dynamic_lens_litlen[i];
            }
        }
    }
    if (dynamic_lens_offset) {
        for (int i = 0; i < 30; i++) {
            if (freqs->offset[i] > 0) {
                dynamic_bits += (uint64_t)freqs->offset[i] * dynamic_lens_offset[i];
            }
        }
    }

    dynamic_bits += 280;

    if (out_static_bits) *out_static_bits = static_bits;
    if (out_dynamic_bits) *out_dynamic_bits = dynamic_bits;

    return static_bits <= dynamic_bits;
}

