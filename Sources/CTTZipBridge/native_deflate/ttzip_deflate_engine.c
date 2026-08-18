// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_engine.c
 * @brief Native in-process Apple Silicon Deflate block compression pipeline.
 * @details Coordinates greedy/lazy LZ77 parsing, length/distance slot translation,
 *          dynamic/static canonical Huffman coding, and RFC 1951 bitstream serialization.
 */

#include "ttzip_deflate_engine.h"
#include <stdlib.h>
#include <string.h>

/* Match finder forward declarations */
size_t ttzip_deflate_fast_find_matches(
    ttzip_deflate_fast_mf_t *mf,
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    ttzip_deflate_token_t *tokens_out,
    size_t max_tokens,
    ttzip_symbol_freqs_t *freqs_out
);

size_t ttzip_deflate_lazy_find_matches(
    ttzip_deflate_lazy_mf_t *mf,
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint32_t max_chain_depth,
    uint32_t nice_match_len,
    ttzip_deflate_token_t *tokens_out,
    size_t max_tokens,
    ttzip_symbol_freqs_t *freqs_out
);

/* 1. Length slot base and extra bits tables (RFC 1951 section 3.2.5) */
const uint16_t s_length_base[29] = {
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
};

const uint8_t s_length_extra_bits[29] = {
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
};

/* 2. Offset slot base and extra bits tables (RFC 1951 section 3.2.5) */
const uint16_t s_offset_base[30] = {
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
    257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
};

const uint8_t s_offset_extra_bits[30] = {
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
    7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
};

/* Fast reverse-lookup mapping tables */
uint8_t s_length_slot[259];
uint8_t s_offset_slot[32769];
static bool s_slot_tables_initialized = false;

static void init_slot_tables(void) {
    if (s_slot_tables_initialized) return;
    
    /* Precompute length to slot lookup */
    for (unsigned slot = 0; slot < 29; slot++) {
        unsigned base = s_length_base[slot];
        unsigned num = 1U << s_length_extra_bits[slot];
        if (slot == 28) num = 1;
        for (unsigned i = 0; i < num && base + i <= 258; i++) {
            s_length_slot[base + i] = (uint8_t)slot;
        }
    }

    /* Precompute distance to slot lookup */
    for (unsigned slot = 0; slot < 30; slot++) {
        unsigned base = s_offset_base[slot];
        unsigned num = 1U << s_offset_extra_bits[slot];
        for (unsigned i = 0; i < num && base + i <= 32768; i++) {
            s_offset_slot[base + i] = (uint8_t)slot;
        }
    }

    s_slot_tables_initialized = true;
}

/* Primary entry point for native Deflate block compression */
size_t ttzip_native_deflate_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const ttzip_native_deflate_options_t *options,
    bool is_final
) {
    if (!s_slot_tables_initialized) {
        init_slot_tables();
    }

    if (in_size == 0) {
        /* Empty input: Emit static empty block with EOB or sync flush marker */
        ttzip_bitstream_t bs;
        ttzip_bs_init(&bs, out, out_capacity);
        if (is_final) {
            /* BFINAL=1, BTYPE=01 (static Huffman block) + EOB marker */
            const ttzip_huffman_codes_t *sc = ttzip_get_static_huffman_codes();
            ttzip_bs_write_bits(&bs, 1 | (1 << 1), 3);
            ttzip_bs_write_bits(&bs, sc->codewords_litlen[256], sc->lens_litlen[256]);
            ttzip_bs_flush_byte_align(&bs);
        } else {
            ttzip_bs_write_sync_flush(&bs);
        }
        return bs.overflow ? 0 : (size_t)(bs.out_next - out);
    }

    /* Allocate intermediate LZ77 token buffer */
    size_t max_tokens = in_size + 16;
    ttzip_deflate_token_t *tokens = (ttzip_deflate_token_t *)malloc(max_tokens * sizeof(ttzip_deflate_token_t));
    if (!tokens) return 0;

    ttzip_symbol_freqs_t freqs;
    memset(&freqs, 0, sizeof(freqs));
    freqs.litlen[256] = 1; /* End-of-Block symbol occurs exactly once */

    size_t num_tokens = 0;
    int tier = (options ? options->tier_level : 3);

    if (tier <= 2) {
        /* Tier 1 / 2: Fast greedy match finder */
        ttzip_deflate_fast_mf_t *mf = (ttzip_deflate_fast_mf_t *)malloc(sizeof(ttzip_deflate_fast_mf_t));
        if (!mf) {
            free(tokens);
            return 0;
        }
        num_tokens = ttzip_deflate_fast_find_matches(
            mf, in, in_size, history, history_size, tokens, max_tokens, &freqs
        );
        free(mf);
    } else {
        /* Tier 3 / 4: Lazy evaluation match finder */
        ttzip_deflate_lazy_mf_t *mf = (ttzip_deflate_lazy_mf_t *)malloc(sizeof(ttzip_deflate_lazy_mf_t));
        if (!mf) {
            free(tokens);
            return 0;
        }
        uint32_t depth = (options ? options->max_chain_depth : (tier == 3 ? 4 : 16));
        uint32_t nice_len = (options ? options->nice_match_len : (tier == 3 ? 32 : 128));
        num_tokens = ttzip_deflate_lazy_find_matches(
            mf, in, in_size, history, history_size, depth, nice_len, tokens, max_tokens, &freqs
        );
        free(mf);
    }

    /* Initialize bitstream output writer */
    ttzip_bitstream_t bs;
    ttzip_bs_init(&bs, out, out_capacity);

    bool use_dynamic = options ? options->dynamic_huffman : true;

    if (use_dynamic) {
        /* Dynamic Canonical Huffman Encoding */
        uint8_t lens_litlen[288];
        uint32_t codewords_litlen[288];
        uint8_t lens_offset[32];
        uint32_t codewords_offset[32];

        ttzip_build_canonical_huffman_tree(freqs.litlen, 286, TTZIP_DEFLATE_MAX_CODEWORD_LEN, lens_litlen, codewords_litlen);
        ttzip_build_canonical_huffman_tree(freqs.offset, 30, TTZIP_DEFLATE_MAX_CODEWORD_LEN, lens_offset, codewords_offset);

        /* 1. Emit block header: BFINAL (1 bit) + BTYPE=10 (2 bits) -> 3 bits */
        uint32_t bfinal_bit = is_final ? 1 : 0;
        ttzip_bs_write_bits(&bs, bfinal_bit | (2 << 1), 3);

        /* 2. Emit dynamic tree headers */
        ttzip_write_dynamic_huffman_header(&bs, lens_litlen, 286, lens_offset, 30);

        /* 3. Emit compressed token payload */
        for (size_t i = 0; i < num_tokens; i++) {
            uint16_t len = tokens[i].length;
            uint16_t off = tokens[i].offset;

            if (len == 0) {
                /* Literal byte */
                uint8_t lit = (uint8_t)off;
                ttzip_bs_write_bits(&bs, codewords_litlen[lit], lens_litlen[lit]);
            } else {
                /* Match length and distance pair */
                uint8_t len_slot = s_length_slot[len];
                ttzip_bs_write_bits(&bs, codewords_litlen[257 + len_slot], lens_litlen[257 + len_slot]);
                uint8_t extra_len_bits = s_length_extra_bits[len_slot];
                if (extra_len_bits > 0) {
                    uint32_t extra_val = len - s_length_base[len_slot];
                    ttzip_bs_write_bits(&bs, extra_val, extra_len_bits);
                }

                uint8_t off_slot = s_offset_slot[off];
                ttzip_bs_write_bits(&bs, codewords_offset[off_slot], lens_offset[off_slot]);
                uint8_t extra_off_bits = s_offset_extra_bits[off_slot];
                if (extra_off_bits > 0) {
                    uint32_t extra_val = off - s_offset_base[off_slot];
                    ttzip_bs_write_bits(&bs, extra_val, extra_off_bits);
                }
            }
        }

        /* 4. Emit End-of-Block (EOB 256) */
        ttzip_bs_write_bits(&bs, codewords_litlen[256], lens_litlen[256]);
    } else {
        /* Static Huffman Encoding */
        const ttzip_huffman_codes_t *sc = ttzip_get_static_huffman_codes();
        uint32_t bfinal_bit = is_final ? 1 : 0;
        ttzip_bs_write_bits(&bs, bfinal_bit | (1 << 1), 3);

        for (size_t i = 0; i < num_tokens; i++) {
            uint16_t len = tokens[i].length;
            uint16_t off = tokens[i].offset;

            if (len == 0) {
                uint8_t lit = (uint8_t)off;
                ttzip_bs_write_bits(&bs, sc->codewords_litlen[lit], sc->lens_litlen[lit]);
            } else {
                uint8_t len_slot = s_length_slot[len];
                ttzip_bs_write_bits(&bs, sc->codewords_litlen[257 + len_slot], sc->lens_litlen[257 + len_slot]);
                uint8_t extra_len_bits = s_length_extra_bits[len_slot];
                if (extra_len_bits > 0) {
                    uint32_t extra_val = len - s_length_base[len_slot];
                    ttzip_bs_write_bits(&bs, extra_val, extra_len_bits);
                }

                uint8_t off_slot = s_offset_slot[off];
                ttzip_bs_write_bits(&bs, sc->codewords_offset[off_slot], sc->lens_offset[off_slot]);
                uint8_t extra_off_bits = s_offset_extra_bits[off_slot];
                if (extra_off_bits > 0) {
                    uint32_t extra_val = off - s_offset_base[off_slot];
                    ttzip_bs_write_bits(&bs, extra_val, extra_off_bits);
                }
            }
        }

        ttzip_bs_write_bits(&bs, sc->codewords_litlen[256], sc->lens_litlen[256]);
    }

    free(tokens);

    /* 5. Stream alignment and non-final block sync flush */
    if (!is_final) {
        ttzip_bs_write_sync_flush(&bs);
    } else {
        ttzip_bs_flush_byte_align(&bs);
    }

    if (bs.overflow) {
        return 0;
    }
    return (size_t)(bs.out_next - out);
}
