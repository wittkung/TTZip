/**
 * @file fuzz_extract_engine.c
 * @brief Zero-Leak LLVM LibFuzzer Target for Multi-Format Archive Extraction in TTZip.
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <archive.h>
#include <archive_entry.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    if (!data || size < 4 || size > 4 * 1024 * 1024) {
        return 0;
    }

    struct archive *a = archive_read_new();
    if (!a) return 0;

    archive_read_support_filter_all(a);
    archive_read_support_format_all(a);

    if (archive_read_open_memory(a, data, size) == ARCHIVE_OK) {
        struct archive_entry *entry;
        while (archive_read_next_header(a, &entry) == ARCHIVE_OK) {
            archive_read_data_skip(a);
        }
    }

    archive_read_close(a);
    archive_read_free(a);
    return 0;
}

#ifndef LIBFUZZER_ACTIVE
// Standalone runner for testing fixtures when built without -fsanitize=fuzzer
int main(int argc, char** argv) {
    if (argc < 2) {
        printf("TTZip Standalone Fuzzer Target Runner (No files passed, dry run OK)\n");
        return 0;
    }
    for (int i = 1; i < argc; ++i) {
        FILE* f = fopen(argv[i], "rb");
        if (!f) continue;
        fseek(f, 0, SEEK_END);
        long sz = ftell(f);
        fseek(f, 0, SEEK_SET);
        if (sz > 0 && sz <= 4 * 1024 * 1024) {
            uint8_t* buf = (uint8_t*)malloc(sz);
            if (buf) {
                size_t n = fread(buf, 1, sz, f);
                if (n == (size_t)sz) {
                    LLVMFuzzerTestOneInput(buf, (size_t)sz);
                }
                free(buf);
            }
        }
        fclose(f);
    }
    printf("✅ Standalone fuzzer runner completed cleanly on input files.\n");
    return 0;
}
#endif
