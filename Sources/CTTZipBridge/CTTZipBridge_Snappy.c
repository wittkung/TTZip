// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_Snappy.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipBridge_APFS.h"
#include "snappy-c.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <dispatch/dispatch.h>
#include <sys/mman.h>
#include <dirent.h>
#include <archive.h>
#include <archive_entry.h>

#if defined(__aarch64__) || defined(__arm64__)
#if defined(__has_include)
#if __has_include(<arm_acle.h>)
#include <arm_acle.h>
#define TTZIP_HAVE_ARM_ACLE 1
#endif
#endif
#endif

// MARK: - Castagnoli CRC32C Engine with ARM64 ACLE & Slice-by-8 Fallback

static uint32_t s_crc32c_table[8][256];
static dispatch_once_t s_crc32c_once;

static void init_crc32c_slice8_table_impl(void) {
    const uint32_t poly = 0x82F63B78U; // Castagnoli reflected polynomial
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = i;
        for (int j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ ((crc & 1) ? poly : 0);
        }
        s_crc32c_table[0][i] = crc;
    }
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t crc = s_crc32c_table[0][i];
        for (int j = 1; j < 8; j++) {
            crc = s_crc32c_table[0][crc & 0xFF] ^ (crc >> 8);
            s_crc32c_table[j][i] = crc;
        }
    }
}

static void init_crc32c_slice8_table(void) {
    dispatch_once(&s_crc32c_once, ^{
        init_crc32c_slice8_table_impl();
    });
}

static bool has_arm64_crc32_hardware(void) {
#if defined(TTZIP_HAVE_ARM_ACLE)
    int val = 0;
    size_t size = sizeof(val);
    if (sysctlbyname("hw.optional.arm.FEAT_CRC32", &val, &size, NULL, 0) == 0 && val != 0) {
        return true;
    }
    if (sysctlbyname("hw.optional.armv8_crc32", &val, &size, NULL, 0) == 0 && val != 0) {
        return true;
    }
    // Apple Silicon M-series (macOS ARM64) always supports ARMv8 CRC32
#if defined(__APPLE__) && (defined(__arm64__) || defined(__aarch64__))
    return true;
#endif
#endif
    return false;
}

uint32_t ttzip_snappy_crc32c(uint32_t crc, const void* data, size_t len) {
    if (!data || len == 0) return crc;
    const uint8_t* p = (const uint8_t*)data;
    uint32_t c = ~crc;

#if defined(TTZIP_HAVE_ARM_ACLE)
    if (has_arm64_crc32_hardware()) {
        while (((uintptr_t)p & 7) && len > 0) {
            c = __builtin_arm_crc32cb(c, *p++);
            len--;
        }
        while (len >= 32) {
            uint64_t v0, v1, v2, v3;
            memcpy(&v0, p, 8);
            memcpy(&v1, p + 8, 8);
            memcpy(&v2, p + 16, 8);
            memcpy(&v3, p + 24, 8);
            c = __builtin_arm_crc32cd(c, v0);
            c = __builtin_arm_crc32cd(c, v1);
            c = __builtin_arm_crc32cd(c, v2);
            c = __builtin_arm_crc32cd(c, v3);
            p += 32;
            len -= 32;
        }
        while (len >= 8) {
            uint64_t v;
            memcpy(&v, p, 8);
            c = __builtin_arm_crc32cd(c, v);
            p += 8;
            len -= 8;
        }
        if (len >= 4) {
            uint32_t v;
            memcpy(&v, p, 4);
            c = __builtin_arm_crc32cw(c, v);
            p += 4;
            len -= 4;
        }
        if (len >= 2) {
            uint16_t v;
            memcpy(&v, p, 2);
            c = __builtin_arm_crc32ch(c, v);
            p += 2;
            len -= 2;
        }
        if (len == 1) {
            c = __builtin_arm_crc32cb(c, *p);
        }
        return ~c;
    }
#endif

    // Fallback: Slice-by-8
    init_crc32c_slice8_table();
    while (((uintptr_t)p & 7) && len > 0) {
        c = s_crc32c_table[0][(c ^ *p++) & 0xFF] ^ (c >> 8);
        len--;
    }
    while (len >= 8) {
        uint32_t low, high;
        memcpy(&low, p, 4);
        memcpy(&high, p + 4, 4);
        low ^= c;
        c = s_crc32c_table[7][low & 0xFF] ^
            s_crc32c_table[6][(low >> 8) & 0xFF] ^
            s_crc32c_table[5][(low >> 16) & 0xFF] ^
            s_crc32c_table[4][(low >> 24) & 0xFF] ^
            s_crc32c_table[3][high & 0xFF] ^
            s_crc32c_table[2][(high >> 8) & 0xFF] ^
            s_crc32c_table[1][(high >> 16) & 0xFF] ^
            s_crc32c_table[0][(high >> 24) & 0xFF];
        p += 8;
        len -= 8;
    }
    while (len > 0) {
        c = s_crc32c_table[0][(c ^ *p++) & 0xFF] ^ (c >> 8);
        len--;
    }
    return ~c;
}

// MARK: - Raw Block Snappy APIs

bool ttzip_snappy_is_available(void) {
    return true;
}

size_t ttzip_snappy_max_compressed_length(size_t source_length) {
    return snappy_max_compressed_length(source_length);
}

int ttzip_snappy_uncompressed_length(const void* compressed, size_t compressed_len, size_t* result_len) {
    if (!compressed || compressed_len == 0 || !result_len) return TTZIP_SNAPPY_ERR_INVALID_PARAM;
    snappy_status st = snappy_uncompressed_length((const char*)compressed, compressed_len, result_len);
    return (st == SNAPPY_OK) ? TTZIP_SNAPPY_OK : TTZIP_SNAPPY_ERR_CORRUPT_VARINT;
}

int ttzip_snappy_compress(const void* input, size_t input_len, void* output, size_t* output_len) {
    if (!output || !output_len) return TTZIP_SNAPPY_ERR_INVALID_PARAM;
    if (input_len == 0) {
        *output_len = 0;
        return TTZIP_SNAPPY_OK;
    }
    if (!input) return TTZIP_SNAPPY_ERR_INVALID_PARAM;

    snappy_status st = snappy_compress((const char*)input, input_len, (char*)output, output_len);
    if (st == SNAPPY_OK) return TTZIP_SNAPPY_OK;
    if (st == SNAPPY_BUFFER_TOO_SMALL) return TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL;
    return TTZIP_SNAPPY_ERR_CORRUPT_TAG;
}

int ttzip_snappy_decompress(const void* compressed, size_t compressed_len, void* output, size_t* output_len) {
    if (!compressed || compressed_len == 0 || !output || !output_len) return TTZIP_SNAPPY_ERR_INVALID_PARAM;

    snappy_status st = snappy_uncompress((const char*)compressed, compressed_len, (char*)output, output_len);
    if (st == SNAPPY_OK) return TTZIP_SNAPPY_OK;
    if (st == SNAPPY_BUFFER_TOO_SMALL) return TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL;
    return TTZIP_SNAPPY_ERR_CORRUPT_TAG;
}

int ttzip_snappy_validate(const void* compressed, size_t compressed_len) {
    if (!compressed || compressed_len == 0) return TTZIP_SNAPPY_ERR_INVALID_PARAM;
    snappy_status st = snappy_validate_compressed_buffer((const char*)compressed, compressed_len);
    return (st == SNAPPY_OK) ? TTZIP_SNAPPY_OK : TTZIP_SNAPPY_ERR_CORRUPT_TAG;
}

// MARK: - Snappy Framing Stream Encoders & Decoders

int ttzip_snappy_framed_compress(const void* input, size_t input_len, void* output, size_t* output_len) {
    if (!output || !output_len) return TTZIP_SNAPPY_ERR_INVALID_PARAM;

    // Stream Header: 10 bytes \xFF\x06\x00\x00sNaPpY
    const size_t max_out = *output_len;
    size_t out_pos = 0;
    if (max_out < TTZIP_SNAPPY_STREAM_ID_LEN) return TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL;

    memcpy((uint8_t*)output + out_pos, TTZIP_SNAPPY_STREAM_ID, TTZIP_SNAPPY_STREAM_ID_LEN);
    out_pos += TTZIP_SNAPPY_STREAM_ID_LEN;

    if (input_len == 0) {
        *output_len = out_pos;
        return TTZIP_SNAPPY_OK;
    }
    if (!input) return TTZIP_SNAPPY_ERR_INVALID_PARAM;

    const uint8_t* in_ptr = (const uint8_t*)input;
    size_t remaining = input_len;
    uint8_t comp_scratch[TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE + 512];

    while (remaining > 0) {
        size_t chunk_raw_len = (remaining > TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE) ? TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE : remaining;
        uint32_t raw_crc = ttzip_snappy_crc32c(0, in_ptr, chunk_raw_len);
        uint32_t masked_crc = ttzip_snappy_mask_crc32c(raw_crc);

        size_t comp_len = sizeof(comp_scratch);
        int comp_res = ttzip_snappy_compress(in_ptr, chunk_raw_len, comp_scratch, &comp_len);

        // Check if compression resulted in actual reduction
        if (comp_res == TTZIP_SNAPPY_OK && comp_len + 4 < chunk_raw_len) {
            // Emit Compressed Chunk (0x00)
            size_t payload_len = comp_len + 4;
            if (out_pos + 4 + payload_len > max_out) return TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL;

            uint8_t* out_p = (uint8_t*)output + out_pos;
            out_p[0] = 0x00; // Compressed Chunk Type
            out_p[1] = (uint8_t)(payload_len & 0xFF);
            out_p[2] = (uint8_t)((payload_len >> 8) & 0xFF);
            out_p[3] = (uint8_t)((payload_len >> 16) & 0xFF);
            memcpy(out_p + 4, &masked_crc, 4);
            memcpy(out_p + 8, comp_scratch, comp_len);
            out_pos += 4 + payload_len;
        } else {
            // Emit Uncompressed Chunk (0x01)
            size_t payload_len = chunk_raw_len + 4;
            if (out_pos + 4 + payload_len > max_out) return TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL;

            uint8_t* out_p = (uint8_t*)output + out_pos;
            out_p[0] = 0x01; // Uncompressed Chunk Type
            out_p[1] = (uint8_t)(payload_len & 0xFF);
            out_p[2] = (uint8_t)((payload_len >> 8) & 0xFF);
            out_p[3] = (uint8_t)((payload_len >> 16) & 0xFF);
            memcpy(out_p + 4, &masked_crc, 4);
            memcpy(out_p + 8, in_ptr, chunk_raw_len);
            out_pos += 4 + payload_len;
        }

        in_ptr += chunk_raw_len;
        remaining -= chunk_raw_len;
    }

    *output_len = out_pos;
    return TTZIP_SNAPPY_OK;
}

int ttzip_snappy_framed_decompress(const void* input, size_t input_len, void* output, size_t* output_len) {
    if (!input || input_len == 0 || !output || !output_len) return TTZIP_SNAPPY_ERR_INVALID_PARAM;

    const uint8_t* in_p = (const uint8_t*)input;
    const uint8_t* in_limit = in_p + input_len;
    uint8_t* out_p = (uint8_t*)output;
    const uint8_t* out_limit = out_p + *output_len;
    size_t total_decompressed = 0;

    // Check Stream Identifier Chunk (10 bytes)
    if (input_len < TTZIP_SNAPPY_STREAM_ID_LEN) return TTZIP_SNAPPY_ERR_UNEXPECTED_EOF;
    if (memcmp(in_p, TTZIP_SNAPPY_STREAM_ID, TTZIP_SNAPPY_STREAM_ID_LEN) != 0) {
        return TTZIP_SNAPPY_ERR_INVALID_MAGIC;
    }
    in_p += TTZIP_SNAPPY_STREAM_ID_LEN;

    uint8_t raw_scratch[TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE + 64];

    while (in_p < in_limit) {
        if (in_limit - in_p < 4) return TTZIP_SNAPPY_ERR_UNEXPECTED_EOF;

        uint8_t chunk_type = in_p[0];
        uint32_t chunk_len = (uint32_t)in_p[1] | ((uint32_t)in_p[2] << 8) | ((uint32_t)in_p[3] << 16);
        in_p += 4;

        if (in_limit - in_p < chunk_len) return TTZIP_SNAPPY_ERR_UNEXPECTED_EOF;

        if (chunk_type == 0xFF) {
            // Stream Identifier (cascade stream support, 6 bytes "sNaPpY")
            if (chunk_len != 6 || memcmp(in_p, "sNaPpY", 6) != 0) {
                return TTZIP_SNAPPY_ERR_INVALID_MAGIC;
            }
            in_p += chunk_len;
            continue;
        } else if (chunk_type == 0xFE || (chunk_type >= 0x80 && chunk_type <= 0xFD)) {
            // Padding or Skippable Chunk
            in_p += chunk_len;
            continue;
        } else if (chunk_type >= 0x02 && chunk_type <= 0x7F) {
            // Reserved Unskippable Chunk
            return TTZIP_SNAPPY_ERR_UNSUPPORTED_CHUNK;
        } else if (chunk_type == 0x00) {
            // Compressed Data Chunk
            if (chunk_len < 4) return TTZIP_SNAPPY_ERR_CORRUPT_TAG;
            uint32_t expected_masked_crc;
            memcpy(&expected_masked_crc, in_p, 4);
            const uint8_t* comp_payload = in_p + 4;
            size_t comp_payload_len = chunk_len - 4;

            size_t uncomp_len = sizeof(raw_scratch);
            int dec_res = ttzip_snappy_decompress(comp_payload, comp_payload_len, raw_scratch, &uncomp_len);
            if (dec_res != TTZIP_SNAPPY_OK) return dec_res;
            if (uncomp_len > TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE) return TTZIP_SNAPPY_ERR_LITERAL_OVERRUN;

            // CRC32C Validation
            uint32_t actual_crc = ttzip_snappy_crc32c(0, raw_scratch, uncomp_len);
            uint32_t actual_masked_crc = ttzip_snappy_mask_crc32c(actual_crc);
            if (actual_masked_crc != expected_masked_crc) {
                return TTZIP_SNAPPY_ERR_CRC32C_MISMATCH;
            }

            if (out_limit - out_p < uncomp_len) return TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL;
            memcpy(out_p, raw_scratch, uncomp_len);
            out_p += uncomp_len;
            total_decompressed += uncomp_len;
            in_p += chunk_len;
        } else if (chunk_type == 0x01) {
            // Uncompressed Data Chunk
            if (chunk_len < 4) return TTZIP_SNAPPY_ERR_CORRUPT_TAG;
            uint32_t expected_masked_crc;
            memcpy(&expected_masked_crc, in_p, 4);
            const uint8_t* raw_payload = in_p + 4;
            size_t raw_payload_len = chunk_len - 4;

            if (raw_payload_len > TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE) return TTZIP_SNAPPY_ERR_LITERAL_OVERRUN;

            // CRC32C Validation
            uint32_t actual_crc = ttzip_snappy_crc32c(0, raw_payload, raw_payload_len);
            uint32_t actual_masked_crc = ttzip_snappy_mask_crc32c(actual_crc);
            if (actual_masked_crc != expected_masked_crc) {
                return TTZIP_SNAPPY_ERR_CRC32C_MISMATCH;
            }

            if (out_limit - out_p < raw_payload_len) return TTZIP_SNAPPY_ERR_BUFFER_TOO_SMALL;
            memcpy(out_p, raw_payload, raw_payload_len);
            out_p += raw_payload_len;
            total_decompressed += raw_payload_len;
            in_p += chunk_len;
        }
    }

    *output_len = total_decompressed;
    return TTZIP_SNAPPY_OK;
}

// MARK: - 100% In-Process TAR.SZ Native Archiving & Extraction Implementation

typedef struct {
    int fd;
    uint8_t accum_buf[TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE];
    size_t accum_len;
    uint8_t out_buf[TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE + 512];
} ttzip_snappy_tar_write_ctx_t;

static ssize_t ttzip_snappy_tar_flush_accum(ttzip_snappy_tar_write_ctx_t* ctx) {
    if (ctx->accum_len == 0) return ARCHIVE_OK;

    uint32_t raw_crc = ttzip_snappy_crc32c(0, ctx->accum_buf, ctx->accum_len);
    uint32_t masked_crc = ttzip_snappy_mask_crc32c(raw_crc);

    size_t comp_len = sizeof(ctx->out_buf) - 8;
    int comp_res = ttzip_snappy_compress(ctx->accum_buf, ctx->accum_len, ctx->out_buf + 8, &comp_len);

    if (comp_res == TTZIP_SNAPPY_OK && comp_len + 4 < ctx->accum_len) {
        size_t payload_len = comp_len + 4;
        ctx->out_buf[0] = 0x00; // Compressed
        ctx->out_buf[1] = (uint8_t)(payload_len & 0xFF);
        ctx->out_buf[2] = (uint8_t)((payload_len >> 8) & 0xFF);
        ctx->out_buf[3] = (uint8_t)((payload_len >> 16) & 0xFF);
        memcpy(ctx->out_buf + 4, &masked_crc, 4);
        ssize_t written = write(ctx->fd, ctx->out_buf, 4 + payload_len);
        ctx->accum_len = 0;
        if (written < 0) return ARCHIVE_FATAL;
    } else {
        size_t payload_len = ctx->accum_len + 4;
        ctx->out_buf[0] = 0x01; // Uncompressed
        ctx->out_buf[1] = (uint8_t)(payload_len & 0xFF);
        ctx->out_buf[2] = (uint8_t)((payload_len >> 8) & 0xFF);
        ctx->out_buf[3] = (uint8_t)((payload_len >> 16) & 0xFF);
        memcpy(ctx->out_buf + 4, &masked_crc, 4);
        memcpy(ctx->out_buf + 8, ctx->accum_buf, ctx->accum_len);
        ssize_t written = write(ctx->fd, ctx->out_buf, 4 + payload_len);
        ctx->accum_len = 0;
        if (written < 0) return ARCHIVE_FATAL;
    }
    return ARCHIVE_OK;
}

static ssize_t ttzip_snappy_archive_write_cb(struct archive* a, void* client_data, const void* buffer, size_t length) {
    (void)a;
    ttzip_snappy_tar_write_ctx_t* ctx = (ttzip_snappy_tar_write_ctx_t*)client_data;
    const uint8_t* p = (const uint8_t*)buffer;
    size_t left = length;

    while (left > 0) {
        size_t space = TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE - ctx->accum_len;
        size_t to_copy = (left < space) ? left : space;
        memcpy(ctx->accum_buf + ctx->accum_len, p, to_copy);
        ctx->accum_len += to_copy;
        p += to_copy;
        left -= to_copy;

        if (ctx->accum_len == TTZIP_SNAPPY_MAX_CHUNK_RAW_SIZE) {
            if (ttzip_snappy_tar_flush_accum(ctx) != ARCHIVE_OK) {
                return -1;
            }
        }
    }
    return (ssize_t)length;
}

static int ttzip_snappy_archive_close_cb(struct archive* a, void* client_data) {
    (void)a;
    ttzip_snappy_tar_write_ctx_t* ctx = (ttzip_snappy_tar_write_ctx_t*)client_data;
    if (ctx) {
        ttzip_snappy_tar_flush_accum(ctx);
        if (ctx->fd >= 0) {
            close(ctx->fd);
            ctx->fd = -1;
        }
        free(ctx);
    }
    return ARCHIVE_OK;
}

static void ttzip_snappy_write_file_data(struct archive* a, const char* full_path, int64_t file_size) {
    int fd = open(full_path, O_RDONLY);
    if (fd < 0) return;

    if (file_size >= 64 * 1024) {
        size_t mapped_size = ttzip_clamp_size((uint64_t)file_size);
        void* mapped = mmap(NULL, mapped_size, PROT_READ, MAP_SHARED, fd, 0);
        if (mapped != MAP_FAILED) {
            madvise(mapped, mapped_size, MADV_WILLNEED | MADV_SEQUENTIAL);
            archive_write_data(a, mapped, mapped_size);
            munmap(mapped, mapped_size);
            close(fd);
            return;
        }
    }

    char stack_buff[16384];
    ssize_t bytes_read;
    while ((bytes_read = read(fd, stack_buff, sizeof(stack_buff))) > 0) {
        archive_write_data(a, stack_buff, (size_t)bytes_read);
    }
    close(fd);
}

static int ttzip_snappy_add_file_or_dir(
    struct archive* a,
    const char* full_path,
    const char* rel_path,
    bool skip_mac_junk
) {
    if (!full_path || !rel_path || rel_path[0] == '\0') return 0;
    if (skip_mac_junk && ttzip_is_mac_junk(rel_path)) return 0;

    struct stat st;
    if (lstat(full_path, &st) != 0) return -1;

    struct archive_entry* entry = archive_entry_new();
    if (!entry) return -1;

    size_t rel_len = strlen(rel_path);
    if (S_ISDIR(st.st_mode) && rel_len > 0 && rel_path[rel_len - 1] != '/') {
        char dir_path[1024];
        snprintf(dir_path, sizeof(dir_path), "%s/", rel_path);
        archive_entry_set_pathname(entry, dir_path);
    } else {
        archive_entry_set_pathname(entry, rel_path);
    }
    archive_entry_copy_stat(entry, &st);

    if (S_ISLNK(st.st_mode)) {
        char symlink_target[1024];
        ssize_t len = readlink(full_path, symlink_target, sizeof(symlink_target) - 1);
        if (len >= 0) {
            symlink_target[len] = '\0';
            archive_entry_set_symlink(entry, symlink_target);
        }
    }

    int r = archive_write_header(a, entry);
    if (r != ARCHIVE_OK) {
        archive_entry_free(entry);
        return -1;
    }

    if (S_ISREG(st.st_mode)) {
        ttzip_snappy_write_file_data(a, full_path, (int64_t)st.st_size);
    }

    archive_entry_free(entry);

    if (S_ISDIR(st.st_mode)) {
        DIR* dir = opendir(full_path);
        if (dir) {
            struct dirent* de;
            while ((de = readdir(dir)) != NULL) {
                if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) continue;
                char sub_full[1024];
                char sub_rel[1024];
                snprintf(sub_full, sizeof(sub_full), "%s/%s", full_path, de->d_name);
                snprintf(sub_rel, sizeof(sub_rel), "%s/%s", rel_path, de->d_name);
                ttzip_snappy_add_file_or_dir(a, sub_full, sub_rel, skip_mac_junk);
            }
            closedir(dir);
        }
    }
    return 0;
}

int ttzip_create_tar_snappy_native_c(
    const char* output_archive_path,
    const char* const* input_paths,
    size_t input_count,
    bool skip_mac_junk
) {
    if (!output_archive_path || !input_paths || input_count == 0) return TTZIP_ERR_INVALID_PARAM;

    int out_fd = open(output_archive_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) return TTZIP_ERR_OPEN_FAILED;

    // Write Snappy Framing Header (10 bytes)
    if (write(out_fd, TTZIP_SNAPPY_STREAM_ID, TTZIP_SNAPPY_STREAM_ID_LEN) != TTZIP_SNAPPY_STREAM_ID_LEN) {
        close(out_fd);
        return TTZIP_ERR_OPEN_FAILED;
    }

    ttzip_snappy_tar_write_ctx_t* ctx = (ttzip_snappy_tar_write_ctx_t*)calloc(1, sizeof(ttzip_snappy_tar_write_ctx_t));
    if (!ctx) {
        close(out_fd);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    ctx->fd = out_fd;

    struct archive* a = archive_write_new();
    if (!a) {
        close(out_fd);
        free(ctx);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    archive_write_set_format_pax_restricted(a);
    archive_write_set_bytes_per_block(a, 64 * 1024);
    archive_write_set_bytes_in_last_block(a, 1);

    if (archive_write_open(a, ctx, NULL, (archive_write_callback*)ttzip_snappy_archive_write_cb, (archive_close_callback*)ttzip_snappy_archive_close_cb) != ARCHIVE_OK) {
        archive_write_free(a);
        return TTZIP_ERR_OPEN_FAILED;
    }

    for (size_t i = 0; i < input_count; i++) {
        const char* path = input_paths[i];
        if (!path) continue;

        const char* basename = strrchr(path, '/');
        const char* rel_name = basename ? (basename + 1) : path;
        ttzip_snappy_add_file_or_dir(a, path, rel_name, skip_mac_junk);
    }

    archive_write_close(a);
    archive_write_free(a);
    return TTZIP_OK;
}

// MARK: - In-Process TAR.SZ Native Extraction Implementation

int ttzip_extract_tar_snappy_native_c(
    const char* archive_path,
    const char* dest_dir,
    bool skip_mac_junk
) {
    if (!archive_path || !dest_dir) return TTZIP_ERR_INVALID_PARAM;

    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) return TTZIP_ERR_OPEN_FAILED;

    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size <= TTZIP_SNAPPY_STREAM_ID_LEN) {
        close(fd);
        return TTZIP_ERR_OPEN_FAILED;
    }

    size_t file_size = ttzip_clamp_size((uint64_t)st.st_size);
    uint8_t* file_mem = (uint8_t*)malloc(file_size);
    if (!file_mem) {
        close(fd);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    ssize_t read_bytes = read(fd, file_mem, file_size);
    close(fd);
    if (read_bytes != (ssize_t)file_size) {
        free(file_mem);
        return TTZIP_ERR_OPEN_FAILED;
    }

    // Allocate uncompressed TAR buffer (estimate 10x compression ratio capacity or incremental)
    size_t tar_capacity = file_size * 10 + (10 * 1024 * 1024);
    uint8_t* tar_mem = (uint8_t*)malloc(tar_capacity);
    if (!tar_mem) {
        free(file_mem);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    size_t tar_size = tar_capacity;
    int dec_res = ttzip_snappy_framed_decompress(file_mem, file_size, tar_mem, &tar_size);
    free(file_mem);

    if (dec_res != TTZIP_SNAPPY_OK) {
        free(tar_mem);
        return TTZIP_ERR_CORRUPT_HEADER;
    }

    // Read TAR entries from in-memory decompressed TAR stream
    ttzip_common_mkdir_p(dest_dir);

    struct archive* a = archive_read_new();
    if (!a) {
        free(tar_mem);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    archive_read_support_format_all(a);
    archive_read_support_filter_none(a);

    struct archive* ext = archive_write_disk_new();
    if (!ext) {
        archive_read_free(a);
        free(tar_mem);
        return TTZIP_ERR_OUT_OF_MEMORY;
    }

    int flags = ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_UNLINK;
    archive_write_disk_set_options(ext, flags);

    if (archive_read_open_memory(a, tar_mem, tar_size) != ARCHIVE_OK) {
        archive_write_free(ext);
        archive_read_free(a);
        free(tar_mem);
        return TTZIP_ERR_OPEN_FAILED;
    }

    struct archive_entry* entry;
    int r;
    while ((r = archive_read_next_header(a, &entry)) == ARCHIVE_OK) {
        const char* entry_pathname = archive_entry_pathname(entry);
        if (skip_mac_junk && ttzip_is_mac_junk(entry_pathname)) {
            archive_read_data_skip(a);
            continue;
        }

        char full_dest_path[1024];
        ttzip_common_join_path(full_dest_path, sizeof(full_dest_path), dest_dir, entry_pathname);
        archive_entry_set_pathname(entry, full_dest_path);

        if (archive_write_header(ext, entry) == ARCHIVE_OK) {
            const void* buff;
            size_t size;
            la_int64_t offset;
            while (archive_read_data_block(a, &buff, &size, &offset) == ARCHIVE_OK) {
                archive_write_data_block(ext, buff, size, offset);
            }
            archive_write_finish_entry(ext);
        }
    }

    archive_write_close(ext);
    archive_write_free(ext);
    archive_read_close(a);
    archive_read_free(a);
    free(tar_mem);

    return TTZIP_OK;
}
