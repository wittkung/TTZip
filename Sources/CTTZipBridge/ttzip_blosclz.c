// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_blosclz.h"
#include <string.h>
#include <stdlib.h>

#define MAX_COPY 32
#define MAX_LEN 264
#define MAX_DISTANCE 8191
#define MAX_FARDISTANCE (65535 + MAX_DISTANCE - 1)

#define HASH_MULTIPLIER 2654435761U

static inline uint32_t read_u32(const uint8_t* p) {
    uint32_t v;
    memcpy(&v, p, sizeof(v));
    return v;
}

static inline void wild_copy_64(uint8_t* dst, const uint8_t* src, uint8_t* end) {
    uint8_t* d = dst;
    const uint8_t* s = src;
    do {
        memcpy(d, s, 8);
        d += 8;
        s += 8;
    } while (d < end);
}

int ttzip_blosclz_compress(
    const void* input,
    int length,
    void* output,
    int maxout,
    int clevel,
    int hash_log
) {
    if (!input || !output || length <= 0 || maxout <= 0) return 0;
    if (clevel < 1) clevel = 1;
    if (clevel > 9) clevel = 9;
    if (hash_log < 12) hash_log = 12;
    if (hash_log > 14) hash_log = 14;

    const uint8_t* ip = (const uint8_t*)input;
    const uint8_t* ibase = ip;
    const uint8_t* ip_bound = ip + length - 4;
    const uint8_t* ip_limit = ip + length - 12;

    uint8_t* op = (uint8_t*)output;
    uint8_t* op_limit = op + maxout;

    // Small data (< 16 bytes): direct literal store
    if (length < 16) {
        if (op + 1 + length > op_limit) return 0;
        *op++ = (uint8_t)(length - 1);
        memcpy(op, ip, (size_t)length);
        return (int)(op + length - (uint8_t*)output);
    }

    uint32_t htab[16384];
    uint32_t hmask = (1U << hash_log) - 1;
    memset(htab, 0, (size_t)(1U << hash_log) * sizeof(uint32_t));

    const uint8_t* anchor = ip;
    ip += 1;

    while (ip < ip_limit) {
        uint32_t seq = read_u32(ip);
        uint32_t hval = (seq * HASH_MULTIPLIER) >> (32U - hash_log);
        hval &= hmask;

        uint32_t ref_offset = htab[hval];
        const uint8_t* ref = ibase + ref_offset;
        htab[hval] = (uint32_t)(ip - ibase);

        uint32_t distance = (uint32_t)(ip - ref);

        if (distance > 0 && distance < MAX_DISTANCE &&
            ref < ip &&
            ref[0] == ip[0] &&
            ref[1] == ip[1] &&
            ref[2] == ip[2]) {

            // Found at least 3-byte match!
            // 1. Flush pending literals before match
            if (ip > anchor) {
                size_t lit_len = (size_t)(ip - anchor);
                while (lit_len > 0) {
                    size_t chunk = lit_len > MAX_COPY ? MAX_COPY : lit_len;
                    if (op + 1 + chunk > op_limit) return 0;
                    *op++ = (uint8_t)(chunk - 1);
                    memcpy(op, anchor, chunk);
                    op += chunk;
                    anchor += chunk;
                    lit_len -= chunk;
                }
            }

            // 2. Extend match length
            size_t match_len = 3;
            while (ip + match_len < ip_bound && ref + match_len < ip && ip[match_len] == ref[match_len]) {
                match_len++;
                if (match_len >= MAX_LEN) break;
            }

            // 3. Emit match token
            if (match_len <= 8) {
                // Short match: 3..8 bytes
                if (op + 2 > op_limit) return 0;
                *op++ = (uint8_t)(((match_len - 2) << 5) | (distance >> 8));
                *op++ = (uint8_t)(distance & 0xFF);
            } else {
                // Long match: > 8 bytes
                if (op + 3 > op_limit) return 0;
                *op++ = (uint8_t)((7 << 5) | (distance >> 8));
                *op++ = (uint8_t)(distance & 0xFF);
                *op++ = (uint8_t)(match_len - 9);
            }

            ip += match_len;
            anchor = ip;

            // Re-seed hash table for next lookup
            if (ip < ip_limit) {
                seq = read_u32(ip - 1);
                hval = ((seq * HASH_MULTIPLIER) >> (32U - hash_log)) & hmask;
                htab[hval] = (uint32_t)(ip - 1 - ibase);
            }
        } else {
            // No match: advance by 1 (or stride on low clevel)
            ip += (clevel < 4) ? 2 : 1;
        }
    }

    // Flush trailing literals
    const uint8_t* iend = ibase + length;
    if (anchor < iend) {
        size_t lit_len = (size_t)(iend - anchor);
        while (lit_len > 0) {
            size_t chunk = lit_len > MAX_COPY ? MAX_COPY : lit_len;
            if (op + 1 + chunk > op_limit) return 0;
            *op++ = (uint8_t)(chunk - 1);
            memcpy(op, anchor, chunk);
            op += chunk;
            anchor += chunk;
            lit_len -= chunk;
        }
    }

    return (int)(op - (uint8_t*)output);
}

int ttzip_blosclz_decompress(
    const void* input,
    int length,
    void* output,
    int maxout
) {
    if (!input || !output || length <= 0 || maxout <= 0) return 0;

    const uint8_t* ip = (const uint8_t*)input;
    const uint8_t* ip_limit = ip + length;
    uint8_t* op = (uint8_t*)output;
    uint8_t* op_limit = op + maxout;
    uint8_t* op_wild_limit = (maxout >= 8) ? (op + maxout - 8) : op;

    while (ip < ip_limit) {
        uint8_t ctrl = *ip++;
        uint8_t opcode = ctrl >> 5;

        if (opcode == 0) {
            // Literal run: 1..32 bytes
            size_t lit_len = (size_t)(ctrl & 0x1F) + 1;
            if (ip + lit_len > ip_limit || op + lit_len > op_limit) return 0;

            if (op <= op_wild_limit && lit_len <= 8) {
                memcpy(op, ip, 8);
                op += lit_len;
                ip += lit_len;
            } else {
                memcpy(op, ip, lit_len);
                op += lit_len;
                ip += lit_len;
            }
        } else {
            // Match token
            if (ip >= ip_limit) return 0;
            uint32_t distance = ((uint32_t)(ctrl & 0x1F) << 8) | (*ip++);
            if (distance == 0 || distance > (size_t)(op - (uint8_t*)output)) {
                return 0; // Corrupt distance
            }

            size_t match_len;
            if (opcode < 7) {
                // Short match: 3..8 bytes
                match_len = (size_t)opcode + 2;
            } else {
                // Extended long match: 9..264 bytes
                if (ip >= ip_limit) return 0;
                match_len = (size_t)(*ip++) + 9;
            }

            if (op + match_len > op_limit) return 0;

            const uint8_t* ref = op - distance;
            if (distance >= 8 && op + match_len <= op_wild_limit) {
                wild_copy_64(op, ref, op + match_len);
                op += match_len;
            } else {
                // Overlapping or near-boundary byte copy
                for (size_t i = 0; i < match_len; i++) {
                    op[i] = ref[i];
                }
                op += match_len;
            }
        }
    }

    return (int)(op - (uint8_t*)output);
}
