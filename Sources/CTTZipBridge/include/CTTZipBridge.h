// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipBridge_h
#define CTTZipBridge_h

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <archive.h>
#include <archive_entry.h>
#include "ttzip_rust_glue.h"

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - 1. Version
const char* cttzip_bridge_version(void);

// MARK: - 2. Fast POSIX Spawn
int ttzip_core_posix_spawn_fast(
    const char* bin_path,
    const char* const* argv,
    const char* working_dir
);

// MARK: - 3. Reed-Solomon Erasure Coding (NEON Accelerated)
int ttzip_rs_create_cauchy_matrix(size_t rows_m, size_t cols_k, uint8_t* out_matrix);
int ttzip_rs_encode_neon(
    const uint8_t* const* data_ptrs,
    size_t k_data,
    uint8_t* const* parity_ptrs,
    size_t m_parity,
    size_t block_size
);
int ttzip_rs_decode_neon(
    const uint8_t* const* available_ptrs,
    const int32_t* available_indices,
    size_t num_available,
    size_t k_data,
    size_t m_parity,
    const int32_t* missing_indices,
    size_t num_missing,
    uint8_t* const* reconstructed_ptrs,
    size_t block_size
);
uint8_t ttzip_rs_gf_mul(uint8_t a, uint8_t b);
uint8_t ttzip_rs_gf_inv(uint8_t a);

// MARK: - 4. Zopfli Deflate Block with History
typedef struct {
    int num_iterations;
    int max_block_splits;
} ttzip_zopfli_options_t;

size_t ttzip_zopfli_compress_block_with_history(
    const uint8_t *in,
    size_t in_size,
    const uint8_t *history,
    size_t history_size,
    uint8_t *out,
    size_t out_capacity,
    const ttzip_zopfli_options_t *options,
    bool is_final
);

// MARK: - 5. CRC-64 ECMA-182
uint64_t ttzip_crc64(const uint8_t *buf, size_t size, uint64_t crc);

// MARK: - 6. File Kind & Magic Sniffing (CTTZipBridge_Archive)
typedef enum {
    TTZIP_KIND_UNKNOWN = 0,
    TTZIP_KIND_ARCHIVE = 1,
    TTZIP_KIND_IMAGE   = 2,
    TTZIP_KIND_AUDIO   = 3,
    TTZIP_KIND_VIDEO   = 4,
    TTZIP_KIND_TEXT    = 5,
    TTZIP_KIND_BINARY  = 6
} ttzip_file_kind_t;

typedef struct {
    ttzip_file_kind_t kind;
    const char* format_name;
    const char* mime_type;
    bool is_archive;
} ttzip_magic_info_t;

ttzip_magic_info_t ttzip_magic_sniff_buffer(const void *buf, size_t len);

// MARK: - 7. Libarchive Native Tar & Advanced Extraction (CTTZipBridge_Archive)
int ttzip_extract_tar_native_c(const char* tar_path, const char* dest_dir, bool skip_mac_junk);
int ttzip_create_tar_native_c(
    const char* out_path,
    const char* format_name,
    const char* const* input_paths,
    size_t num_inputs,
    bool skip_mac_junk,
    int level
);
int ttzip_extract_archive_advanced(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipBridge_h */
