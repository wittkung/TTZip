// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipBridge_UnRAR.h
 * @brief Native UnRAR extraction and inspection interfaces.
 */

#ifndef CTTZIP_BRIDGE_UNRAR_H
#define CTTZIP_BRIDGE_UNRAR_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_unrar_extract_archive(
    const char* archive_path,
    const char* destination_dir,
    bool skip_mac_junk,
    const char* password
);

int ttzip_unrar_inspect_entry_count(const char* archive_path);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_UNRAR_H */
