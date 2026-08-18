// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_dmg_demux.h
 * @brief In-process native C UDIF (Apple DMG) container parser and LZFSE chunk demuxer.
 */

#ifndef TTZIP_DMG_DEMUX_H
#define TTZIP_DMG_DEMUX_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "CTTZipCommon.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_DMG_KOLY_MAGIC 0x6B6F6C79U // 'koly'
#define TTZIP_DMG_MISH_MAGIC 0x6D697368U // 'mish'

// UDIF Chunk Types
#define TTZIP_UDIF_CHUNK_ZERO        0x00000000U
#define TTZIP_UDIF_CHUNK_RAW         0x00000001U
#define TTZIP_UDIF_CHUNK_IGNORE      0x00000002U
#define TTZIP_UDIF_CHUNK_COMMENT     0x7FFFFFFEU
#define TTZIP_UDIF_CHUNK_TERMINATOR  0xFFFFFFFFU
#define TTZIP_UDIF_CHUNK_ADC         0x80000004U
#define TTZIP_UDIF_CHUNK_ZLIB        0x80000005U
#define TTZIP_UDIF_CHUNK_BZIP2       0x80000006U
#define TTZIP_UDIF_CHUNK_LZFSE       0x80000007U
#define TTZIP_UDIF_CHUNK_LZMA        0x80000008U

#pragma pack(push, 1)

typedef struct {
    uint32_t signature;              // 'koly' (0x6B6F6C79)
    uint32_t version;                // 4
    uint32_t header_size;            // 512
    uint32_t flags;
    uint64_t running_data_fork_off;
    uint64_t data_fork_offset;       // 0
    uint64_t data_fork_length;
    uint64_t rsrc_fork_offset;
    uint64_t rsrc_fork_length;
    uint32_t segment_number;
    uint32_t segment_count;
    uint8_t  segment_id[16];
    uint32_t data_checksum_type;
    uint32_t data_checksum_size;
    uint32_t data_checksum[32];
    uint64_t xml_offset;
    uint64_t xml_length;
    uint8_t  reserved1[120];
    uint32_t master_checksum_type;
    uint32_t master_checksum_size;
    uint32_t master_checksum[32];
    uint32_t image_variant;
    uint64_t sector_count;
    uint32_t reserved2[3];
} ttzip_udif_koly_t;

typedef struct {
    uint32_t signature;            // 'mish' (0x6D697368)
    uint32_t version;              // 1
    uint64_t sector_number;
    uint64_t sector_count;
    uint64_t data_offset;
    uint32_t buffers_needed;
    uint32_t block_descriptors;
    uint32_t reserved[6];
    uint32_t checksum_type;
    uint32_t checksum_size;
    uint32_t checksum[32];
    uint32_t number_of_chunks;
} ttzip_udif_mish_t;

typedef struct {
    uint32_t entry_type;
    uint32_t comment;
    uint64_t sector_number;
    uint64_t sector_count;
    uint64_t compressed_offset;
    uint64_t compressed_length;
} ttzip_udif_chunk_entry_t;

#pragma pack(pop)

/**
 * @brief Probes if a file is a valid Apple UDIF DMG with 'koly' trailer.
 */
bool ttzip_dmg_probe(const char* file_path);

/**
 * @brief Parses DMG 'koly' trailer from end of file.
 */
int ttzip_dmg_read_koly(const char* file_path, ttzip_udif_koly_t* out_koly);

/**
 * @brief Decompresses all partitions from a DMG file into a raw disk image file.
 *        Supports RAW, ZERO, ZLIB, BZIP2, LZFSE (0x80000006/0x80000007), LZMA chunks.
 *
 * @param dmg_path Source .dmg file path.
 * @param raw_out_path Target decompressed raw .img/.iso file path.
 * @return TTZIP_OK (0) on success, or error code.
 */
int ttzip_dmg_decompress_to_raw(const char* dmg_path, const char* raw_out_path);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_DMG_DEMUX_H */
