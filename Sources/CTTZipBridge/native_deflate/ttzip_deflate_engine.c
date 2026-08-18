// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_engine.c
 * @brief Native in-process Apple Silicon Deflate block & streaming compression pipeline (Instant Incremental).
 * @details Coordinates greedy/fast-lazy/deep-lazy LZ77 parsing, length/distance slot translation,
 *          dynamic/static canonical Huffman coding, and RFC 1951 continuous bitstream serialization.
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

#if defined(__APPLE__) || defined(__linux__) || defined(_WIN32)
#define TTZIP_THREAD_LOCAL _Thread_local
#else
#define TTZIP_THREAD_LOCAL __thread
#endif

static TTZIP_THREAD_LOCAL ttzip_deflate_fast_mf_t s_tls_fast_mf;
static TTZIP_THREAD_LOCAL ttzip_deflate_fast_lazy_mf_t s_tls_fast_lazy_mf;
static TTZIP_THREAD_LOCAL ttzip_deflate_deep_lazy_mf_t s_tls_deep_lazy_mf;
static TTZIP_THREAD_LOCAL ttzip_deflate_token_t s_tls_fixed_tokens[65536 + 64];

#define TTZIP_STREAM_CHUNK_SIZE 65536

/* Primary entry point for native Deflate block/stream compression */
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
        ttzip_bitstream_t bs;
        ttzip_bs_init(&bs, out, out_capacity);
        if (is_final) {
            const ttzip_huffman_codes_t *sc = ttzip_get_static_huffman_codes();
            ttzip_bs_write_bits(&bs, 1 | (1 << 1), 3);
            ttzip_bs_write_bits(&bs, sc->codewords_litlen[256], sc->lens_litlen[256]);
            ttzip_bs_flush_byte_align(&bs);
        } else {
            ttzip_bs_write_sync_flush(&bs);
        }
        return bs.overflow ? 0 : (size_t)(bs.out_next - out);
    }

    ttzip_bitstream_t bs;
    ttzip_bs_init(&bs, out, out_capacity);

    size_t pos = 0;
    while (pos < in_size) {
        size_t chunk_len = in_size - pos;
        if (chunk_len > TTZIP_STREAM_CHUNK_SIZE) chunk_len = TTZIP_STREAM_CHUNK_SIZE;
        bool is_last_chunk_in_block = (pos + chunk_len == in_size);
        bool chunk_is_final = is_last_chunk_in_block && is_final;

        const uint8_t *in_chunk = in + pos;
        const uint8_t *cur_history = NULL;
        size_t cur_hist_len = 0;

        if (pos > 0) {
            cur_hist_len = (pos >= 32768) ? 32768 : pos;
            cur_history = in + pos - cur_hist_len;
        } else if (history && history_size > 0) {
            cur_history = history;
            cur_hist_len = history_size > 32768 ? 32768 : history_size;
        }

        ttzip_symbol_freqs_t freqs;
        memset(&freqs, 0, sizeof(freqs));
        freqs.litlen[256] = 1;

        size_t num_tokens = 0;
        int tier = (options ? options->tier_level : 3);

        if (tier <= 2) {
            num_tokens = ttzip_deflate_fast_find_matches(
                &s_tls_fast_mf, in_chunk, chunk_len, cur_history, cur_hist_len, s_tls_fixed_tokens, 65536, &freqs
            );
        } else if (tier == 3) {
            uint32_t depth = options ? options->max_chain_depth : 4;
            uint32_t nice_len = options ? options->nice_match_len : 32;
            num_tokens = ttzip_deflate_fast_lazy_find_matches(
                &s_tls_fast_lazy_mf, in_chunk, chunk_len, cur_history, cur_hist_len, depth, nice_len, s_tls_fixed_tokens, 65536, &freqs
            );
        } else {
            uint32_t depth = options ? options->max_chain_depth : 16;
            uint32_t nice_len = options ? options->nice_match_len : 65;
            uint32_t lookahead = options ? options->lookahead_steps : 2;
            num_tokens = ttzip_deflate_deep_lazy_find_matches(
                &s_tls_deep_lazy_mf, in_chunk, chunk_len, cur_history, cur_hist_len, depth, nice_len, lookahead, s_tls_fixed_tokens, 65536, &freqs
            );
        }

        bool use_dynamic = options ? options->dynamic_huffman : true;

        if (use_dynamic) {
            uint8_t lens_litlen[288];
            uint32_t codewords_litlen[288];
            uint8_t lens_offset[32];
            uint32_t codewords_offset[32];

            ttzip_build_canonical_huffman_tree(freqs.litlen, 286, TTZIP_DEFLATE_MAX_CODEWORD_LEN, lens_litlen, codewords_litlen);
            ttzip_build_canonical_huffman_tree(freqs.offset, 30, TTZIP_DEFLATE_MAX_CODEWORD_LEN, lens_offset, codewords_offset);

            uint32_t bfinal_bit = chunk_is_final ? 1 : 0;
            ttzip_bs_write_bits(&bs, bfinal_bit | (2 << 1), 3);
            ttzip_write_dynamic_huffman_header(&bs, lens_litlen, 286, lens_offset, 30);

            for (size_t i = 0; i < num_tokens; i++) {
                uint16_t len = s_tls_fixed_tokens[i].length;
                uint16_t off = s_tls_fixed_tokens[i].offset;

                if (len == 0) {
                    uint8_t lit = (uint8_t)off;
                    ttzip_bs_write_bits(&bs, codewords_litlen[lit], lens_litlen[lit]);
                } else {
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

            ttzip_bs_write_bits(&bs, codewords_litlen[256], lens_litlen[256]);
        } else {
            const ttzip_huffman_codes_t *sc = ttzip_get_static_huffman_codes();
            uint32_t bfinal_bit = chunk_is_final ? 1 : 0;
            ttzip_bs_write_bits(&bs, bfinal_bit | (1 << 1), 3);

            for (size_t i = 0; i < num_tokens; i++) {
                uint16_t len = s_tls_fixed_tokens[i].length;
                uint16_t off = s_tls_fixed_tokens[i].offset;

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

        if (bs.overflow) return 0;
        pos += chunk_len;
    }

    if (is_final) {
        ttzip_bs_flush_byte_align(&bs);
    } else {
        ttzip_bs_write_sync_flush(&bs);
    }

    return bs.overflow ? 0 : (size_t)(bs.out_next - out);
}

#include "CTTZipDeflateEngine.h"
#include "libdeflate.h"

struct ttzip_deflate_compressor {
    int level;
    struct libdeflate_compressor *fallback_comp;
};

ttzip_deflate_compressor_t *ttzip_deflate_compressor_alloc(int level) {
    if (level < 1) level = 1;
    if (level > 9) level = 9;
    ttzip_deflate_compressor_t *c = (ttzip_deflate_compressor_t *)calloc(1, sizeof(ttzip_deflate_compressor_t));
    if (!c) return NULL;
    c->level = level;
    c->fallback_comp = libdeflate_alloc_compressor(level);
    return c;
}

void ttzip_deflate_compressor_free(ttzip_deflate_compressor_t *c) {
    if (!c) return;
    if (c->fallback_comp) {
        libdeflate_free_compressor(c->fallback_comp);
    }
    free(c);
}

size_t ttzip_deflate_compress(
    ttzip_deflate_compressor_t *c,
    const void *in,
    size_t in_size,
    void *out,
    size_t out_capacity
) {
    if (!c || !in || !out || out_capacity == 0) return 0;
    
    if (c->level <= 2) {
        ttzip_native_deflate_options_t opts;
        memset(&opts, 0, sizeof(opts));
        opts.dynamic_huffman = true;
        opts.tier_level = c->level;
        opts.max_chain_depth = 2;
        opts.nice_match_len = 32;
        opts.lookahead_steps = 0;
        opts.skip_intermediate_hashes = true;

        size_t written = ttzip_native_deflate_compress_block_with_history(
            (const uint8_t *)in, in_size, NULL, 0, (uint8_t *)out, out_capacity, &opts, true
        );
        if (written > 0) {
            return written;
        }
    }

    if (c->fallback_comp) {
        return libdeflate_deflate_compress(c->fallback_comp, in, in_size, out, out_capacity);
    }
    return 0;
}
