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
#include "ttzip_deflate_bitstream.h"
#include "ttzip_deflate_huffman.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

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
#include <pthread.h>

static pthread_once_t s_slot_once = PTHREAD_ONCE_INIT;

static void init_slot_tables_impl(void) {
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
}

static inline void init_slot_tables(void) {
    pthread_once(&s_slot_once, init_slot_tables_impl);
}


#if defined(__APPLE__) || defined(__linux__) || defined(_WIN32)
#define TTZIP_THREAD_LOCAL _Thread_local
#else
#define TTZIP_THREAD_LOCAL __thread
#endif

typedef struct {
    union {
        ttzip_deflate_hybrid_fast_mf_t hybrid_fast_mf;
        ttzip_deflate_fast_lazy_mf_t fast_lazy_mf;
        ttzip_deflate_deep_lazy_mf_t deep_lazy_mf;
    } mf;
    ttzip_deflate_token_t fixed_tokens[131072 + 256];
    uint8_t history_bounce_buffer[32768 + 131072];
} ttzip_deflate_scratch_t;

#define TTZIP_STREAM_CHUNK_SIZE 131072

#include "CTTZipStreamCoder.h"

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
    init_slot_tables();


    if (!in || in_size == 0) {
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

    ttzip_deflate_scratch_t *scratch = (ttzip_deflate_scratch_t *)malloc(sizeof(ttzip_deflate_scratch_t));
    if (!scratch) return 0;

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
            cur_hist_len = history_size > 32768 ? 32768 : history_size;
            if (history + history_size == in) {
                cur_history = history + history_size - cur_hist_len;
            } else {
                memcpy(scratch->history_bounce_buffer, history + history_size - cur_hist_len, cur_hist_len);
                memcpy(scratch->history_bounce_buffer + cur_hist_len, in_chunk, chunk_len);
                in_chunk = scratch->history_bounce_buffer + cur_hist_len;
                cur_history = scratch->history_bounce_buffer;
            }
        }

        ttzip_symbol_freqs_t freqs;
        memset(&freqs, 0, sizeof(freqs));
        freqs.litlen[256] = 1;

        size_t num_tokens = 0;
        int tier = (options ? options->tier_level : 3);

        if (tier == 1) {
            /* Level 1: 64KB Direct 3-Byte Hash + 64-Bit SWAR Matchfinder */
            num_tokens = ttzip_deflate_hybrid_fast_find_matches(
                &scratch->mf.hybrid_fast_mf, in_chunk, chunk_len, cur_history, cur_hist_len, scratch->fixed_tokens, 131072, &freqs
            );
        } else if (tier >= 2 && tier <= 5) {
            /* Level 2..5: 64KB 4-Way Compact Bucket Table (HT-4) with Early Cutoff */
            uint32_t depth = options ? options->max_chain_depth : (tier == 2 ? 2 : (tier == 3 ? 2 : 4));
            uint32_t nice_len = options ? options->nice_match_len : (tier == 2 ? 24 : (tier == 3 ? 32 : (tier == 4 ? 32 : 48)));
            num_tokens = ttzip_deflate_fast_lazy_find_matches(
                &scratch->mf.fast_lazy_mf, in_chunk, chunk_len, cur_history, cur_hist_len, depth, nice_len, scratch->fixed_tokens, 131072, &freqs
            );
        } else {
            /* Level 6..9: 256KB Deep Hash Chain Lookahead Lazy Matchfinder */
            uint32_t depth = options ? options->max_chain_depth : (tier == 6 ? 8 : (tier == 7 ? 16 : (tier == 8 ? 32 : 64)));
            uint32_t nice_len = options ? options->nice_match_len : (tier == 6 ? 64 : (tier <= 8 ? 128 : 258));
            uint32_t lookahead = options ? options->lookahead_steps : 1;
            num_tokens = ttzip_deflate_deep_lazy_find_matches(
                &scratch->mf.deep_lazy_mf, in_chunk, chunk_len, cur_history, cur_hist_len, depth, nice_len, lookahead, scratch->fixed_tokens, 131072, &freqs
            );
        }




        if (num_tokens >= (chunk_len * 98) / 100) {
            /* Data is effectively incompressible (>98% literals): directly emit RFC 1951 uncompressed block(s) (BTYPE=00) */
            size_t u_pos = 0;
            while (u_pos < chunk_len) {
                size_t u_len = chunk_len - u_pos;
                if (u_len > 65535) u_len = 65535;
                bool is_last_u = (u_pos + u_len == chunk_len);
                ttzip_bs_write_uncompressed_block(&bs, in_chunk + u_pos, (uint16_t)u_len, is_last_u && chunk_is_final);
                u_pos += u_len;
            }
            if (bs.overflow) {
                free(scratch);
                return 0;
            }
            pos += chunk_len;
            continue;
        }


        bool use_dynamic = options ? options->dynamic_huffman : true;
        if (chunk_len < 4096 || num_tokens < 384) {
            use_dynamic = false;
        }

        uint8_t lens_litlen[288] = {0};
        uint32_t codewords_litlen[288] = {0};
        uint8_t lens_offset[32] = {0};
        uint32_t codewords_offset[32] = {0};


        if (use_dynamic) {
            ttzip_build_canonical_huffman_tree(freqs.litlen, 286, TTZIP_DEFLATE_MAX_CODEWORD_LEN, lens_litlen, codewords_litlen);
            ttzip_build_canonical_huffman_tree(freqs.offset, 30, TTZIP_DEFLATE_MAX_CODEWORD_LEN, lens_offset, codewords_offset);

            uint64_t static_bits = 0, dynamic_bits = 0;
            if (ttzip_eval_huffman_bit_costs(&freqs, lens_litlen, lens_offset, &static_bits, &dynamic_bits)) {
                use_dynamic = false;
            }
        }

        if (use_dynamic) {
            uint32_t bfinal_bit = chunk_is_final ? 1 : 0;
            ttzip_bs_write_bits(&bs, bfinal_bit | (2 << 1), 3);
            ttzip_write_dynamic_huffman_header(&bs, lens_litlen, 286, lens_offset, 30);

            size_t i = 0;
            while (i < num_tokens) {
                uint16_t len0 = scratch->fixed_tokens[i].length;
                uint16_t off0 = scratch->fixed_tokens[i].offset;

                if (len0 == 0) {
                    if (i + 1 < num_tokens && scratch->fixed_tokens[i + 1].length == 0) {
                        uint8_t lit0 = (uint8_t)off0;
                        uint8_t lit1 = (uint8_t)scratch->fixed_tokens[i + 1].offset;
                        uint32_t code0 = codewords_litlen[lit0];
                        unsigned len_bits0 = lens_litlen[lit0];
                        uint32_t code1 = codewords_litlen[lit1];
                        unsigned len_bits1 = lens_litlen[lit1];

                        uint32_t dual_bits = code0 | (code1 << len_bits0);
                        ttzip_bs_write_bits(&bs, dual_bits, len_bits0 + len_bits1);
                        i += 2;
                    } else {
                        uint8_t lit = (uint8_t)off0;
                        ttzip_bs_write_bits(&bs, codewords_litlen[lit], lens_litlen[lit]);
                        i++;
                    }
                } else {
                    uint8_t len_slot = s_length_slot[len0];
                    uint32_t len_code = codewords_litlen[257 + len_slot];
                    unsigned len_bits = lens_litlen[257 + len_slot];
                    uint8_t extra_len_bits = s_length_extra_bits[len_slot];
                    uint32_t extra_len_val = len0 - s_length_base[len_slot];

                    uint32_t packed_len = len_code | (extra_len_val << len_bits);
                    ttzip_bs_write_bits(&bs, packed_len, len_bits + extra_len_bits);

                    uint8_t off_slot = s_offset_slot[off0];
                    uint32_t off_code = codewords_offset[off_slot];
                    unsigned off_bits = lens_offset[off_slot];
                    uint8_t extra_off_bits = s_offset_extra_bits[off_slot];
                    uint32_t extra_off_val = off0 - s_offset_base[off_slot];

                    uint32_t packed_off = off_code | (extra_off_val << off_bits);
                    ttzip_bs_write_bits(&bs, packed_off, off_bits + extra_off_bits);
                    i++;
                }
            }

            ttzip_bs_write_bits(&bs, codewords_litlen[256], lens_litlen[256]);
        } else {
            const ttzip_huffman_codes_t *sc = ttzip_get_static_huffman_codes();
            uint32_t bfinal_bit = chunk_is_final ? 1 : 0;
            ttzip_bs_write_bits(&bs, bfinal_bit | (1 << 1), 3);

            size_t i = 0;
            while (i < num_tokens) {
                uint16_t len0 = scratch->fixed_tokens[i].length;
                uint16_t off0 = scratch->fixed_tokens[i].offset;

                if (len0 == 0) {
                    if (i + 1 < num_tokens && scratch->fixed_tokens[i + 1].length == 0) {
                        uint8_t lit0 = (uint8_t)off0;
                        uint8_t lit1 = (uint8_t)scratch->fixed_tokens[i + 1].offset;
                        uint32_t code0 = sc->codewords_litlen[lit0];
                        unsigned len_bits0 = sc->lens_litlen[lit0];
                        uint32_t code1 = sc->codewords_litlen[lit1];
                        unsigned len_bits1 = sc->lens_litlen[lit1];

                        uint32_t dual_bits = code0 | (code1 << len_bits0);
                        ttzip_bs_write_bits(&bs, dual_bits, len_bits0 + len_bits1);
                        i += 2;
                    } else {
                        uint8_t lit = (uint8_t)off0;
                        ttzip_bs_write_bits(&bs, sc->codewords_litlen[lit], sc->lens_litlen[lit]);
                        i++;
                    }
                } else {
                    uint8_t len_slot = s_length_slot[len0];
                    uint32_t len_code = sc->codewords_litlen[257 + len_slot];
                    unsigned len_bits = sc->lens_litlen[257 + len_slot];
                    uint8_t extra_len_bits = s_length_extra_bits[len_slot];
                    uint32_t extra_len_val = len0 - s_length_base[len_slot];

                    uint32_t packed_len = len_code | (extra_len_val << len_bits);
                    ttzip_bs_write_bits(&bs, packed_len, len_bits + extra_len_bits);

                    uint8_t off_slot = s_offset_slot[off0];
                    uint32_t off_code = sc->codewords_offset[off_slot];
                    unsigned off_bits = sc->lens_offset[off_slot];
                    uint8_t extra_off_bits = s_offset_extra_bits[off_slot];
                    uint32_t extra_off_val = off0 - s_offset_base[off_slot];

                    uint32_t packed_off = off_code | (extra_off_val << off_bits);
                    ttzip_bs_write_bits(&bs, packed_off, off_bits + extra_off_bits);
                    i++;
                }
            }

            ttzip_bs_write_bits(&bs, sc->codewords_litlen[256], sc->lens_litlen[256]);
        }


        if (bs.overflow) {
            free(scratch);
            return 0;
        }
        pos += chunk_len;
    }

    if (is_final) {
        ttzip_bs_flush_byte_align(&bs);
    } else {
        ttzip_bs_write_sync_flush(&bs);
    }

    size_t result = bs.overflow ? 0 : (size_t)(bs.out_next - out);
    free(scratch);
    return result;


}


#include "CTTZipDeflateEngine.h"
#include "ttzip_zopfli_engine.h"
#include "libdeflate.h"

struct ttzip_deflate_compressor {
    int level;
};

ttzip_deflate_compressor_t *ttzip_deflate_compressor_alloc(int level) {
    if (level < 1) level = 1;
    if (level > 15) level = 15;

    ttzip_deflate_compressor_t *c = (ttzip_deflate_compressor_t *)calloc(1, sizeof(ttzip_deflate_compressor_t));
    if (!c) return NULL;
    c->level = level;
    return c;
}

void ttzip_deflate_compressor_free(ttzip_deflate_compressor_t *c) {
    if (!c) return;
    free(c);
}

size_t ttzip_deflate_compress(
    ttzip_deflate_compressor_t *c,
    const void *in,
    size_t in_size,
    void *out,
    size_t out_capacity
) {
    if (!c || !out || out_capacity == 0) return 0;
    if (in_size == 0) {
        if (out_capacity < 2) return 0;
        uint8_t *out_bytes = (uint8_t *)out;
        out_bytes[0] = 0x03;
        out_bytes[1] = 0x00;
        return 2;
    }
    if (!in) return 0;

    
    if (c->level >= 13) {
        TTZipZopfliOptions zopts;
        ttzip_zopfli_init_options(&zopts, (int32_t)(c->level == 13 ? 2 : (c->level == 14 ? 5 : 15)));
        return ttzip_zopfli_compress_block_with_history(
            (const uint8_t *)in, in_size, NULL, 0, (uint8_t *)out, out_capacity, &zopts, 1
        );
    }

    if (c->level >= 1 && c->level <= 12) {
        return ttzip_libdeflate_compress(in, in_size, out, out_capacity, c->level);
    }

    ttzip_native_deflate_options_t opts;
    memset(&opts, 0, sizeof(opts));
    opts.dynamic_huffman = true;
    opts.tier_level = 1;
    opts.max_chain_depth = 0;
    opts.nice_match_len = 32;
    opts.lookahead_steps = 0;
    opts.skip_intermediate_hashes = true;

    return ttzip_native_deflate_compress_block_with_history(
        (const uint8_t *)in, in_size, NULL, 0, (uint8_t *)out, out_capacity, &opts, true
    );
}



