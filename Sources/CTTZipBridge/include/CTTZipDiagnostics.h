// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipDiagnostics.h
 * @brief Diagnostic telemetry, crash site recording, and signal handling.
 */

#ifndef CTTZIPDIAGNOSTICS_H
#define CTTZIPDIAGNOSTICS_H

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    const char* layer;        // e.g. "C:7zDecoder", "C:LZMA2Enc"
    const char* operation;    // e.g. "extract", "compress"
    const char* file_path;    // current file being operated on
    int64_t     file_size;
    int         error_code;
    char        detail[256];
} ttzip_diag_context_t;

void ttzip_diag_enter(const char* layer, const char* operation, const char* path, int64_t size);
void ttzip_diag_set_error(int code, const char* detail);
void ttzip_diag_leave(void);
const ttzip_diag_context_t* ttzip_diag_current(void);

void ttzip_install_signal_handlers(void);

/**
 * Combines two libarchive-aligned return codes using monotonic negative severity ordering:
 * ARCHIVE_FATAL (-30) < ARCHIVE_FAILED (-25) < ARCHIVE_WARN (-20) < ARCHIVE_RETRY (-10) < ARCHIVE_OK (0) < ARCHIVE_EOF (1)
 *
 * More severe errors have lower (more negative) numerical values.
 * Returns the more severe error: (err1 < err2 ? err1 : err2).
 */
int ttzip_err_combine(int err1, int err2);

#endif // CTTZIPDIAGNOSTICS_H
