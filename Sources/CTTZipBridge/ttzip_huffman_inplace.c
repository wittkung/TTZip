// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_huffman_inplace.h"
#include <string.h>

#if defined(__aarch64__) || defined(_M_ARM64)
#  if defined(__GNUC__) || defined(__clang__)
static inline uint32_t ttzip_rbit32(uint32_t v) {
    uint32_t res;
    __asm__("rbit %w0, %w1" : "=r" (res) : "r" (v));
    return res;
}
#  else
static inline uint32_t ttzip_rbit32(uint32_t v) {
    return (uint32_t)__builtin_arm_rbit(v);
}
#  endif
#endif

#if !defined(__aarch64__) && !defined(_M_ARM64)
/* 256-byte cacheline-resident bit-reversal lookup table for x86_64 fallback */
static const uint8_t s_bitreverse_tab[256] = {
    0x00, 0x80, 0x40, 0xc0, 0x20, 0xa0, 0x60, 0xe0,
    0x10, 0x90, 0x50, 0xd0, 0x30, 0xb0, 0x70, 0xf0,
    0x08, 0x88, 0x48, 0xc8, 0x28, 0xa8, 0x68, 0xe8,
    0x18, 0x98, 0x58, 0xd8, 0x38, 0xb8, 0x78, 0xf8,
    0x04, 0x84, 0x44, 0xc4, 0x24, 0xa4, 0x64, 0xe4,
    0x14, 0x94, 0x54, 0xd4, 0x34, 0xb4, 0x74, 0xf4,
    0x0c, 0x8c, 0x4c, 0xcc, 0x2c, 0xac, 0x6c, 0xec,
    0x1c, 0x9c, 0x5c, 0xdc, 0x3c, 0xbc, 0x7c, 0xfc,
    0x02, 0x82, 0x42, 0xc2, 0x22, 0xa2, 0x62, 0xe2,
    0x12, 0x92, 0x52, 0xd2, 0x32, 0xb2, 0x72, 0xf2,
    0x0a, 0x8a, 0x4a, 0xca, 0x2a, 0xaa, 0x6a, 0xea,
    0x1a, 0x9a, 0x5a, 0xda, 0x3a, 0xba, 0x7a, 0xfa,
    0x06, 0x86, 0x46, 0xc6, 0x26, 0xa6, 0x66, 0xe6,
    0x16, 0x96, 0x56, 0xd6, 0x36, 0xb6, 0x76, 0xf6,
    0x0e, 0x8e, 0x4e, 0xce, 0x2e, 0xae, 0x6e, 0xee,
    0x1e, 0x9e, 0x5e, 0xde, 0x3e, 0xbe, 0x7e, 0xfe,
    0x01, 0x81, 0x41, 0xc1, 0x21, 0xa1, 0x61, 0xe1,
    0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1,
    0x09, 0x89, 0x49, 0xc9, 0x29, 0xa9, 0x69, 0xe9,
    0x19, 0x99, 0x59, 0xd9, 0x39, 0xb9, 0x79, 0xf9,
    0x05, 0x85, 0x45, 0xc5, 0x25, 0xa5, 0x65, 0xe5,
    0x15, 0x95, 0x55, 0xd5, 0x35, 0xb5, 0x75, 0xf5,
    0x0d, 0x8d, 0x4d, 0xcd, 0x2d, 0xad, 0x6d, 0xed,
    0x1d, 0x9d, 0x5d, 0xdd, 0x3d, 0xbd, 0x7d, 0xfd,
    0x03, 0x83, 0x43, 0xc3, 0x23, 0xa3, 0x63, 0xe3,
    0x13, 0x93, 0x53, 0xd3, 0x33, 0xb3, 0x73, 0xf3,
    0x0b, 0x8b, 0x4b, 0xcb, 0x2b, 0xab, 0x6b, 0xeb,
    0x1b, 0x9b, 0x5b, 0xdb, 0x3b, 0xbb, 0x7b, 0xfb,
    0x07, 0x87, 0x47, 0xc7, 0x27, 0xa7, 0x67, 0xe7,
    0x17, 0x97, 0x57, 0xd7, 0x37, 0xb7, 0x77, 0xf7,
    0x0f, 0x8f, 0x4f, 0xcf, 0x2f, 0xaf, 0x6f, 0xef,
    0x1f, 0x9f, 0x5f, 0xdf, 0x3f, 0xbf, 0x7f, 0xff
};
#endif

uint32_t ttzip_canonical_bit_reverse(uint32_t code, uint8_t len) {
    if (len == 0) return 0;
#if defined(__aarch64__) || defined(_M_ARM64)
    return ttzip_rbit32(code) >> ((32 - len) & 31);
#else
    uint32_t rev16 = ((uint32_t)s_bitreverse_tab[code & 0xFF] << 8) | s_bitreverse_tab[(code >> 8) & 0xFF];
    return rev16 >> (16 - len);
#endif
}

static void build_tree_inplace(uint32_t A[], unsigned sym_count) {
    const unsigned last_idx = sym_count - 1;
    unsigned i = 0; // Leaf queue read index
    unsigned b = 0; // Non-leaf queue read index
    unsigned e = 0; // Non-leaf queue write index

    do {
        uint32_t new_freq;

        if (i + 1 <= last_idx &&
            (b == e || (A[i + 1] & TTZIP_HUFF_FREQ_MASK) <= (A[b] & TTZIP_HUFF_FREQ_MASK))) {
            // Two leaves
            new_freq = (A[i] & TTZIP_HUFF_FREQ_MASK) + (A[i + 1] & TTZIP_HUFF_FREQ_MASK);
            i += 2;
        } else if (b + 2 <= e &&
                   (i > last_idx || (A[b + 1] & TTZIP_HUFF_FREQ_MASK) < (A[i] & TTZIP_HUFF_FREQ_MASK))) {
            // Two non-leaves
            new_freq = (A[b] & TTZIP_HUFF_FREQ_MASK) + (A[b + 1] & TTZIP_HUFF_FREQ_MASK);
            A[b]     = (e << TTZIP_HUFF_SYM_BITS) | (A[b] & TTZIP_HUFF_SYM_MASK);
            A[b + 1] = (e << TTZIP_HUFF_SYM_BITS) | (A[b + 1] & TTZIP_HUFF_SYM_MASK);
            b += 2;
        } else {
            // One leaf and one non-leaf
            new_freq = (A[i] & TTZIP_HUFF_FREQ_MASK) + (A[b] & TTZIP_HUFF_FREQ_MASK);
            A[b]     = (e << TTZIP_HUFF_SYM_BITS) | (A[b] & TTZIP_HUFF_SYM_MASK);
            i++;
            b++;
        }
        A[e] = new_freq | (A[e] & TTZIP_HUFF_SYM_MASK);
    } while (++e < last_idx);
}

static void compute_length_counts_inplace(
    uint32_t A[],
    unsigned root_idx,
    unsigned len_counts[],
    unsigned max_codeword_len
) {
    for (unsigned len = 0; len <= max_codeword_len; ++len) {
        len_counts[len] = 0;
    }
    len_counts[1] = 2;

    A[root_idx] &= TTZIP_HUFF_SYM_MASK; // Root depth is 0

    for (int node = (int)root_idx - 1; node >= 0; --node) {
        unsigned parent = A[node] >> TTZIP_HUFF_SYM_BITS;
        unsigned parent_depth = A[parent] >> TTZIP_HUFF_SYM_BITS;
        unsigned depth = parent_depth + 1;

        A[node] = (A[node] & TTZIP_HUFF_SYM_MASK) | (depth << TTZIP_HUFF_SYM_BITS);

        if (depth >= max_codeword_len) {
            depth = max_codeword_len;
            do {
                depth--;
            } while (len_counts[depth] == 0);
        }

        len_counts[depth]--;
        len_counts[depth + 1] += 2;
    }
}

static void gen_codewords_inplace(
    uint32_t A[],
    uint8_t lens[],
    const unsigned len_counts[],
    unsigned max_codeword_len,
    unsigned num_syms,
    bool bit_reverse
) {
    uint32_t next_codewords[TTZIP_HUFF_MAX_CODE_LEN + 1];
    unsigned i = 0;

    for (unsigned len = max_codeword_len; len >= 1; --len) {
        unsigned count = len_counts[len];
        while (count--) {
            lens[A[i++] & TTZIP_HUFF_SYM_MASK] = (uint8_t)len;
        }
    }

    next_codewords[0] = 0;
    next_codewords[1] = 0;
    for (unsigned len = 2; len <= max_codeword_len; ++len) {
        next_codewords[len] = (next_codewords[len - 1] + len_counts[len - 1]) << 1;
    }

    for (unsigned sym = 0; sym < num_syms; ++sym) {
        uint8_t l = lens[sym];
        if (l == 0) {
            A[sym] = 0;
            continue;
        }
        uint32_t code = next_codewords[l]++;
        A[sym] = bit_reverse ? ttzip_canonical_bit_reverse(code, l) : code;
    }
}

static void heap_sort_symbols(uint32_t A[], unsigned n) {
    if (n < 2) return;
    for (unsigned i = n / 2; i > 0; i--) {
        unsigned root = i - 1;
        uint32_t val = A[root];
        while (2 * root + 1 < n) {
            unsigned child = 2 * root + 1;
            if (child + 1 < n && (A[child + 1] & TTZIP_HUFF_FREQ_MASK) > (A[child] & TTZIP_HUFF_FREQ_MASK)) {
                child++;
            }
            if ((val & TTZIP_HUFF_FREQ_MASK) >= (A[child] & TTZIP_HUFF_FREQ_MASK)) break;
            A[root] = A[child];
            root = child;
        }
        A[root] = val;
    }
    for (unsigned i = n - 1; i > 0; i--) {
        uint32_t temp = A[0];
        A[0] = A[i];
        A[i] = temp;
        unsigned root = 0;
        uint32_t val = A[0];
        while (2 * root + 1 < i) {
            unsigned child = 2 * root + 1;
            if (child + 1 < i && (A[child + 1] & TTZIP_HUFF_FREQ_MASK) > (A[child] & TTZIP_HUFF_FREQ_MASK)) {
                child++;
            }
            if ((val & TTZIP_HUFF_FREQ_MASK) >= (A[child] & TTZIP_HUFF_FREQ_MASK)) break;
            A[root] = A[child];
            root = child;
        }
        A[root] = val;
    }
}

static unsigned sort_symbols_fast(unsigned num_syms, const uint32_t freqs[], uint8_t lens[], uint32_t symout[]) {
    unsigned num_counters = num_syms <= 32 ? 32 : (num_syms <= 288 ? 288 : 512);
    unsigned counters[512];
    memset(counters, 0, num_counters * sizeof(counters[0]));

    for (unsigned sym = 0; sym < num_syms; sym++) {
        uint32_t f = freqs[sym];
        unsigned idx = f < (num_counters - 1) ? f : (num_counters - 1);
        counters[idx]++;
    }

    unsigned num_used_syms = 0;
    for (unsigned i = 1; i < num_counters; i++) {
        unsigned count = counters[i];
        counters[i] = num_used_syms;
        num_used_syms += count;
    }

    for (unsigned sym = 0; sym < num_syms; sym++) {
        uint32_t freq = freqs[sym];
        if (freq != 0) {
            unsigned idx = freq < (num_counters - 1) ? freq : (num_counters - 1);
            symout[counters[idx]++] = (sym & TTZIP_HUFF_SYM_MASK) | (freq << TTZIP_HUFF_SYM_BITS);
        } else {
            lens[sym] = 0;
        }
    }

    unsigned last_start = counters[num_counters - 2];
    unsigned last_count = counters[num_counters - 1] - last_start;
    if (last_count > 1) {
        heap_sort_symbols(symout + last_start, last_count);
    }

    return num_used_syms;
}

void ttzip_make_canonical_huffman_code_inplace(
    unsigned num_syms,
    unsigned max_codeword_len,
    const uint32_t freqs[],
    uint8_t lens[],
    uint32_t codewords[],
    bool bit_reverse
) {
    if (!freqs || !lens || !codewords || num_syms < 2) return;
    if (max_codeword_len > TTZIP_HUFF_MAX_CODE_LEN) max_codeword_len = TTZIP_HUFF_MAX_CODE_LEN;

    uint32_t* A = codewords;
    unsigned num_used_syms = sort_symbols_fast(num_syms, freqs, lens, A);

    if (num_used_syms == 0) {
        memset(codewords, 0, num_syms * sizeof(uint32_t));
        return;
    }

    if (num_used_syms < 2) {
        unsigned sym = A[0] & TTZIP_HUFF_SYM_MASK;
        unsigned dummy_sym = (sym == 0) ? 1 : 0;
        memset(codewords, 0, num_syms * sizeof(uint32_t));
        lens[sym] = 1;
        lens[dummy_sym] = 1;
        codewords[sym] = 0;
        codewords[dummy_sym] = 1;
        return;
    }

    // Phase 1: In-place two-queue tree construction
    build_tree_inplace(A, num_used_syms);

    // Phase 2: Reverse topological pass & depth computation
    unsigned len_counts[TTZIP_HUFF_MAX_CODE_LEN + 1];
    compute_length_counts_inplace(A, num_used_syms - 2, len_counts, max_codeword_len);

    // Phase 3: Canonical codeword generation
    gen_codewords_inplace(A, lens, len_counts, max_codeword_len, num_syms, bit_reverse);
}
