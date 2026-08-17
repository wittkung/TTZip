#ifndef TTZIP_LZMA_HC4_NEON_H
#define TTZIP_LZMA_HC4_NEON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// HC4 Match Finder with ARM NEON acceleration
// Designed for LZMA L1 fast mode on Apple Silicon

typedef struct {
    uint32_t len;
    uint32_t dist;   // distance - 1
} ttzip_match_t;

typedef struct {
    uint32_t* hash2;         // 2-byte hash table (1024 entries)
    uint32_t* hash3;         // 3-byte hash table (65536 entries)
    uint32_t* hash4;         // 4-byte hash table (hash_mask+1 entries)
    uint32_t* chain;         // chain array (dict_size entries)
    const uint8_t* buffer;   // input data pointer
    uint32_t  buffer_size;   // total input size
    uint32_t  pos;           // current position in buffer
    uint32_t  dict_size;     // dictionary size (256KB for L1)
    uint32_t  hash_mask;     // hash4 table size mask
    uint32_t  cut_value;     // max chain search depth (16 for L1)
    uint32_t  nice_len;      // nice match length (32 for L1)
    uint32_t  len_limit;     // max match length (273)
} ttzip_hc4_t;

// Initialize HC4 match finder. Returns 0 on success.
int ttzip_hc4_init(ttzip_hc4_t* mf, const uint8_t* data, uint32_t data_size,
                   uint32_t dict_size, uint32_t nice_len, uint32_t cut_value);

// Free HC4 match finder resources.
void ttzip_hc4_free(ttzip_hc4_t* mf);

// Find matches at current position. Returns number of matches found.
// Advances position by 1.
uint32_t ttzip_hc4_get_matches(ttzip_hc4_t* mf, ttzip_match_t* matches, uint32_t max_matches);

// Skip n positions without finding matches.
void ttzip_hc4_skip(ttzip_hc4_t* mf, uint32_t count);

// Double-Fast Dual-Table Match Finder (4-byte short + 8-byte long O(1) hash tables)
// Inspired by Zstandard Double-Fast algorithm, optimized for Apple Silicon zero-allocation hot paths
typedef struct {
    uint32_t* table_small;   // 4-byte hash table (65536 entries = 256KB)
    uint32_t* table_long;    // 8-byte hash table (65536 entries = 256KB)
    const uint8_t* buffer;   // Input data pointer
    uint32_t buffer_size;    // Total input size
    uint32_t pos;            // Current position
    uint32_t dict_size;      // Dictionary window size
    uint32_t mask_small;     // Mask for small table (0xFFFF)
    uint32_t mask_long;      // Mask for long table (0xFFFF)
    uint32_t nice_len;       // Greedy lookahead threshold (default 32)
    uint32_t len_limit;      // Max match length (default 273)
    void* workspace;         // Pointer to workspace memory
    bool owns_workspace;     // True if allocated dynamically
} ttzip_double_fast_t;

// Initialize Double-Fast with optional caller-provided 512KB workspace (zero dynamic allocation)
int ttzip_double_fast_init_workspace(ttzip_double_fast_t* df, const uint8_t* data, uint32_t data_size,
                                     uint32_t dict_size, uint32_t nice_len, void* workspace, size_t workspace_size);

// Initialize Double-Fast match finder (dynamically allocates 512KB workspace)
int ttzip_double_fast_init(ttzip_double_fast_t* df, const uint8_t* data, uint32_t data_size,
                           uint32_t dict_size, uint32_t nice_len);

// Free Double-Fast match finder
void ttzip_double_fast_free(ttzip_double_fast_t* df);

// Find best matches using Double-Fast dual table lookup and 1-step lookahead
uint32_t ttzip_double_fast_get_matches(ttzip_double_fast_t* df, ttzip_match_t* matches, uint32_t max_matches);

// Skip n positions in Double-Fast tables
void ttzip_double_fast_skip(ttzip_double_fast_t* df, uint32_t count);

/**
 * @brief Hybrid SWAR (Tier 0: 64-bit GPR) + NEON (Tier 1: 128-bit vector) match length finder.
 *
 * Designed to eliminate Apple Silicon vector-to-GPR cross-domain latency on short matches (< 8 bytes)
 * while accelerating extended match scans (up to max_len, e.g. 258 for Deflate or 273 for LZMA) via 128-bit NEON unrolling.
 *
 * @param p1 Pointer to search target
 * @param p2 Pointer to match candidate
 * @param max_len Maximum match length to compare
 * @return Contiguous identical byte count in range [0, max_len]
 */
uint32_t ttzip_hybrid_match_len_neon(const uint8_t* p1, const uint8_t* p2, uint32_t max_len);

// Fast 64-bit SWAR & NEON match length computation (alias to ttzip_hybrid_match_len_neon).
uint32_t ttzip_match_len_neon(const uint8_t* p1, const uint8_t* p2, uint32_t max_len);

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

static inline bool ttzip_is_block_repetitive_neon(const uint8_t* data, size_t size, uint8_t* out_byte) {
    if (!data || size == 0) return false;
    uint8_t first_byte = data[0];
    if (out_byte) *out_byte = first_byte;
    size_t i = 0;
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    uint8x16_t vtarget = vdupq_n_u8(first_byte);
    while (i + 64 <= size) {
        uint8x16_t v1 = veorq_u8(vld1q_u8(data + i), vtarget);
        uint8x16_t v2 = veorq_u8(vld1q_u8(data + i + 16), vtarget);
        uint8x16_t v3 = veorq_u8(vld1q_u8(data + i + 32), vtarget);
        uint8x16_t v4 = veorq_u8(vld1q_u8(data + i + 48), vtarget);
        uint8x16_t final_or = vorrq_u8(vorrq_u8(v1, v2), vorrq_u8(v3, v4));
        uint64_t low = vgetq_lane_u64(vreinterpretq_u64_u8(final_or), 0);
        uint64_t high = vgetq_lane_u64(vreinterpretq_u64_u8(final_or), 1);
        if (low | high) return false;
        i += 64;
    }
#endif
    while (i < size) {
        if (data[i] != first_byte) return false;
        i++;
    }
    return true;
}

static inline bool ttzip_is_block_all_zero_neon(const uint8_t* data, size_t size) {
    uint8_t b = 0;
    return ttzip_is_block_repetitive_neon(data, size, &b) && b == 0;
}

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA_HC4_NEON_H
