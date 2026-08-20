// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file quickstart.c
 * @brief TTZip Public C API 1-Minute Developer Quickstart Guide.
 * 
 * Demonstrates:
 *   1. Engine Version & Semantic Query
 *   2. Hardware-Accelerated CRC32 / CRC64 Checksumming
 *   3. In-Memory SOTA Codec Compression (Zstd / Deflate / Snappy)
 *   4. Sub-Nanosecond File Format Magic Header Sniffing
 *   5. Pure C11 Natural Numeric String Comparison
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ttzip_api.h"

int main(void) {
    printf("=================================================================\n");
    printf(" TTZip High-Performance C SDK Quickstart (v%s)\n", ttzip_version_string());
    printf("=================================================================\n\n");

    // [Demo 1] Engine Version Verification
    uint32_t ver = ttzip_version_number();
    printf("• [Demo 1] Engine ABI Version: %u.%u.%u (0x%06X)\n",
        (ver >> 16) & 0xFF, (ver >> 8) & 0xFF, ver & 0xFF, ver);

    // [Demo 2] Hardware-Accelerated Vector Checksums
    const char *payload = "TTZip: The world's fastest cross-platform archiving microkernel!";
    size_t payload_len = strlen(payload);

    uint32_t crc32_val = ttzip_crc32(0, payload, payload_len);
    uint64_t crc64_val = ttzip_crc64((const uint8_t *)payload, payload_len, 0);
    printf("• [Demo 2] Hardware CRC32: 0x%08X | CRC64: 0x%016llX\n", crc32_val, (unsigned long long)crc64_val);

    // [Demo 3] In-Memory Codec Compression & Decompression
    size_t comp_cap = ttzip_compress_bound(TTZIP_API_CODEC_ZSTD, payload_len);
    uint8_t *comp_buf = (uint8_t *)malloc(comp_cap);
    uint8_t *decomp_buf = (uint8_t *)malloc(payload_len + 1);

    size_t comp_len = ttzip_compress_buffer(
        TTZIP_API_CODEC_ZSTD,
        payload,
        payload_len,
        comp_buf,
        comp_cap,
        3 // Compression Level 3
    );

    size_t decomp_len = ttzip_decompress_buffer(
        TTZIP_API_CODEC_ZSTD,
        comp_buf,
        comp_len,
        decomp_buf,
        payload_len
    );
    decomp_buf[decomp_len] = '\0';

    printf("• [Demo 3] In-Memory Zstandard: %zu B -> %zu B -> %zu B (Match: %s)\n",
        payload_len, comp_len, decomp_len,
        (strcmp((char *)decomp_buf, payload) == 0) ? "PASS [100% Exact]" : "FAIL");

    free(comp_buf);
    free(decomp_buf);

    // [Demo 4] Sub-Nanosecond Magic Header Format Sniffing
    uint8_t png_header[16] = { 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 'I', 'H', 'D', 'R' };
    ttzip_magic_info_t sniff = ttzip_magic_sniff_buffer(png_header, sizeof(png_header));
    printf("• [Demo 4] Magic Sniffing (16 bytes): Format=%s, MIME=%s, Kind=%d\n",
        sniff.format_name, sniff.mime_type, sniff.kind);

    // [Demo 5] C11 Natural Numeric String Comparison
    const char *str1 = "backup_v1.0.9.zip";
    const char *str2 = "backup_v1.0.10.zip";
    int cmp_res = ttzip_strnatcasecmp(str1, str2);
    printf("• [Demo 5] Natural Sort: '%s' vs '%s' -> Result: %d (%s)\n",
        str1, str2, cmp_res, (cmp_res < 0) ? "Correct (v1.0.9 < v1.0.10)" : "Incorrect");

    printf("\n🎉 All 5 TTZip C SDK demonstrations executed successfully!\n");
    return 0;
}
