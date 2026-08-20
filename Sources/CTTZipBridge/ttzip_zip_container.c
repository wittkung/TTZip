// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_zip_container.h"
#include <string.h>

static inline void write_le16(uint16_t v, uint8_t *p) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
}

static inline void write_le32(uint32_t v, uint8_t *p) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
    p[2] = (uint8_t)((v >> 16) & 0xFF);
    p[3] = (uint8_t)((v >> 24) & 0xFF);
}

size_t ttzip_zip_write_local_header(
    const ttzip_zip_entry_meta_t *meta,
    void *out_buf,
    size_t out_buf_cap
) {
    if (!meta || !out_buf) return 0;
    size_t required = TTZIP_ZIP_LOCAL_HEADER_SIZE + meta->file_name_len;
    if (out_buf_cap < required) return 0;

    uint8_t *p = (uint8_t *)out_buf;
    write_le32(TTZIP_ZIP_LOCAL_HEADER_MAGIC, p + 0);
    write_le16(20, p + 4); /* version needed to extract (2.0) */
    
    uint16_t flags = 0;
    if (meta->is_utf8) flags |= (1 << 11); /* Language encoding flag (EFS) */
    write_le16(flags, p + 6);
    write_le16(meta->compression_method, p + 8);
    write_le32(meta->dos_datetime, p + 10);
    write_le32(meta->crc32, p + 14);
    write_le32((uint32_t)meta->compressed_size, p + 18);
    write_le32((uint32_t)meta->uncompressed_size, p + 22);
    write_le16(meta->file_name_len, p + 26);
    write_le16(0, p + 28); /* extra field length */

    if (meta->file_name && meta->file_name_len > 0) {
        memcpy(p + TTZIP_ZIP_LOCAL_HEADER_SIZE, meta->file_name, meta->file_name_len);
    }
    return required;
}

size_t ttzip_zip_write_cd_header(
    const ttzip_zip_entry_meta_t *meta,
    void *out_buf,
    size_t out_buf_cap
) {
    if (!meta || !out_buf) return 0;
    size_t required = TTZIP_ZIP_CD_HEADER_SIZE + meta->file_name_len;
    if (out_buf_cap < required) return 0;

    uint8_t *p = (uint8_t *)out_buf;
    write_le32(TTZIP_ZIP_CD_HEADER_MAGIC, p + 0);
    write_le16(0x0314, p + 4); /* version made by (UNIX 2.0) */
    write_le16(20, p + 6);     /* version needed to extract (2.0) */
    
    uint16_t flags = 0;
    if (meta->is_utf8) flags |= (1 << 11);
    write_le16(flags, p + 8);
    write_le16(meta->compression_method, p + 10);
    write_le32(meta->dos_datetime, p + 12);
    write_le32(meta->crc32, p + 16);
    write_le32((uint32_t)meta->compressed_size, p + 20);
    write_le32((uint32_t)meta->uncompressed_size, p + 24);
    write_le16(meta->file_name_len, p + 28);
    write_le16(0, p + 30); /* extra field len */
    write_le16(0, p + 32); /* file comment len */
    write_le16(0, p + 34); /* disk number start */
    write_le16(0, p + 36); /* internal file attributes */
    write_le32(meta->external_attributes, p + 38);
    write_le32((uint32_t)meta->local_header_offset, p + 42);

    if (meta->file_name && meta->file_name_len > 0) {
        memcpy(p + TTZIP_ZIP_CD_HEADER_SIZE, meta->file_name, meta->file_name_len);
    }
    return required;
}

size_t ttzip_zip_write_eocd(
    uint16_t entry_count,
    uint32_t cd_size,
    uint32_t cd_offset,
    void *out_buf,
    size_t out_buf_cap
) {
    if (!out_buf || out_buf_cap < TTZIP_ZIP_EOCD_SIZE) return 0;

    uint8_t *p = (uint8_t *)out_buf;
    write_le32(TTZIP_ZIP_EOCD_MAGIC, p + 0);
    write_le16(0, p + 4);           /* number of this disk */
    write_le16(0, p + 6);           /* disk where central directory starts */
    write_le16(entry_count, p + 8);  /* number of central directory records on this disk */
    write_le16(entry_count, p + 10); /* total number of central directory records */
    write_le32(cd_size, p + 12);     /* size of central directory */
    write_le32(cd_offset, p + 16);   /* offset of start of central directory */
    write_le16(0, p + 20);          /* comment length */
    return TTZIP_ZIP_EOCD_SIZE;
}
