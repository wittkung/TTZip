// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_inflate_dual_lut.h
 * @brief 12-bit Dual-Symbol Direct Huffman Decoding LUT for single-core ultra-fast decompression.
 */

#ifndef TTZIP_INFLATE_DUAL_LUT_H
#define TTZIP_INFLATE_DUAL_LUT_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

#define TTZIP_LITLEN_TABLEBITS 12
#define TTZIP_LITLEN_TABLESIZE (1U << TTZIP_LITLEN_TABLEBITS) // 4096 entries (16 KB)
#define TTZIP_OFFSET_TABLEBITS 9
#define TTZIP_OFFSET_TABLESIZE (1U << TTZIP_OFFSET_TABLEBITS) // 512 entries

/* Entry flags in 32-bit entry */
#define TTZIP_HUFFDEC_DUAL_LITERAL 0x80000000U // Bit 31: 1 = Dual-literal (2 bytes)
#define TTZIP_HUFFDEC_LITERAL      0x40000000U // Bit 30: 1 = Single-literal (1 byte)
#define TTZIP_HUFFDEC_EXCEPTIONAL  0x20000000U // Bit 29: 1 = Subtable jump or EOB / Invalid

typedef struct {
    uint32_t litlen_table[TTZIP_LITLEN_TABLESIZE];
    uint32_t offset_table[TTZIP_OFFSET_TABLESIZE];
    uint32_t secondary_table[1024]; // Overflow subtable for long codes (>12 bits)
} ttzip_inflate_tables_t;

/* Build 12-bit dual-symbol direct Huffman table from canonical code lengths */
static inline bool ttzip_inflate_build_dual_litlen_table(
    ttzip_inflate_tables_t *tables,
    const uint8_t *lens,
    unsigned num_symbols
) {
    if (!tables || !lens || num_symbols > 288) return false;

    memset(tables->litlen_table, 0, sizeof(tables->litlen_table));
    uint16_t count[16];
    uint16_t next_code[16];
    memset(count, 0, sizeof(count));
    for (unsigned i = 0; i < num_symbols; i++) {
        if (lens[i] > 0 && lens[i] <= 15) {
            count[lens[i]]++;
        }
    }

    uint16_t code = 0;
    count[0] = 0;
    for (unsigned len = 1; len <= 15; len++) {
        code = (code + count[len - 1]) << 1;
        next_code[len] = code;
    }

    uint16_t codewords[288];
    for (unsigned i = 0; i < num_symbols; i++) {
        if (lens[i] > 0) {
            codewords[i] = next_code[lens[i]]++;
        } else {
            codewords[i] = 0;
        }
    }

    /* 1. Populate primary single-symbol entries */
    for (unsigned sym = 0; sym < num_symbols; sym++) {
        unsigned len = lens[sym];
        if (len == 0) continue;
        uint16_t cw = codewords[sym];

        /* Bit-reverse codeword to LSB-first index */
        uint16_t rev_cw = 0;
        for (unsigned b = 0; b < len; b++) {
            rev_cw |= ((cw >> b) & 1) << (len - 1 - b);
        }

        if (len <= TTZIP_LITLEN_TABLEBITS) {
            uint32_t entry;
            if (sym < 256) {
                // Single literal
                entry = TTZIP_HUFFDEC_LITERAL | ((uint32_t)sym << 16) | len;
            } else if (sym == 256) {
                // End of block
                entry = TTZIP_HUFFDEC_EXCEPTIONAL | 0; // len in low byte = len
                entry |= len;
            } else {
                // Match length (sym 257..285)
                unsigned slot = sym - 257;
                entry = ((uint32_t)slot << 16) | len;
            }

            unsigned step = 1U << len;
            for (unsigned idx = rev_cw; idx < TTZIP_LITLEN_TABLESIZE; idx += step) {
                tables->litlen_table[idx] = entry;
            }
        }
    }

    /* 2. Populate Dual-Symbol entries for short literals (len1 + len2 <= 12) */
    for (unsigned s1 = 0; s1 < 256; s1++) {
        unsigned l1 = lens[s1];
        if (l1 == 0 || l1 > 6) continue;
        uint16_t cw1 = codewords[s1];
        uint16_t r1 = 0;
        for (unsigned b = 0; b < l1; b++) r1 |= ((cw1 >> b) & 1) << (l1 - 1 - b);

        for (unsigned s2 = 0; s2 < 256; s2++) {
            unsigned l2 = lens[s2];
            if (l2 == 0) continue;
            unsigned total_len = l1 + l2;
            if (total_len > TTZIP_LITLEN_TABLEBITS) continue;

            uint16_t cw2 = codewords[s2];
            uint16_t r2 = 0;
            for (unsigned b = 0; b < l2; b++) r2 |= ((cw2 >> b) & 1) << (l2 - 1 - b);

            uint32_t combined_idx = r1 | (r2 << l1);
            uint32_t dual_entry = TTZIP_HUFFDEC_DUAL_LITERAL |
                                  ((uint32_t)s2 << 24) |
                                  ((uint32_t)s1 << 16) |
                                  ((uint32_t)l2 << 12) |
                                  ((uint32_t)l1 << 8) |
                                  total_len;

            unsigned step = 1U << total_len;
            for (unsigned idx = combined_idx; idx < TTZIP_LITLEN_TABLESIZE; idx += step) {
                tables->litlen_table[idx] = dual_entry;
            }
        }
    }

    return true;
}

#endif /* TTZIP_INFLATE_DUAL_LUT_H */
