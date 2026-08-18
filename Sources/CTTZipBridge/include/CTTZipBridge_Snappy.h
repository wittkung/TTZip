// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZIP_BRIDGE_SNAPPY_H
#define CTTZIP_BRIDGE_SNAPPY_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Snappy Magic Identifiers & Status Codes

#define TTZIP_SNAPPY_MAGIC 0x734E6150 // 'sNaP'
#define TTZIP_SNAPPY_STREAM_ID "\xFF\x06\x00\x00sNaPpY"
#define TTZIP_SNAPPY_STREAM_ID_LEN 10
#define TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE 65536 // 64KB
#define TTZIP_SNAPPY_MAX_CHUNK_PAYLOAD (65536 + 4) // 64KB + 4B CRC
#define TTZIP_SNAPPY_CRC32C_MASK_DELTA 0xa282ead8U

typedef enum {
    TTZIP_SNAPPY_OK                       =  0,
    TTZIP_SNAPPY_ERR_INVALID_MAGIC        = -1,
    TTZIP_SNAPPY_ERR_CORRUPT_VARINT       = -2,
    TTZIP_SNAPPY_ERR_CORRUPT_TAG          = -3,
    TTZIP_SNAPPY_ERR_OFFSET_OUT_OF_BOUNDS = -4,
    TTZIP_SNAPPY_ERR_LITERAL_OVERRUN      = -5,
    TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL     = -6,
    TTZIP_SNAPPY_ERR_CRC32C_MISMATCH      = -7,
    TTZIP_SNAPPY_ERR_UNSUPPORTED_CHUNK    = -8,
    TTZIP_SNAPPY_ERR_UNEXPECTED_EOF       = -9,
    TTZIP_SNAPPY_ERR_INVALID_PARAM        = -10,
    TTZIP_SNAPPY_ERR_IO_FAILED            = -11
} ttzip_snappy_status_t;

// MARK: - Raw Block Compression & Decompression APIs

/**
 * @brief Checks if native Snappy engine is available.
 */
bool ttzip_snappy_is_available(void);

/**
 * @brief Returns maximum compressed length buffer needed for given input length.
 */
size_t ttzip_snappy_max_compressed_length(size_t source_length);

/**
 * @brief Parses uncompressed length from Snappy varint header.
 * @return 0 on success (TTZIP_SNAPPY_OK), negative error code on failure.
 */
int ttzip_snappy_uncompressed_length(const void* compressed, size_t compressed_len, size_t* result_len);

/**
 * @brief Compresses raw memory buffer using in-process native Snappy engine.
 * @param[in] input Source uncompressed bytes.
 * @param[in] input_len Byte length of input.
 * @param[out] output Destination buffer (must have capacity >= ttzip_snappy_max_compressed_length(input_len)).
 * @param[in,out] output_len In: buffer capacity. Out: actual compressed byte count.
 * @return 0 on success, negative error code on failure.
 */
int ttzip_snappy_compress(const void* input, size_t input_len, void* output, size_t* output_len);

/**
 * @brief Decompresses raw Snappy buffer into destination memory.
 * @param[in] compressed Source compressed bytes.
 * @param[in] compressed_len Byte length of compressed buffer.
 * @param[out] output Destination buffer for uncompressed bytes.
 * @param[in,out] output_len In: buffer capacity. Out: actual decompressed byte count.
 * @return 0 on success, negative error code on failure.
 */
int ttzip_snappy_decompress(const void* compressed, size_t compressed_len, void* output, size_t* output_len);

/**
 * @brief Validates integrity of compressed Snappy buffer without writing to destination.
 * @return 0 on valid, negative error code on corruption.
 */
int ttzip_snappy_validate(const void* compressed, size_t compressed_len);

// MARK: - CRC32C & Masking Routines (Apple Silicon Hardware Accelerated)

/**
 * @brief Computes Castagnoli CRC32C checksum with Apple Silicon ARM64 ACLE hardware acceleration.
 */
uint32_t ttzip_snappy_crc32c(uint32_t crc, const void* data, size_t len);

/**
 * @brief Masks CRC32C per Snappy Framing Format specification.
 */
static inline uint32_t ttzip_snappy_mask_crc32c(uint32_t crc) {
    return ((crc >> 15) | (crc << 17)) + TTZIP_SNAPPY_CRC32C_MASK_DELTA;
}

/**
 * @brief Unmasks CRC32C per Snappy Framing Format specification.
 */
static inline uint32_t ttzip_snappy_unmask_crc32c(uint32_t masked_crc) {
    uint32_t rot = masked_crc - TTZIP_SNAPPY_CRC32C_MASK_DELTA;
    return (rot >> 17) | (rot << 15);
}

// MARK: - Framing Stream Format Encoders & Decoders

/**
 * @brief Encodes raw buffer into Snappy Framing Format (.sz) stream.
 * @param[in] input Source uncompressed bytes.
 * @param[in] input_len Length of uncompressed bytes.
 * @param[out] output Destination buffer.
 * @param[in,out] output_len In: buffer capacity. Out: actual framed output bytes.
 * @return 0 on success, negative error code on failure.
 */
int ttzip_snappy_framed_compress(const void* input, size_t input_len, void* output, size_t* output_len);

/**
 * @brief Decodes Snappy Framing Format (.sz) stream into uncompressed bytes.
 * @param[in] input Framed stream bytes starting with stream identifier.
 * @param[in] input_len Total framed stream length.
 * @param[out] output Destination buffer.
 * @param[in,out] output_len In: buffer capacity. Out: actual uncompressed bytes.
 * @return 0 on success, negative error code on failure.
 */
int ttzip_snappy_framed_decompress(const void* input, size_t input_len, void* output, size_t* output_len);

// MARK: - 100% In-Process TAR.SZ Native Archiving & Extraction

/**
 * @brief Creates TAR.SZ archive completely in-process without external CLI processes.
 * @param[in] output_archive_path Target archive path (.tar.sz or .sz).
 * @param[in] input_paths Array of file/directory paths to archive.
 * @param[in] input_count Number of elements in input_paths.
 * @param[in] skip_mac_junk If true, skips .DS_Store and __MACOSX resource forks.
 * @return 0 on success, negative error code on failure.
 */
int ttzip_create_tar_snappy_native_c(
    const char* output_archive_path,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
);

/**
 * @brief Extracts TAR.SZ archive completely in-process without external CLI processes.
 * @param[in] archive_path Source archive path (.tar.sz or .sz).
 * @param[in] dest_dir Destination directory for extraction.
 * @param[in] skip_mac_junk If true, skips .DS_Store and __MACOSX resource forks.
 * @return 0 on success, negative error code on failure.
 */
int ttzip_extract_tar_snappy_native_c(
    const char* archive_path,
    const char* dest_dir,
    bool skip_mac_junk
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_SNAPPY_H */
