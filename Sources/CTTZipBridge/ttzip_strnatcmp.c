// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_strnatcmp.h"
#include <ctype.h>

static int compare_digits(const char **a, const char **b) {
    uint64_t val_a = 0;
    uint64_t val_b = 0;
    size_t len_a = 0;
    size_t len_b = 0;

    while (isdigit((unsigned char)**a)) {
        val_a = val_a * 10 + (**a - '0');
        (*a)++;
        len_a++;
    }
    while (isdigit((unsigned char)**b)) {
        val_b = val_b * 10 + (**b - '0');
        (*b)++;
        len_b++;
    }

    if (val_a < val_b) return -1;
    if (val_a > val_b) return 1;
    if (len_a < len_b) return -1;
    if (len_a > len_b) return 1;
    return 0;
}

static int strnatcmp_impl(const char *a, const char *b, bool fold_case) {
    if (!a && !b) return 0;
    if (!a) return -1;
    if (!b) return 1;

    while (*a && *b) {
        if (isdigit((unsigned char)*a) && isdigit((unsigned char)*b)) {
            int dig_res = compare_digits(&a, &b);
            if (dig_res != 0) return dig_res;
        } else {
            char ca = fold_case ? (char)tolower((unsigned char)*a) : *a;
            char cb = fold_case ? (char)tolower((unsigned char)*b) : *b;
            if (ca != cb) {
                return (unsigned char)ca - (unsigned char)cb;
            }
            a++;
            b++;
        }
    }

    if (*a) return 1;
    if (*b) return -1;
    return 0;
}

int ttzip_strnatcmp(const char *a, const char *b) {
    return strnatcmp_impl(a, b, false);
}

int ttzip_strnatcasecmp(const char *a, const char *b) {
    return strnatcmp_impl(a, b, true);
}
