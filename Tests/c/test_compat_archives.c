/**
 * @file test_compat_archives.c
 * @brief Backward Compatibility Test Suite for Historical & Non-Standard Archives in TTZip.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "CTTZipBridge_Archive.h"
#include "ttzip_tar_native.h"
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>

static void cleanup_test_dir(const char* path) {
    DIR* d = opendir(path);
    if (!d) {
        unlink(path);
        return;
    }
    struct dirent* entry;
    while ((entry = readdir(d)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
        char subpath[1024];
        snprintf(subpath, sizeof(subpath), "%s/%s", path, entry->d_name);
        cleanup_test_dir(subpath);
    }
    closedir(d);
    rmdir(path);
}

TEST_CASE(test_compat_legacy_zip_extraction) {
    const char* zip_path = "tests/fixtures/compat/compat_zip_standard.zip";
    const char* out_dir = "build/test_compat_zip_out";
    cleanup_test_dir(out_dir);

    int rc = ttzip_extract_archive(zip_path, out_dir);
    ASSERT_EQ(rc, TTZIP_OK);

    char target_file[512];
    snprintf(target_file, sizeof(target_file), "%s/legacy_doc.txt", out_dir);
    FILE* f = fopen(target_file, "rb");
    ASSERT_NOT_NULL(f);
    if (f) {
        char buf[128] = {0};
        size_t n = fread(buf, 1, sizeof(buf) - 1, f);
        fclose(f);
        ASSERT_TRUE(n > 0);
        ASSERT_TRUE(strstr(buf, "Legacy backward compatibility") != NULL);
    }

    cleanup_test_dir(out_dir);
}

TEST_CASE(test_compat_gtar_longlink_extraction) {
    const char* tar_path = "tests/fixtures/compat/compat_gtar_longlink.tar";
    const char* out_dir = "build/test_compat_tar_out";
    cleanup_test_dir(out_dir);

    int rc = ttzip_extract_tar_native_c(tar_path, out_dir, false);
    ASSERT_EQ(rc, TTZIP_OK);

    const char* deep_path = "build/test_compat_tar_out/very_long_path_directory_structure_exceeding_one_hundred_bytes_in_length_for_posix_compat/sub_path/target_file.txt";
    FILE* f = fopen(deep_path, "rb");
    ASSERT_NOT_NULL(f);
    if (f) {
        char buf[128] = {0};
        size_t n = fread(buf, 1, sizeof(buf) - 1, f);
        (void)n;
        fclose(f);
        ASSERT_TRUE(strstr(buf, "longlink extraction payload") != NULL);
    }

    cleanup_test_dir(out_dir);
}

void run_compat_archives_tests(void) {
    ttzip_test_init_suite("Historical Archive Backward Compatibility");
    RUN_TEST(test_compat_legacy_zip_extraction);
    RUN_TEST(test_compat_gtar_longlink_extraction);
    ttzip_test_finish_suite();
}
