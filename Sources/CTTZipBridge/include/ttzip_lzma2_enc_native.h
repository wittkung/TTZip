// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_lzma2_enc_native.h
 * @brief Native in-process LZMA2 compression and 7Z container creation interface.
 */

#ifndef TTZIP_LZMA2_ENC_NATIVE_H
#define TTZIP_LZMA2_ENC_NATIVE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_create_7z_lzma2_native_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    const char* password
);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_LZMA2_ENC_NATIVE_H
