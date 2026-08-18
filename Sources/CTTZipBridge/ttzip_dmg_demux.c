// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_dmg_demux.h"
#include "include/CTTZipBridge_LZFSE.h"
#include "include/CTTZipBridge_APFS.h"
#include "include/CTTZipCommon.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <zlib.h>

#if defined(__APPLE__)
#include <libkern/OSByteOrder.h>
#define ttzip_be32(x) OSSwapBigToHostInt32(x)
#define ttzip_be64(x) OSSwapBigToHostInt64(x)
#else
#define ttzip_be32(x) __builtin_bswap32(x)
#define ttzip_be64(x) __builtin_bswap64(x)
#endif

// MARK: - Base64 Decoding Helper

static const int8_t s_b64_table[256] = {
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,
    52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-1,-1,-1,
    -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,
    15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,
    -1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
    41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
};

static uint8_t* ttzip_base64_decode(const char* src, size_t src_len, size_t* out_len) {
    if (!src || src_len == 0) return NULL;
    size_t alloc_size = (src_len * 3) / 4 + 64;
    uint8_t* out = (uint8_t*)malloc(alloc_size);
    if (!out) return NULL;

    size_t out_idx = 0;
    uint32_t val = 0;
    int valb = -8;
    for (size_t i = 0; i < src_len; i++) {
        uint8_t c = (uint8_t)src[i];
        int8_t v = s_b64_table[c];
        if (v == -1) continue; // skip whitespace and formatting
        val = (val << 6) | (uint8_t)v;
        valb += 6;
        if (valb >= 0) {
            out[out_idx++] = (uint8_t)((val >> valb) & 0xFF);
            valb -= 8;
        }
    }
    if (out_len) *out_len = out_idx;
    return out;
}

// MARK: - UDIF DMG Probing & Header Parsing

bool ttzip_dmg_probe(const char* file_path) {
    ttzip_udif_koly_t koly;
    return (ttzip_dmg_read_koly(file_path, &koly) == TTZIP_OK);
}

int ttzip_dmg_read_koly(const char* file_path, ttzip_udif_koly_t* out_koly) {
    if (!file_path || !out_koly) return TTZIP_ERR_INVALID_PARAM;

    int fd = open(file_path, O_RDONLY);
    if (fd < 0) return TTZIP_ERR_FILE_NOT_FOUND;

    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 512) {
        close(fd);
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    if (lseek(fd, st.st_size - 512, SEEK_SET) < 0) {
        close(fd);
        return TTZIP_ERR_INVALID_OFFSET;
    }

    ssize_t n = read(fd, out_koly, 512);
    close(fd);
    if (n != 512) return TTZIP_ERR_CORRUPT_HEADER;

    uint32_t sig = ttzip_be32(out_koly->signature);
    if (sig != TTZIP_DMG_KOLY_MAGIC) {
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    // Convert fields in-place
    out_koly->signature             = sig;
    out_koly->version               = ttzip_be32(out_koly->version);
    out_koly->header_size           = ttzip_be32(out_koly->header_size);
    out_koly->flags                 = ttzip_be32(out_koly->flags);
    out_koly->running_data_fork_off = ttzip_be64(out_koly->running_data_fork_off);
    out_koly->data_fork_offset      = ttzip_be64(out_koly->data_fork_offset);
    out_koly->data_fork_length      = ttzip_be64(out_koly->data_fork_length);
    out_koly->rsrc_fork_offset      = ttzip_be64(out_koly->rsrc_fork_offset);
    out_koly->rsrc_fork_length      = ttzip_be64(out_koly->rsrc_fork_length);
    out_koly->segment_number        = ttzip_be32(out_koly->segment_number);
    out_koly->segment_count         = ttzip_be32(out_koly->segment_count);
    out_koly->xml_offset            = ttzip_be64(out_koly->xml_offset);
    out_koly->xml_length            = ttzip_be64(out_koly->xml_length);
    out_koly->sector_count          = ttzip_be64(out_koly->sector_count);

    return TTZIP_OK;
}

// MARK: - Chunk Decompressor & Disk Image Builder

static int decompress_single_chunk(
    int fd_in,
    int fd_out,
    const ttzip_udif_chunk_entry_t* chunk,
    uint8_t* comp_buf,
    size_t comp_buf_cap,
    uint8_t* decomp_buf,
    size_t decomp_buf_cap
) {
    uint32_t type = chunk->entry_type;
    uint64_t sector_num = chunk->sector_number;
    uint64_t sector_count = chunk->sector_count;
    uint64_t comp_off = chunk->compressed_offset;
    uint64_t comp_len = chunk->compressed_length;

    if (sector_count == 0 || type == TTZIP_UDIF_CHUNK_COMMENT || type == TTZIP_UDIF_CHUNK_TERMINATOR) {
        return TTZIP_OK;
    }

    off_t target_out_off = (off_t)(sector_num * 512);
    size_t target_decomp_size = (size_t)(sector_count * 512);

    if (type == TTZIP_UDIF_CHUNK_ZERO || type == TTZIP_UDIF_CHUNK_IGNORE) {
        // Zero or ignored sectors
        if (target_decomp_size <= decomp_buf_cap) {
            memset(decomp_buf, 0, target_decomp_size);
            pwrite(fd_out, decomp_buf, target_decomp_size, target_out_off);
        }
        return TTZIP_OK;
    }

    if (type == TTZIP_UDIF_CHUNK_RAW) {
        // Raw sectors
        if (comp_len > comp_buf_cap) return TTZIP_ERR_OUT_OF_MEMORY;
        ssize_t n = pread(fd_in, comp_buf, (size_t)comp_len, (off_t)comp_off);
        if (n != (ssize_t)comp_len) return TTZIP_ERR_CORRUPT_HEADER;
        pwrite(fd_out, comp_buf, (size_t)comp_len, target_out_off);
        return TTZIP_OK;
    }

    if (type == TTZIP_UDIF_CHUNK_LZFSE || type == TTZIP_UDIF_CHUNK_BZIP2 /* LZFSE in ULFO */) {
        // LZFSE compressed block
        if (comp_len > comp_buf_cap || target_decomp_size > decomp_buf_cap) {
            return TTZIP_ERR_OUT_OF_MEMORY;
        }
        ssize_t n = pread(fd_in, comp_buf, (size_t)comp_len, (off_t)comp_off);
        if (n != (ssize_t)comp_len) return TTZIP_ERR_CORRUPT_HEADER;

        size_t written = ttzip_lzfse_decompress_block(comp_buf, (size_t)comp_len, decomp_buf, target_decomp_size);
        if (written == 0 && target_decomp_size > 0) {
            // Fallback try raw or return error
            return TTZIP_ERR_CORRUPT_HEADER;
        }
        pwrite(fd_out, decomp_buf, written, target_out_off);
        return TTZIP_OK;
    }

    if (type == TTZIP_UDIF_CHUNK_ZLIB || type == TTZIP_UDIF_CHUNK_ADC) {
        // ZLIB compressed block
        if (comp_len > comp_buf_cap || target_decomp_size > decomp_buf_cap) {
            return TTZIP_ERR_OUT_OF_MEMORY;
        }
        ssize_t n = pread(fd_in, comp_buf, (size_t)comp_len, (off_t)comp_off);
        if (n != (ssize_t)comp_len) return TTZIP_ERR_CORRUPT_HEADER;

        z_stream zs;
        memset(&zs, 0, sizeof(zs));
        zs.next_in = comp_buf;
        zs.avail_in = (uInt)comp_len;
        zs.next_out = decomp_buf;
        zs.avail_out = (uInt)target_decomp_size;

        if (inflateInit(&zs) != Z_OK) return TTZIP_ERR_ARCHIVE_INIT_FAILED;
        int ret = inflate(&zs, Z_FINISH);
        inflateEnd(&zs);

        if (ret != Z_STREAM_END && ret != Z_OK) {
            return TTZIP_ERR_CORRUPT_HEADER;
        }
        pwrite(fd_out, decomp_buf, (size_t)zs.total_out, target_out_off);
        return TTZIP_OK;
    }

    return TTZIP_OK;
}

int ttzip_dmg_decompress_to_raw(const char* dmg_path, const char* raw_out_path) {
    if (!dmg_path || !raw_out_path) return TTZIP_ERR_INVALID_PARAM;

    ttzip_udif_koly_t koly;
    int status = ttzip_dmg_read_koly(dmg_path, &koly);
    if (status != TTZIP_OK) return status;

    int fd_in = open(dmg_path, O_RDONLY);
    if (fd_in < 0) return TTZIP_ERR_FILE_NOT_FOUND;

    if (koly.xml_length == 0 || koly.xml_length > 16 * 1024 * 1024) {
        close(fd_in);
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    char* xml_buf = (char*)malloc((size_t)koly.xml_length + 1);
    if (!xml_buf) {
        close(fd_in);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    ssize_t n_xml = pread(fd_in, xml_buf, (size_t)koly.xml_length, (off_t)koly.xml_offset);
    if (n_xml != (ssize_t)koly.xml_length) {
        free(xml_buf);
        close(fd_in);
        return TTZIP_ERR_CORRUPT_HEADER;
    }
    xml_buf[koly.xml_length] = '\0';

    int fd_out = open(raw_out_path, O_CREAT | O_RDWR | O_TRUNC, 0644);
    if (fd_out < 0) {
        free(xml_buf);
        close(fd_in);
        return TTZIP_ERR_OPEN_FAILED;
    }

    if (koly.sector_count > 0) {
        ttzip_apfs_preallocate(fd_out, (int64_t)(koly.sector_count * 512));
    }

    // Allocate 4MB page-aligned working buffers for chunk decoding
    size_t comp_buf_cap = 4 * 1024 * 1024;
    size_t decomp_buf_cap = 4 * 1024 * 1024;
    uint8_t* comp_buf = (uint8_t*)malloc(comp_buf_cap);
    uint8_t* decomp_buf = (uint8_t*)malloc(decomp_buf_cap);

    if (!comp_buf || !decomp_buf) {
        free(comp_buf);
        free(decomp_buf);
        free(xml_buf);
        close(fd_out);
        close(fd_in);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    // Scan XML for all <data> blocks inside <key>blkx</key>
    const char* cursor = xml_buf;
    int chunks_processed = 0;

    while ((cursor = strstr(cursor, "<data>")) != NULL) {
        cursor += 6; // skip "<data>"
        const char* end_tag = strstr(cursor, "</data>");
        if (!end_tag) break;

        size_t b64_len = (size_t)(end_tag - cursor);
        size_t raw_mish_len = 0;
        uint8_t* mish_data = ttzip_base64_decode(cursor, b64_len, &raw_mish_len);
        cursor = end_tag + 7;

        if (!mish_data || raw_mish_len < sizeof(ttzip_udif_mish_t)) {
            free(mish_data);
            continue;
        }

        const ttzip_udif_mish_t* mish = (const ttzip_udif_mish_t*)mish_data;
        uint32_t mish_sig = ttzip_be32(mish->signature);
        if (mish_sig != TTZIP_DMG_MISH_MAGIC) {
            free(mish_data);
            continue;
        }

        uint32_t num_chunks = ttzip_be32(mish->number_of_chunks);
        size_t expected_size = sizeof(ttzip_udif_mish_t) + (size_t)num_chunks * sizeof(ttzip_udif_chunk_entry_t);
        if (raw_mish_len < expected_size) {
            num_chunks = (uint32_t)((raw_mish_len - sizeof(ttzip_udif_mish_t)) / sizeof(ttzip_udif_chunk_entry_t));
        }

        const ttzip_udif_chunk_entry_t* raw_chunks = (const ttzip_udif_chunk_entry_t*)(mish_data + sizeof(ttzip_udif_mish_t));

        for (uint32_t c = 0; c < num_chunks; c++) {
            ttzip_udif_chunk_entry_t entry;
            entry.entry_type        = ttzip_be32(raw_chunks[c].entry_type);
            entry.comment           = ttzip_be32(raw_chunks[c].comment);
            entry.sector_number     = ttzip_be64(raw_chunks[c].sector_number);
            entry.sector_count      = ttzip_be64(raw_chunks[c].sector_count);
            entry.compressed_offset = ttzip_be64(raw_chunks[c].compressed_offset);
            entry.compressed_length = ttzip_be64(raw_chunks[c].compressed_length);

            if (entry.entry_type == TTZIP_UDIF_CHUNK_TERMINATOR) {
                break;
            }

            decompress_single_chunk(
                fd_in,
                fd_out,
                &entry,
                comp_buf,
                comp_buf_cap,
                decomp_buf,
                decomp_buf_cap
            );
            chunks_processed++;
        }

        free(mish_data);
    }

    free(comp_buf);
    free(decomp_buf);
    free(xml_buf);
    close(fd_out);
    close(fd_in);

    return (chunks_processed > 0) ? TTZIP_OK : TTZIP_ERR_CORRUPT_HEADER;
}
