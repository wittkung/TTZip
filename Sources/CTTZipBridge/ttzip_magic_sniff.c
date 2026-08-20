// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_magic_sniff.h"
#include "include/ttzip_fs.h"
#include <string.h>

ttzip_magic_info_t ttzip_magic_sniff_buffer(const void *buf, size_t len) {
    ttzip_magic_info_t res;
    memset(&res, 0, sizeof(res));
    res.kind = TTZIP_KIND_UNKNOWN;
    res.format_name = "BINARY";
    res.mime_type = "application/octet-stream";

    if (!buf || len < 4) return res;

    const uint8_t *b = (const uint8_t *)buf;

    /* 1. Archives */
    if (len >= 4 && b[0] == 'P' && b[1] == 'K' && b[2] == 0x03 && b[3] == 0x04) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "ZIP";
        res.mime_type = "application/zip";
        res.is_archive = true;
        return res;
    }
    if (len >= 6 && b[0] == '7' && b[1] == 'z' && b[2] == 0xBC && b[3] == 0xAF && b[4] == 0x27 && b[5] == 0x1C) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "7Z";
        res.mime_type = "application/x-7z-compressed";
        res.is_archive = true;
        return res;
    }
    if (len >= 2 && b[0] == 0x1F && b[1] == 0x8B) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "GZIP";
        res.mime_type = "application/gzip";
        res.is_archive = true;
        return res;
    }
    if (len >= 6 && b[0] == 0xFD && b[1] == '7' && b[2] == 'z' && b[3] == 'X' && b[4] == 'Z' && b[5] == 0x00) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "XZ";
        res.mime_type = "application/x-xz";
        res.is_archive = true;
        return res;
    }
    if (len >= 4 && b[0] == 0x28 && b[1] == 0xB5 && b[2] == 0x2F && b[3] == 0xFD) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "ZSTD";
        res.mime_type = "application/zstd";
        res.is_archive = true;
        return res;
    }
    if (len >= 3 && b[0] == 'B' && b[1] == 'Z' && b[2] == 'h') {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "BZIP2";
        res.mime_type = "application/x-bzip2";
        res.is_archive = true;
        return res;
    }
    if (len >= 7 && b[0] == 'R' && b[1] == 'a' && b[2] == 'r' && b[3] == '!' && b[4] == 0x1A && b[5] == 0x07) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "RAR";
        res.mime_type = "application/x-rar-compressed";
        res.is_archive = true;
        return res;
    }
    if (len >= 265 && memcmp(b + 257, "ustar", 5) == 0) {
        res.kind = TTZIP_KIND_ARCHIVE;
        res.format_name = "TAR";
        res.mime_type = "application/x-tar";
        res.is_archive = true;
        return res;
    }

    /* 2. Images */
    if (len >= 8 && b[0] == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G' && b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
        res.kind = TTZIP_KIND_IMAGE;
        res.format_name = "PNG";
        res.mime_type = "image/png";
        res.is_media = true;
        return res;
    }
    if (len >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
        res.kind = TTZIP_KIND_IMAGE;
        res.format_name = "JPEG";
        res.mime_type = "image/jpeg";
        res.is_media = true;
        return res;
    }
    if (len >= 6 && (memcmp(b, "GIF87a", 6) == 0 || memcmp(b, "GIF89a", 6) == 0)) {
        res.kind = TTZIP_KIND_IMAGE;
        res.format_name = "GIF";
        res.mime_type = "image/gif";
        res.is_media = true;
        return res;
    }
    if (len >= 12 && memcmp(b, "RIFF", 4) == 0 && memcmp(b + 8, "WEBP", 4) == 0) {
        res.kind = TTZIP_KIND_IMAGE;
        res.format_name = "WEBP";
        res.mime_type = "image/webp";
        res.is_media = true;
        return res;
    }
    if (len >= 2 && b[0] == 'B' && b[1] == 'M') {
        res.kind = TTZIP_KIND_IMAGE;
        res.format_name = "BMP";
        res.mime_type = "image/bmp";
        res.is_media = true;
        return res;
    }

    /* 3. Documents & Media */
    if (len >= 4 && memcmp(b, "%PDF", 4) == 0) {
        res.kind = TTZIP_KIND_PDF;
        res.format_name = "PDF";
        res.mime_type = "application/pdf";
        return res;
    }
    if (len >= 12 && memcmp(b + 4, "ftyp", 4) == 0) {
        res.kind = TTZIP_KIND_VIDEO;
        res.format_name = "MP4";
        res.mime_type = "video/mp4";
        res.is_media = true;
        return res;
    }
    if (len >= 3 && memcmp(b, "ID3", 3) == 0) {
        res.kind = TTZIP_KIND_AUDIO;
        res.format_name = "MP3";
        res.mime_type = "audio/mpeg";
        res.is_media = true;
        return res;
    }
    if (len >= 4 && memcmp(b, "fLaC", 4) == 0) {
        res.kind = TTZIP_KIND_AUDIO;
        res.format_name = "FLAC";
        res.mime_type = "audio/flac";
        res.is_media = true;
        return res;
    }

    return res;
}

ttzip_magic_info_t ttzip_magic_sniff_file(const char *utf8_path) {
    if (!utf8_path) {
        ttzip_magic_info_t res;
        memset(&res, 0, sizeof(res));
        return res;
    }
    uint64_t len = 0;
    const void *mapped = ttzip_fs_mmap_read(utf8_path, &len);
    if (!mapped) {
        ttzip_magic_info_t res;
        memset(&res, 0, sizeof(res));
        return res;
    }
    ttzip_magic_info_t res = ttzip_magic_sniff_buffer(mapped, (size_t)len);
    ttzip_fs_munmap(mapped, len);
    return res;
}
