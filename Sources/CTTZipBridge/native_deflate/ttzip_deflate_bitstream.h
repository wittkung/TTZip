// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_deflate_bitstream.h
 * @brief Ultra high-throughput 64-bit branchless Deflate bitstream writer.
 * @details Implements LSB-first bit insertion, unaligned 64-bit scalar/NEON word flushes,
 *          RFC 1951 byte alignment, and Z_SYNC_FLUSH boundary markers for multi-core streaming.
 */

#ifndef TTZIP_DEFLATE_BITSTREAM_H
#define TTZIP_DEFLATE_BITSTREAM_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

#if defined(__arm64__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 64-bit branchless bitstream state machine.
 */
typedef struct {
    uint64_t bit_buffer;   /**< Accumulated bits in LSB-first order (0 <= bit_count <= 63). */
    unsigned bit_count;    /**< Number of valid bits currently held in bit_buffer. */
    uint8_t *out_next;     /**< Pointer to next writable byte in destination memory. */
    uint8_t *out_end;      /**< Hard upper bound of destination buffer. */
    uint8_t *out_fast_end; /**< Fast-path threshold pointer (out_end - 8) for single-cycle 64-bit stores. */
    bool     overflow;     /**< True if destination capacity was exceeded during writes. */
} ttzip_bitstream_t;

/**
 * @brief Initializes a bitstream writer state with given memory bounds.
 *
 * @param[out] bs           Bitstream state to initialize.
 * @param[in]  out          Destination byte buffer.
 * @param[in]  out_capacity Total allocated capacity of out buffer in bytes.
 */
static inline void ttzip_bs_init(ttzip_bitstream_t *bs, uint8_t *out, size_t out_capacity) {
    bs->bit_buffer = 0;
    bs->bit_count = 0;
    bs->out_next = out;
    bs->out_end = out + out_capacity;
    bs->out_fast_end = (out_capacity >= 8) ? (out + out_capacity - 8) : out;
    bs->overflow = false;
}

/**
 * @brief Emits up to 32 bits into the bitstream in LSB-first order.
 *
 * @param[in,out] bs    Active bitstream state.
 * @param[in]     bits  Bit values to write (must have bits above nbits cleared).
 * @param[in]     nbits Number of bits to consume (1 <= nbits <= 32).
 */
static inline void ttzip_bs_write_bits(ttzip_bitstream_t *bs, uint32_t bits, unsigned nbits) {
    bs->bit_buffer |= ((uint64_t)bits) << bs->bit_count;
    bs->bit_count += nbits;

    if (bs->bit_count >= 32) {
        if (bs->out_next < bs->out_fast_end) {
            uint32_t w = (uint32_t)bs->bit_buffer;
            memcpy(bs->out_next, &w, 4);
            bs->out_next += 4;
            bs->bit_buffer >>= 32;
            bs->bit_count -= 32;
        } else {
            while (bs->bit_count >= 8) {
                if (bs->out_next < bs->out_end) {
                    *bs->out_next++ = (uint8_t)bs->bit_buffer;
                    bs->bit_buffer >>= 8;
                    bs->bit_count -= 8;
                } else {
                    bs->overflow = true;
                    break;
                }
            }
        }
    }
}

/**
 * @brief Emits up to 56 bits into the bitstream in a single branchless operation.
 */
static inline void ttzip_bs_write_bits64(ttzip_bitstream_t *bs, uint64_t bits, unsigned nbits) {
    bs->bit_buffer |= bits << bs->bit_count;
    bs->bit_count += nbits;

    if (bs->bit_count >= 32) {
        if (bs->out_next < bs->out_fast_end) {
            uint32_t w = (uint32_t)bs->bit_buffer;
            memcpy(bs->out_next, &w, 4);
            bs->out_next += 4;
            bs->bit_buffer >>= 32;
            bs->bit_count -= 32;
        } else {
            while (bs->bit_count >= 8) {
                if (bs->out_next < bs->out_end) {
                    *bs->out_next++ = (uint8_t)bs->bit_buffer;
                    bs->bit_buffer >>= 8;
                    bs->bit_count -= 8;
                } else {
                    bs->overflow = true;
                    break;
                }
            }
        }
    }
}


/**
 * @brief Flushes any remaining partial byte to byte boundary with zero bits (RFC 1951 section 3.2.1).
 *
 * @param[in,out] bs Active bitstream state.
 */
static inline void ttzip_bs_flush_byte_align(ttzip_bitstream_t *bs) {
    if (bs->bit_count > 0) {
        unsigned rem = (8 - (bs->bit_count & 7)) & 7;
        if (rem > 0) {
            bs->bit_count += rem;
        }
        while (bs->bit_count >= 8) {
            if (bs->out_next < bs->out_end) {
                *bs->out_next++ = (uint8_t)bs->bit_buffer;
                bs->bit_buffer >>= 8;
                bs->bit_count -= 8;
            } else {
                bs->overflow = true;
                break;
            }
        }
        bs->bit_buffer = 0;
        bs->bit_count = 0;
    }
}

/**
 * @brief Emits RFC 1951 Z_SYNC_FLUSH marker (empty uncompressed block: 0x00, 0x00, 0xFF, 0xFF).
 *
 * @param[in,out] bs Active bitstream state.
 */
static inline void ttzip_bs_write_sync_flush(ttzip_bitstream_t *bs) {
    /* 1. Emit BFINAL=0, BTYPE=00 (uncompressed block header: 3 bits '000') */
    ttzip_bs_write_bits(bs, 0, 3);
    /* 2. Align to next byte boundary */
    ttzip_bs_flush_byte_align(bs);
    /* 3. Emit LEN=0x0000 and NLEN=0xFFFF */
    if (bs->out_next + 4 <= bs->out_end) {
        bs->out_next[0] = 0x00;
        bs->out_next[1] = 0x00;
        bs->out_next[2] = 0xFF;
        bs->out_next[3] = 0xFF;
        bs->out_next += 4;
    } else {
        bs->overflow = true;
    }
}

/**
 * @brief Emits a raw RFC 1951 uncompressed block (BTYPE=00) directly copying uncompressed bytes.
 */
static inline void ttzip_bs_write_uncompressed_block(
    ttzip_bitstream_t *bs,
    const uint8_t *in,
    uint16_t len,
    bool is_final
) {
    uint32_t bfinal_bit = is_final ? 1 : 0;
    ttzip_bs_write_bits(bs, bfinal_bit | (0 << 1), 3);
    ttzip_bs_flush_byte_align(bs);

    uint16_t nlen = (uint16_t)~len;
    if (bs->out_next + 4 + len <= bs->out_end) {
        memcpy(bs->out_next, &len, 2);
        memcpy(bs->out_next + 2, &nlen, 2);
        memcpy(bs->out_next + 4, in, len);
        bs->out_next += 4 + len;
    } else {
        bs->overflow = true;
    }
}

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_DEFLATE_BITSTREAM_H */
