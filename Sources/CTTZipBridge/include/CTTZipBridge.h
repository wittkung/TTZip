// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge.h
 * @brief Master C bridge header exporting in-process native compression and archive routines.
 * @details Unifies libarchive, libdeflate, LZMA2, Zstandard, APFS zero-copy, and ARM NEON crypto primitives.
 */

#ifndef CTTZipBridge_h
#define CTTZipBridge_h

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <archive.h>
#include <archive_entry.h>
#include <uchardet/uchardet.h>
#include "CTTZipCommon.h"
#include "ttzip_platform.h"
#include "CTTZipPlatform.h"
#include "CTTZipIO.h"

#include "CTTZipSIMD.h"
#include "CTTZipCoreArchitecture.h"
#include "CTTZipNEONMatchFinder.h"
#include "CTTZipQuantumPipeline.h"
#include "CTTZipParser.h"
#include "CTTZipSliceProfiler.h"
#include "CTTZipPlatformTimer.h"
#include "CTTZipBridge_Zstd.h"
#include "lz4.h"
#include "ttzip_bcj_arm64_neon.h"
#include "ttzip_7z_crypto_neon.h"
#include "ttzip_lzma2_branchless_rc.h"
#include "ttzip_lzma_radix_mf.h"
#include "ttzip_fl2_lzma2.h"
#include "ttzip_lzma_hc4_neon.h"
#include "ttzip_native_archive.h"
#include "CTTZipBridge_ZipChunkedStream.h"
#include "CTTZipChecksum.h"
#include "ttzip_crc64.h"
#include "CTTZipBridge_Snappy.h"
#include "ttzip_branchless_decomp.h"
#include "ttzip_7z_header_parser.h"
#include "ttzip_tar_native.h"
#include "CTTZipFilterPipeline.h"
#include "CTTZipSuperChunk.h"
#include "CTTZipHeuristicTuner.h"
#include "CTTZipPluginRegistry.h"
#include "CTTZipBitGroom.h"

#ifdef __cplusplus

extern "C" {
#endif

/* ============================================================================
 * 0. Logging and Diagnostics Central Router
 * ============================================================================ */

/**
 * @brief Log output callback function prototype.
 * @param[in] level   Log severity level (0: DEBUG, 1: INFO, 2: WARN, 3: ERROR).
 * @param[in] message UTF-8 null-terminated log string. Valid only during callback invocation.
 */
typedef void (*ttzip_log_callback_t)(int level, const char* message);

/**
 * @brief Registers global unified log callback.
 * @param[in] cb Callback function pointer, or NULL to unregister.
 */
void ttzip_set_log_callback(ttzip_log_callback_t cb);

/**
 * @brief Format and print a log message through the registered callback.
 */
void ttzip_log_c(int level, const char* fmt, ...);

/* ============================================================================
 * 1. Character Set Detection and Intelligent Transcoding (uchardet)
 * ============================================================================ */

/**
 * @brief Detects character encoding of a raw binary buffer.
 * @param[in] bytes  Input byte stream pointer. Must not be NULL.
 * @param[in] length Stream length in bytes.
 * @return Dynamically allocated charset name (e.g. "UTF-8", "GB18030"), or NULL on failure.
 * @note [Ownership] Caller owns returned memory and must release it with free().
 */
char* ttzip_detect_charset(const char* bytes, size_t length);

/* ============================================================================
 * 2. Archive Metadata Inspection Interfaces
 * ============================================================================ */

typedef void (*ttzip_entry_callback)(void* context, const char* pathname, int64_t uncompressed_size, bool is_directory);

typedef void (*ttzip_entry_callback_v2)(
    void* context,
    const char* pathname,
    int64_t uncompressed_size,
    bool is_directory,
    bool is_data_encrypted,
    bool is_metadata_encrypted
);

int ttzip_inspect_archive(const char* archive_path, void* context, ttzip_entry_callback callback);
int ttzip_inspect_archive_advanced(const char* archive_path, const char* password, void* context, ttzip_entry_callback callback);
int ttzip_inspect_archive_v2(const char* archive_path, const char* password, void* context, ttzip_entry_callback_v2 callback);

/* ============================================================================
 * 3. Extraction Interfaces
 * ============================================================================ */

int ttzip_extract_archive_advanced(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

int ttzip_extract_zip_c_parallel(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

/* ============================================================================
 * 4. Compression and Packaging Interfaces
 * ============================================================================ */

int ttzip_create_archive_advanced(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
);

int ttzip_create_archive_tuned(
    const char* output_archive_path,
    const char* format,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk,
    int zstd_level,
    int zstd_long_window_log,
    int cpu_threads,
    const char* password
);

int ttzip_spawn_7zz_extract(
    const char* bin_path,
    const char* archive_path,
    const char* destination_dir,
    const char* password
);

int ttzip_spawn_7zz_compress(
    const char* bin_path,
    const char* output_archive_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
);

/* ============================================================================
 * 5. In-Memory Block Codec Interfaces (Zstd / LZ4 / LibDeflate)
 * ============================================================================ */

size_t ttzip_zstd_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int compression_level);
size_t ttzip_zstd_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_zstd_compress_advanced(
    const void* src, size_t src_size,
    void* dst, size_t dst_capacity,
    int level, int nb_workers, int job_size_mb, int overlap_log, int window_log, bool enable_ldm
);
int ttzip_zstd_compress_file_stream(
    const char* src_path,
    const char* dst_path,
    int level, int nb_workers, int job_size_mb, int overlap_log, int window_log, bool enable_ldm,
    const char* dict_path
);

int ttzip_zstd_decompress_file_stream(
    const char* src_path,
    const char* dst_path,
    const char* dict_path
);
size_t ttzip_lz4_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int acceleration);
size_t ttzip_lz4_compress_bound(size_t src_size);
size_t ttzip_lz4_compress_fast_tls(const void* src, size_t src_size, void* dst, size_t dst_capacity, int acceleration);
size_t ttzip_lz4_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_lz4_decompress_partial(const void* src, size_t src_size, void* dst, size_t target_size, size_t dst_capacity);

struct libdeflate_compressor;
struct libdeflate_decompressor;
struct libdeflate_compressor* ttzip_get_tls_compressor(int level);
struct libdeflate_decompressor* ttzip_get_tls_decompressor(void);
size_t ttzip_libdeflate_decompress(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_libdeflate_compress(const void* src, size_t src_size, void* dst, size_t dst_capacity, int level);
size_t ttzip_zlib_deflate_compress_chunk(const void* src, size_t src_size, void* dst, size_t dst_capacity, int level, bool is_last_chunk);

/* ============================================================================
 * 6. Zero-Copy mmap ZIP Central Directory Inspector
 * ============================================================================ */
int ttzip_mmap_zip_inspect(const char* archive_path, void* context, ttzip_entry_callback callback);

/* ============================================================================
 * 7. Checksums, CRC32, Entropy and Fast Character Checks
 * ============================================================================ */
uint32_t ttzip_compute_file_crc32(const char* file_path);
uint32_t ttzip_compute_buffer_crc32(const void* buf, size_t len);
uint32_t ttzip_compute_buffer_crc32_neon(uint32_t initial_crc, const void* buf, size_t len);
uint32_t ttzip_compute_buffer_crc32_parallel(const void* buf, size_t len);
void ttzip_neon_memcpy_64b(void* dst, const void* src, size_t len);
double ttzip_estimate_buffer_entropy(const void* buf, size_t len);
double ttzip_estimate_buffer_entropy_dynamic(const void* buf, size_t len);
double ttzip_estimate_file_entropy_dynamic(const char* file_path);
bool ttzip_is_ascii_fast(const void* buf, size_t len);
bool ttzip_is_mac_junk(const char* path);

int ttzip_pbkdf2_sha1_fast(const char* password, size_t pass_len, const uint8_t* salt, size_t salt_len, uint32_t rounds, uint8_t* out_key, size_t key_len);
int ttzip_pbkdf2_sha256_fast(const char* password, size_t pass_len, const uint8_t* salt, size_t salt_len, uint32_t rounds, uint8_t* out_key, size_t key_len);

int ttzip_create_tar_native_c(const char* output_path, const char* format_flag, const char* const* input_paths, size_t input_count, bool skip_mac_junk, int level);
int ttzip_create_tar_direct_c(const char* output_path, const char* const* input_paths, size_t input_count, bool skip_mac_junk);
int ttzip_extract_tar_native_c(const char* archive_path, const char* dest_dir, bool skip_mac_junk);
int ttzip_extract_tar_from_memory(const void* tar_buf, size_t tar_len, const char* dest_dir, bool skip_mac_junk);

/* ============================================================================
 * 8. Aligned Memory Allocation Helper
 * ============================================================================ */
void* ttzip_aligned_alloc_16k(size_t size);

/* ============================================================================
 * 9. WinZip AES-256 CTR Parallel Hardware Cryptography
 * ============================================================================ */
int ttzip_aes256_ctr_crypt(
    const uint8_t* key,
    uint64_t initial_block_count,
    const uint8_t* src,
    size_t length,
    uint8_t* dst
);

/* ============================================================================
 * 10. APFS Zero-Copy Clone and Preallocation
 * ============================================================================ */
int ttzip_apfs_clone_range(int in_fd, int64_t in_offset, int out_fd, int64_t out_offset, uint64_t count);
int ttzip_apfs_preallocate(int fd, int64_t target_size);

/* ============================================================================
 * 11. Multi-Core AES-256 CTR Engine
 * ============================================================================ */
int ttzip_aes256_ctr_crypt_parallel(
    const uint8_t* key,
    const uint8_t* src,
    size_t length,
    uint8_t* dst,
    int threads
);

int ttzip_compute_hmac_sha1_fast(
    const uint8_t* key,
    size_t key_len,
    const uint8_t* data,
    size_t data_len,
    uint8_t out_mac[10]
);

/* ============================================================================
 * 12. Parallel libdeflate ZIP Creation Engine
 * ============================================================================ */
int ttzip_create_zip_parallel_c(
    const char* output_zip_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    bool skip_mac_junk,
    const char* password
);

/* ============================================================================
 * 13. Native 7Z Codec & Thread Pool Interfaces
 * ============================================================================ */
int ttzip_extract_7z_native_c(const char* archive_path, const char* destination_dir, const char* password);
int ttzip_extract_7z_libarchive_c(const char* archive_path, const char* dest_dir, const char* password);
int ttzip_7z_extract_native_parallel_c(const char* archive_path, const char* destination_dir, const char* password);
int ttzip_create_7z_native_c(const char* output_path, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_create_7z_store_fast_c(const char* output_path, const char* const* input_paths, size_t input_count);
int ttzip_create_7z_parallel_fast_c(const char* output_path, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_create_7z_lzma2_native_c(const char* output_path, const char* const* input_paths, size_t input_count, int level, const char* password);
void ttzip_register_7zz_binary(const char* bin_path);
const char* ttzip_get_7zz_binary_path(void);
int ttzip_spawn_7zz_extract(const char* bin_path, const char* archive_path, const char* destination_dir, const char* password);
int ttzip_spawn_7zz_compress(const char* bin_path, const char* output_archive_path, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_spawn_7zz_compress_in_dir(const char* bin_path, const char* output_archive_path, const char* working_dir, const char* const* input_paths, size_t input_count, int level, const char* password);
int ttzip_lzma2_compress_mt_c(const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_capacity, size_t* out_compressed_len, int level);
int ttzip_lzma2_decompress_mt_c(const uint8_t* src, size_t src_len, uint8_t* dst, size_t dst_capacity, size_t* out_decompressed_len);
int ttzip_stat_file_info(const char* path, uint64_t* out_size, uint32_t* out_mode, uint64_t* out_mtime);

#include "CTTZipStreamCoder.h"
#include "CTTZipBridge_7zParallel.h"
#include "ttzip_7z_kdf_arm64.h"
#include "ttzip_tar_zstd_direct.h"

/* ============================================================================
 * 14. Architecture Layer Primitives (CTTZipCoreArchitecture)
 * ============================================================================ */
int ttzip_core_apfs_preallocate_file(int fd, int64_t target_size);
void* ttzip_core_aligned_alloc_16k(size_t size);
uint32_t ttzip_core_crc32_neon_single(uint32_t crc, const uint8_t* buf, size_t len);
int ttzip_core_posix_spawn_fast(const char* bin_path, const char* const* argv, const char* working_dir);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipBridge_h */
