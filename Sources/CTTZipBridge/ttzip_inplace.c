// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_inplace.h"
#include "include/ttzip_zip_container.h"
#include "include/ttzip_fs.h"
#include "include/ttzip_api.h"
#include "include/CTTZipCRC32Neon.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int ttzip_inplace_append_file(
    const char *archive_path,
    const char *new_file_path,
    const char *entry_name
) {
    if (!archive_path || !new_file_path) return TTZIP_API_ERR_INVALID_PARAM;

    uint64_t file_len = 0;
    const void *mapped = ttzip_fs_mmap_read(new_file_path, &file_len);
    if (!mapped && file_len > 0) return TTZIP_API_ERR_IO_FAILURE;

    FILE *fp = fopen(archive_path, "r+b");
    if (!fp) {
        if (mapped) ttzip_fs_munmap(mapped, file_len);
        return TTZIP_API_ERR_IO_FAILURE;
    }

    /* Seek to end */
    fseek(fp, 0, SEEK_END);
    long arc_size = ftell(fp);
    if (arc_size < 22) {
        fclose(fp);
        if (mapped) ttzip_fs_munmap(mapped, file_len);
        return TTZIP_API_ERR_CORRUPT_DATA;
    }

    const char *name = entry_name;
    if (!name) {
        name = strrchr(new_file_path, '/');
#if defined(_WIN32)
        if (!name) name = strrchr(new_file_path, '\\');
#endif
        name = name ? name + 1 : new_file_path;
    }

    uint32_t file_crc = mapped ? ttzip_crc32_fast(0, (const uint8_t *)mapped, (size_t)file_len) : 0;
    size_t comp_cap = ttzip_compress_bound(TTZIP_API_CODEC_DEFLATE, (size_t)file_len);
    uint8_t *comp_buf = (uint8_t *)malloc(comp_cap > 0 ? comp_cap : 1);
    size_t comp_len = 0;

    if (comp_buf && mapped && file_len > 0) {
        comp_len = ttzip_compress_buffer(TTZIP_API_CODEC_DEFLATE, mapped, (size_t)file_len, comp_buf, comp_cap, 6);
        if (comp_len == 0 || comp_len >= file_len) {
            memcpy(comp_buf, mapped, (size_t)file_len);
            comp_len = (size_t)file_len;
        }
    }

    uint64_t local_hdr_offset = (uint64_t)arc_size;

    ttzip_zip_entry_meta_t meta;
    memset(&meta, 0, sizeof(meta));
    meta.file_name = name;
    meta.file_name_len = (uint16_t)strlen(name);
    meta.crc32 = file_crc;
    meta.compressed_size = comp_len;
    meta.uncompressed_size = file_len;
    meta.local_header_offset = local_hdr_offset;
    meta.compression_method = (comp_len == file_len) ? 0 : 8;
    meta.dos_datetime = 0x58210000;
    meta.external_attributes = 0x81a40000;
    meta.is_utf8 = true;

    uint8_t local_hdr[1024];
    size_t local_hdr_len = ttzip_zip_write_local_header(&meta, local_hdr, sizeof(local_hdr));
    fwrite(local_hdr, 1, local_hdr_len, fp);

    if (comp_len > 0 && comp_buf) {
        fwrite(comp_buf, 1, comp_len, fp);
    }

    /* Write CD header for appended file */
    uint64_t cd_offset = local_hdr_offset + local_hdr_len + comp_len;
    uint8_t cd_hdr[1024];
    size_t cd_hdr_len = ttzip_zip_write_cd_header(&meta, cd_hdr, sizeof(cd_hdr));
    fwrite(cd_hdr, 1, cd_hdr_len, fp);

    /* Write updated EOCD */
    uint8_t eocd_buf[64];
    size_t eocd_len = ttzip_zip_write_eocd(1, (uint32_t)cd_hdr_len, (uint32_t)cd_offset, eocd_buf, sizeof(eocd_buf));
    fwrite(eocd_buf, 1, eocd_len, fp);

    fclose(fp);
    if (mapped) ttzip_fs_munmap(mapped, file_len);
    if (comp_buf) free(comp_buf);

    return TTZIP_API_OK;
}
