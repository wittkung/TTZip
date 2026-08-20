// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_security.h"
#include <string.h>

void ttzip_secure_zero_memory(void *ptr, size_t len) {
    if (!ptr || len == 0) return;
    volatile uint8_t *p = (volatile uint8_t *)ptr;
    while (len--) {
        *p++ = 0;
    }
}

int ttzip_generate_recovery_parity(
    const uint8_t *src,
    size_t len,
    uint8_t *out_parity,
    size_t parity_len
) {
    if (!src || len == 0 || !out_parity || parity_len == 0) return -1;

    memset(out_parity, 0, parity_len);

    /* Galois Field / XOR Parity Generation */
    for (size_t i = 0; i < len; i++) {
        size_t p_idx = i % parity_len;
        out_parity[p_idx] ^= src[i];
    }

    return 0;
}

bool ttzip_verify_recovery_parity(
    const uint8_t *src,
    size_t len,
    const uint8_t *parity,
    size_t parity_len
) {
    if (!src || len == 0 || !parity || parity_len == 0) return false;

    uint8_t *check = (uint8_t *)malloc(parity_len);
    if (!check) return false;

    ttzip_generate_recovery_parity(src, len, check, parity_len);
    int diff = memcmp(check, parity, parity_len);
    free(check);

    return (diff == 0);
}
