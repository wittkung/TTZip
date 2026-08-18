// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipVLMeta.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <zstd.h>

#pragma pack(push, 1)
typedef struct {
    char magic[8];            // "TTZIPVLM"
    uint32_t version;         // 1
    uint32_t layer_count;     // Number of layers
    uint64_t uncompressed_size;
    uint64_t compressed_size;
} ttzip_vlmeta_header_t;

typedef struct {
    uint64_t trailer_offset;  // File offset where header begins
    char magic[8];            // "TTZIPVLM"
} ttzip_vlmeta_footer_t;

typedef struct {
    char name[64];
    uint64_t payload_size;
} ttzip_vlmeta_wire_entry_t;
#pragma pack(pop)

int ttzip_vlmeta_append_trailer(
    const char* archive_path,
    const ttzip_vlmeta_entry_t* entries,
    size_t entry_count
) {
    if (!archive_path || !entries || entry_count == 0) return -1;

    // 1. Serialize all entries to uncompressed buffer
    size_t total_unc_bytes = 0;
    for (size_t i = 0; i < entry_count; i++) {
        total_unc_bytes += sizeof(ttzip_vlmeta_wire_entry_t) + entries[i].payload_size;
    }

    uint8_t* unc_buf = (uint8_t*)malloc(total_unc_bytes);
    if (!unc_buf) return -2;

    size_t off = 0;
    for (size_t i = 0; i < entry_count; i++) {
        ttzip_vlmeta_wire_entry_t wire;
        memset(&wire, 0, sizeof(wire));
        strncpy(wire.name, entries[i].name, sizeof(wire.name) - 1);
        wire.payload_size = (uint64_t)entries[i].payload_size;

        memcpy(unc_buf + off, &wire, sizeof(wire));
        off += sizeof(wire);

        if (entries[i].payload && entries[i].payload_size > 0) {
            memcpy(unc_buf + off, entries[i].payload, entries[i].payload_size);
            off += entries[i].payload_size;
        }
    }

    // 2. Compress via Zstd
    size_t comp_bound = ZSTD_compressBound(total_unc_bytes);
    uint8_t* comp_buf = (uint8_t*)malloc(comp_bound);
    if (!comp_buf) {
        free(unc_buf);
        return -2;
    }

    size_t actual_comp = ZSTD_compress(comp_buf, comp_bound, unc_buf, total_unc_bytes, 3);
    free(unc_buf);
    if (ZSTD_isError(actual_comp)) {
        free(comp_buf);
        return -3;
    }

    // 3. Open archive file in append mode and get current EOF offset
    int fd = open(archive_path, O_RDWR | O_CREAT, 0644);
    if (fd < 0) {
        free(comp_buf);
        return -4;
    }

    struct stat st;
    if (fstat(fd, &st) != 0) {
        close(fd);
        free(comp_buf);
        return -4;
    }
    uint64_t trailer_start_offset = (uint64_t)st.st_size;

    // 4. Construct Header & Footer
    ttzip_vlmeta_header_t header;
    memcpy(header.magic, TTZIP_VLMETA_MAGIC, 8);
    header.version = TTZIP_VLMETA_VERSION;
    header.layer_count = (uint32_t)entry_count;
    header.uncompressed_size = (uint64_t)total_unc_bytes;
    header.compressed_size = (uint64_t)actual_comp;

    ttzip_vlmeta_footer_t footer;
    footer.trailer_offset = trailer_start_offset;
    memcpy(footer.magic, TTZIP_VLMETA_MAGIC, 8);

    // 5. Append to EOF
    lseek(fd, 0, SEEK_END);
    write(fd, &header, sizeof(header));
    write(fd, comp_buf, actual_comp);
    write(fd, &footer, sizeof(footer));

    close(fd);
    free(comp_buf);
    return 0;
}

int ttzip_vlmeta_read_layer(
    const char* archive_path,
    const char* layer_name,
    uint8_t** out_payload,
    size_t* out_size
) {
    if (!archive_path || !layer_name || !out_payload || !out_size) return -1;
    *out_payload = NULL;
    *out_size = 0;

    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) return -2;

    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < (off_t)(sizeof(ttzip_vlmeta_header_t) + sizeof(ttzip_vlmeta_footer_t))) {
        close(fd);
        return -3;
    }

    // 1. Read Footer from EOF-16
    ttzip_vlmeta_footer_t footer;
    if (pread(fd, &footer, sizeof(footer), st.st_size - sizeof(footer)) != sizeof(footer)) {
        close(fd);
        return -4;
    }

    if (memcmp(footer.magic, TTZIP_VLMETA_MAGIC, 8) != 0 || (off_t)footer.trailer_offset >= st.st_size) {
        close(fd);
        return -5; // No valid VLMeta trailer
    }

    // 2. Read Header
    ttzip_vlmeta_header_t header;
    if (pread(fd, &header, sizeof(header), (off_t)footer.trailer_offset) != sizeof(header)) {
        close(fd);
        return -6;
    }

    if (memcmp(header.magic, TTZIP_VLMETA_MAGIC, 8) != 0 || header.compressed_size == 0) {
        close(fd);
        return -7;
    }

    // 3. Read & Decompress Payload
    uint8_t* comp_buf = (uint8_t*)malloc(header.compressed_size);
    if (!comp_buf) {
        close(fd);
        return -8;
    }

    off_t payload_offset = (off_t)(footer.trailer_offset + sizeof(header));
    if (pread(fd, comp_buf, header.compressed_size, payload_offset) != (ssize_t)header.compressed_size) {
        free(comp_buf);
        close(fd);
        return -9;
    }
    close(fd);

    uint8_t* unc_buf = (uint8_t*)malloc(header.uncompressed_size);
    if (!unc_buf) {
        free(comp_buf);
        return -8;
    }

    size_t actual_decomp = ZSTD_decompress(unc_buf, header.uncompressed_size, comp_buf, header.compressed_size);
    free(comp_buf);
    if (ZSTD_isError(actual_decomp) || actual_decomp != header.uncompressed_size) {
        free(unc_buf);
        return -10;
    }

    // 4. Scan Wire Entries for Matching Layer
    size_t off = 0;
    for (uint32_t i = 0; i < header.layer_count && off < header.uncompressed_size; i++) {
        if (off + sizeof(ttzip_vlmeta_wire_entry_t) > header.uncompressed_size) break;
        ttzip_vlmeta_wire_entry_t* wire = (ttzip_vlmeta_wire_entry_t*)(unc_buf + off);
        off += sizeof(ttzip_vlmeta_wire_entry_t);

        if (strncmp(wire->name, layer_name, sizeof(wire->name)) == 0) {
            uint8_t* res = (uint8_t*)malloc(wire->payload_size);
            if (res) {
                memcpy(res, unc_buf + off, wire->payload_size);
                *out_payload = res;
                *out_size = wire->payload_size;
                free(unc_buf);
                return 0;
            }
        }
        off += wire->payload_size;
    }

    free(unc_buf);
    return -11; // Layer not found
}

void ttzip_vlmeta_free_payload(uint8_t* payload) {
    if (payload) free(payload);
}
