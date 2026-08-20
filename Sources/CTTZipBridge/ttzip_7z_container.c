// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_7z_container.h"
#include "include/CTTZipCRC32Neon.h"
#include <string.h>

const uint8_t TTZIP_7Z_MAGIC[6] = { '7', 'z', 0xBC, 0xAF, 0x27, 0x1C };

static inline void write_le32(uint8_t *p, uint32_t val) {
    p[0] = (uint8_t)(val & 0xFF);
    p[1] = (uint8_t)((val >> 8) & 0xFF);
    p[2] = (uint8_t)((val >> 16) & 0xFF);
    p[3] = (uint8_t)((val >> 24) & 0xFF);
}

static inline void write_le64(uint8_t *p, uint64_t val) {
    write_le32(p, (uint32_t)(val & 0xFFFFFFFF));
    write_le32(p + 4, (uint32_t)(val >> 32));
}

size_t ttzip_7z_write_signature_header(
    uint64_t next_header_offset,
    uint64_t next_header_size,
    uint32_t next_header_crc,
    uint8_t dst_header[TTZIP_7Z_SIGNATURE_SIZE]
) {
    if (!dst_header) return 0;

    memset(dst_header, 0, TTZIP_7Z_SIGNATURE_SIZE);

    /* 1. Signature: 6 bytes */
    memcpy(dst_header, TTZIP_7Z_MAGIC, 6);

    /* 2. Version: 2 bytes (0.4) */
    dst_header[6] = 0x00;
    dst_header[7] = 0x04;

    /* 3. NextHeader fields (offsets 12..31) */
    write_le64(dst_header + 12, next_header_offset);
    write_le64(dst_header + 20, next_header_size);
    write_le32(dst_header + 28, next_header_crc);

    /* 4. StartHeader CRC (CRC32 of bytes 12..31, written to bytes 8..11) */
    uint32_t start_hdr_crc = ttzip_crc32_fast(0, dst_header + 12, 20);
    write_le32(dst_header + 8, start_hdr_crc);

    return TTZIP_7Z_SIGNATURE_SIZE;
}
