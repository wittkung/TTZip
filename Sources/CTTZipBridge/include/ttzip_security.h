// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_security.h
 * @brief High-security cryptographic memory scrubbing (DSE immune) and Reed-Solomon recovery records.
 */

#ifndef TTZIP_SECURITY_H
#define TTZIP_SECURITY_H

#include "ttzip_platform.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Zeroes memory securely, guaranteed not to be optimized away by Dead Store Elimination (DSE).
 */
TTZIP_API void ttzip_secure_zero_memory(void *ptr, size_t len);

/**
 * @brief Generates forward error correction (FEC) parity bytes for recovery records.
 */
TTZIP_API int ttzip_generate_recovery_parity(
    const uint8_t *src,
    size_t len,
    uint8_t *out_parity,
    size_t parity_len
);

/**
 * @brief Verifies whether data matches the recovery parity block.
 */
TTZIP_API bool ttzip_verify_recovery_parity(
    const uint8_t *src,
    size_t len,
    const uint8_t *parity,
    size_t parity_len
);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_SECURITY_H */
