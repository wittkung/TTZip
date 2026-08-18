// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file CTTZipParser.h
 * @brief Little-endian fast unaligned readers/writers and ZIP header parsing primitives.
 */

#ifndef CTTZIP_PARSER_H
#define CTTZIP_PARSER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

// Safe Little-Endian Readers (100% ARM64 Unaligned Access Safe)
static inline uint16_t read_u16_le(const void* ptr) {
    uint16_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}

static inline uint32_t read_u32_le(const void* ptr) {
    uint32_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}

static inline uint64_t read_u64_le(const void* ptr) {
    uint64_t val;
    memcpy(&val, ptr, sizeof(val));
    return val;
}

// Safe Little-Endian Writers (100% ARM64 Unaligned Access Safe)
static inline void write_u16_le(void* ptr, uint16_t val) {
    memcpy(ptr, &val, sizeof(val));
}

static inline void write_u32_le(void* ptr, uint32_t val) {
    memcpy(ptr, &val, sizeof(val));
}

static inline void write_u64_le(void* ptr, uint64_t val) {
    memcpy(ptr, &val, sizeof(val));
}

// Struct for Zip Central Directory Entry Metadata
typedef struct {
    char rel_path[2048];
    uint64_t uncompressed_size;
    uint64_t compressed_size;
    uint64_t lfh_offset;
    uint32_t crc32;
    uint16_t compression_method;
    uint16_t actual_method;
    uint16_t flag;
    uint8_t aes_strength;
    bool is_directory;
    bool is_encrypted;
} ttzip_parsed_entry_t;

// Struct for Zip EOCD Info
typedef struct {
    uint64_t cd_offset;
    uint64_t cd_size;
    uint64_t total_entries;
} ttzip_eocd_info_t;

// Defensive Parser API
bool ttzip_find_eocd(const uint8_t* mapped, size_t file_size, ttzip_eocd_info_t* out_eocd);
bool ttzip_parse_cdfh_entry(const uint8_t* mapped, size_t file_size, size_t curr_pos, ttzip_parsed_entry_t* out_entry, size_t* out_next_pos);

#ifdef __cplusplus
}
#endif

#endif // CTTZIP_PARSER_H
