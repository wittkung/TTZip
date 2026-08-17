#ifndef CTTZIP_ZIP_WRITE_INTERNAL_H
#define CTTZIP_ZIP_WRITE_INTERNAL_H

#include "CTTZipBridge_ZipWrite.h"
#include "CTTZipCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

typedef struct {
    char src_path[4096];
    char rel_path[4096];
    bool is_directory;
    bool is_mmapped;
    int64_t uncompressed_size;
    int64_t compressed_size;
    uint32_t crc32;
    uint16_t compression_method;
    uint16_t actual_method;
    void* compressed_payload;
    size_t arena_offset;
    size_t arena_cap;
} ttzip_c_item_t;

typedef struct {
    ttzip_c_item_t* items;
    size_t count;
    size_t capacity;
} ttzip_c_item_list_t;

int ttzip_write_zip_archive_disk(const char* output_zip_path, ttzip_c_item_list_t* list, bool has_password);

#endif
