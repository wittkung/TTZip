/**
 * @file test_magic_sniff.c
 * @brief Unit tests for binary magic sniffing and format identification.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_magic_sniff.h"

TEST_CASE(test_zip_magic_sniffing) {
    // Standard ZIP Local File Header: "PK\x03\x04"
    const uint8_t zip_header[] = { 0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00,
                                   0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    ttzip_magic_info_t info = ttzip_magic_sniff_buffer(zip_header, sizeof(zip_header));
    ASSERT_TRUE(info.is_archive);
    ASSERT_EQ(info.kind, TTZIP_KIND_ARCHIVE);
    ASSERT_STR_EQ(info.format_name, "ZIP");
    ASSERT_STR_EQ(info.mime_type, "application/zip");
}

TEST_CASE(test_7z_magic_sniffing) {
    // Standard 7-Zip Header: "7z\xBC\xAF\x27\x1C"
    const uint8_t sevenz_header[] = { 0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C, 0x00, 0x04 };
    ttzip_magic_info_t info = ttzip_magic_sniff_buffer(sevenz_header, sizeof(sevenz_header));
    ASSERT_TRUE(info.is_archive);
    ASSERT_EQ(info.kind, TTZIP_KIND_ARCHIVE);
    ASSERT_STR_EQ(info.format_name, "7Z");
}

TEST_CASE(test_tar_gz_and_xz_magic_sniffing) {
    // GZIP Header: 0x1F, 0x8B, 0x08
    const uint8_t gz_header[] = { 0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00 };
    ttzip_magic_info_t gz_info = ttzip_magic_sniff_buffer(gz_header, sizeof(gz_header));
    ASSERT_TRUE(gz_info.is_archive);
    ASSERT_STR_EQ(gz_info.format_name, "GZIP");

    // XZ Header: 0xFD, '7', 'z', 'X', 'Z', 0x00
    const uint8_t xz_header[] = { 0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00 };
    ttzip_magic_info_t xz_info = ttzip_magic_sniff_buffer(xz_header, sizeof(xz_header));
    ASSERT_TRUE(xz_info.is_archive);
    ASSERT_STR_EQ(xz_info.format_name, "XZ");

    // Zstandard Header: 0x28, 0xB5, 0x2F, 0xFD
    const uint8_t zst_header[] = { 0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x00 };
    ttzip_magic_info_t zst_info = ttzip_magic_sniff_buffer(zst_header, sizeof(zst_header));
    ASSERT_TRUE(zst_info.is_archive);
    ASSERT_STR_EQ(zst_info.format_name, "ZSTD");
}

TEST_CASE(test_media_and_pdf_sniffing) {
    // PNG Header: 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A
    const uint8_t png_header[] = { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
    ttzip_magic_info_t png_info = ttzip_magic_sniff_buffer(png_header, sizeof(png_header));
    ASSERT_TRUE(png_info.is_media);
    ASSERT_EQ(png_info.kind, TTZIP_KIND_IMAGE);
    ASSERT_STR_EQ(png_info.format_name, "PNG");

    // PDF Header: "%PDF-1.7"
    const uint8_t pdf_header[] = "%PDF-1.7\n%abc";
    ttzip_magic_info_t pdf_info = ttzip_magic_sniff_buffer(pdf_header, 12);
    ASSERT_EQ(pdf_info.kind, TTZIP_KIND_PDF);
    ASSERT_STR_EQ(pdf_info.format_name, "PDF");
}

TEST_CASE(test_short_and_unknown_buffer_safety) {
    // 0 bytes buffer
    ttzip_magic_info_t empty_info = ttzip_magic_sniff_buffer(NULL, 0);
    ASSERT_EQ(empty_info.kind, TTZIP_KIND_UNKNOWN);
    ASSERT_FALSE(empty_info.is_archive);

    // 2 bytes non-matching buffer
    const uint8_t random_bytes[] = { 0x42, 0x13 };
    ttzip_magic_info_t rand_info = ttzip_magic_sniff_buffer(random_bytes, sizeof(random_bytes));
    ASSERT_EQ(rand_info.kind, TTZIP_KIND_UNKNOWN);
}

void run_magic_sniff_tests(void) {
    ttzip_test_init_suite("Magic Sniffing");
    RUN_TEST(test_zip_magic_sniffing);
    RUN_TEST(test_7z_magic_sniffing);
    RUN_TEST(test_tar_gz_and_xz_magic_sniffing);
    RUN_TEST(test_media_and_pdf_sniffing);
    RUN_TEST(test_short_and_unknown_buffer_safety);
    ttzip_test_finish_suite();
}
