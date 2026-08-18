// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_tar_zstd_direct.h
 * @brief 100% in-process native Direct mmap TAR.ZST compressor and streaming extractor.
 */

#ifndef TTZIP_TAR_ZSTD_DIRECT_H
#define TTZIP_TAR_ZSTD_DIRECT_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_create_tar_zstd_direct_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    bool skip_mac_junk
);

int ttzip_extract_tar_zstd_direct_c(
    const char* archive_path,
    const char* dest_dir,
    bool skip_mac_junk
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_TAR_ZSTD_DIRECT_H
