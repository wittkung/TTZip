// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_tar_container.h"
#include <string.h>
#include <stdio.h>

static void format_octal(char *dst, size_t size, uint64_t val) {
    if (size == 0) return;
    char fmt[16];
    snprintf(fmt, sizeof(fmt), "%%0%zuo", size - 1);
    char tmp[32];
    snprintf(tmp, sizeof(tmp), fmt, (unsigned long long)val);
    memcpy(dst, tmp, size - 1);
    dst[size - 1] = '\0';
}

size_t ttzip_tar_write_header(
    const ttzip_tar_entry_meta_t *meta,
    uint8_t dst_block[TTZIP_TAR_BLOCK_SIZE]
) {
    if (!meta || !dst_block) return 0;

    memset(dst_block, 0, TTZIP_TAR_BLOCK_SIZE);

    /* 1. Name (100 bytes) */
    const char *name = meta->path ? meta->path : "unnamed";
    strncpy((char *)dst_block, name, 100);

    /* 2. Mode (8 bytes) */
    uint32_t mode = meta->mode ? (meta->mode & 07777) : (meta->is_directory ? 0755 : 0644);
    format_octal((char *)dst_block + 100, 8, mode);

    /* 3. UID & GID (8 bytes each) */
    format_octal((char *)dst_block + 108, 8, meta->uid);
    format_octal((char *)dst_block + 116, 8, meta->gid);

    /* 4. Size (12 bytes) */
    uint64_t sz = meta->is_directory ? 0 : meta->file_size;
    format_octal((char *)dst_block + 124, 12, sz);

    /* 5. Mtime (12 bytes) */
    uint32_t mtime = meta->mtime ? meta->mtime : 1700000000;
    format_octal((char *)dst_block + 136, 12, mtime);

    /* 6. Checksum placeholder: 8 spaces (0x20) */
    memset(dst_block + 148, ' ', 8);

    /* 7. Typeflag (1 byte) */
    dst_block[156] = meta->is_directory ? '5' : '0';

    /* 8. Magic & Version (6 + 2 bytes) */
    memcpy(dst_block + 257, "ustar\0", 6);
    memcpy(dst_block + 263, "00", 2);

    /* 9. Uname & Gname (32 bytes each) */
    const char *uname = meta->uname ? meta->uname : "staff";
    const char *gname = meta->gname ? meta->gname : "staff";
    strncpy((char *)dst_block + 265, uname, 32);
    strncpy((char *)dst_block + 297, gname, 32);

    /* 10. Calculate Checksum */
    uint32_t chksum = 0;
    for (size_t i = 0; i < TTZIP_TAR_BLOCK_SIZE; i++) {
        chksum += dst_block[i];
    }

    char chk_str[8];
    snprintf(chk_str, sizeof(chk_str), "%06o", chksum);
    memcpy(dst_block + 148, chk_str, 6);
    dst_block[154] = '\0';
    dst_block[155] = ' ';

    return TTZIP_TAR_BLOCK_SIZE;
}

size_t ttzip_tar_write_trailer(
    uint8_t dst_trailer[1024]
) {
    if (!dst_trailer) return 0;
    memset(dst_trailer, 0, 1024);
    return 1024;
}
