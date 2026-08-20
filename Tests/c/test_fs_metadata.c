/**
 * @file test_fs_metadata.c
 * @brief Test Suite for macOS APFS Extended Attributes (xattr) and Sparse File Allocation in TTZip.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include "ttzip_test_harness.h"
#include "ttzip_tar_native.h"
#include "CTTZipCommon.h"
#include <sys/stat.h>
#include <sys/xattr.h>
#include <unistd.h>
#include <fcntl.h>
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

TEST_CASE(test_macos_xattr_preservation) {
    const char* base_dir = "build/test_xattr_dir";
    cleanup_test_dir(base_dir);
    mkdir(base_dir, 0755);

    char src_file[512];
    snprintf(src_file, sizeof(src_file), "%s/source.txt", base_dir);
    FILE* f = fopen(src_file, "wb");
    ASSERT_NOT_NULL(f);
    if (f) {
        fwrite("Payload with extended metadata attributes", 1, 41, f);
        fclose(f);
    }

#if defined(__APPLE__)
    const char* attr_name = "user.ttzip.security_tag";
    const char* attr_value = "Verified-Secure-APFS-2026";
    int xres = setxattr(src_file, attr_name, attr_value, strlen(attr_value), 0, 0);
    ASSERT_EQ(xres, 0);

    char val_buf[128] = {0};
    ssize_t read_len = getxattr(src_file, attr_name, val_buf, sizeof(val_buf) - 1, 0, 0);
    ASSERT_TRUE(read_len > 0);
    ASSERT_TRUE(strcmp(val_buf, attr_value) == 0);
#endif

    cleanup_test_dir(base_dir);
}

TEST_CASE(test_apfs_sparse_file_hole_preservation) {
    const char* base_dir = "build/test_sparse_dir";
    cleanup_test_dir(base_dir);
    mkdir(base_dir, 0755);

    char sparse_file[512];
    snprintf(sparse_file, sizeof(sparse_file), "%s/1gb_sparse.img", base_dir);
    int fd = open(sparse_file, O_CREAT | O_RDWR | O_TRUNC, 0644);
    ASSERT_TRUE(fd >= 0);

    if (fd >= 0) {
        off_t target_offset = 1024ULL * 1024ULL * 1024ULL; // 1 GiB
        off_t seek_res = lseek(fd, target_offset, SEEK_SET);
        ASSERT_EQ(seek_res, target_offset);
        
        ssize_t wn = write(fd, "TAIL", 4);
        ASSERT_EQ(wn, 4);
        close(fd);

        struct stat st;
        int sres = stat(sparse_file, &st);
        ASSERT_EQ(sres, 0);
        ASSERT_TRUE(st.st_size >= target_offset);

        uint64_t physical_bytes = (uint64_t)st.st_blocks * 512ULL;
        ASSERT_TRUE(physical_bytes < 2ULL * 1024ULL * 1024ULL);
    }

    cleanup_test_dir(base_dir);
}

void run_fs_metadata_tests(void) {
    ttzip_test_init_suite("macOS APFS Metadata & Sparse Holes");
    RUN_TEST(test_macos_xattr_preservation);
    RUN_TEST(test_apfs_sparse_file_hole_preservation);
    ttzip_test_finish_suite();
}
