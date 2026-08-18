// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZip7zStoreInternal.h
 * @brief Internal type aliases and function mappings for 7Z store/solid pipeline.
 */

#ifndef CTTZIP_7Z_STORE_INTERNAL_H
#define CTTZIP_7Z_STORE_INTERNAL_H

#include "CTTZipBridge_7zStore.h"
#include "CTTZipCommon.h"
#include "CTTZipIO.h"
#include "CTTZipSIMD.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

typedef ttzip_io_entry_t ttzip_7z_store_entry_t;
typedef ttzip_io_file_list_t ttzip_7z_store_list_t;

#define ttzip_7z_collect_recursive ttzip_io_collect_recursive
#define ttzip_7z_write_varint ttzip_varint_write_u64
#define ttzip_7z_write_all ttzip_io_write_all

#endif // CTTZIP_7Z_STORE_INTERNAL_H
