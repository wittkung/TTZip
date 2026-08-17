// CTTZipBridge_7zNativeDecoder.c
// TTZip 原生进程内 7Z 多核并行解压引擎管道调度器

#include "include/CTTZipBridge_7zNativeDecoder.h"
#include "include/ttzip_7z_header_parser.h"
#include "include/ttzip_7z_block_decoder.h"
#include "include/ttzip_7z_crypto_neon.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipDiagnostics.h"
#include "include/CTTZipSliceProfiler.h"
#include "include/CTTZipIO.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <libdeflate.h>

int ttzip_7z_extract_native_parallel_c(
    const char* archive_path,
    const char* destination_dir,
    const char* password
) {
    if (!archive_path || !destination_dir) return TTZIP_ERR_INVALID_PARAM;
    ttzip_diag_enter("C:7zNativeDecoder", "extract", archive_path, 0);

    int fd = open(archive_path, O_RDONLY);
    if (fd < 0) {
        ttzip_diag_set_error(TTZIP_ERR_OPEN_FAILED, "failed to open archive");
        ttzip_diag_leave();
        return TTZIP_ERR_OPEN_FAILED;
    }

    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 32) {
        close(fd);
        ttzip_diag_set_error(TTZIP_ERR_INVALID_PARAM, "invalid 7z file size");
        ttzip_diag_leave();
        return TTZIP_ERR_INVALID_PARAM;
    }

    size_t file_size = (size_t)st.st_size;
    void* mapped = mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (mapped == MAP_FAILED) {
        ttzip_diag_set_error(TTZIP_ERR_MMAP_FAILED, "mmap failed");
        ttzip_diag_leave();
        return TTZIP_ERR_MMAP_FAILED;
    }

    // 1. 零拷贝解析 7z 头部与元数据
    TTZIP_SLICE_SCOPE_BEGIN("1_7zDec_HeaderParse");
    ttzip_7z_header_info_t info;
    int parse_res = ttzip_7z_parse_header_metadata((const uint8_t*)mapped, file_size, &info);
    ttzip_log(0, "[7zDecoder] parse_res=%d, file_size=%zu, is_enc=%d", parse_res, file_size, (int)info.is_encrypted);
    if (parse_res != TTZIP_OK || info.num_files == 0) {
        ttzip_7z_free_header_info(&info);
        munmap(mapped, file_size);
        ttzip_diag_set_error(parse_res != TTZIP_OK ? parse_res : TTZIP_ERR_CORRUPT_HEADER, "header parse failed or no files");
        ttzip_diag_leave();
        TTZIP_SLICE_SCOPE_END("1_7zDec_HeaderParse");
        return parse_res != TTZIP_OK ? parse_res : TTZIP_ERR_CORRUPT_HEADER;
    }
    TTZIP_SLICE_SCOPE_END("1_7zDec_HeaderParse");

    ttzip_common_mkdir_p(destination_dir);

    const uint8_t* payload_start = (const uint8_t*)mapped + info.payload_offset;
    size_t payload_len = info.payload_len;
    uint8_t* decrypted_payload = NULL;

    // 2. 若加密，执行 ARM64 NEON 硬件 AES-256-CBC 向量化解密
    if (info.is_encrypted && payload_len > 0) {
        if (!password || password[0] == '\0') {
            ttzip_7z_free_header_info(&info);
            munmap(mapped, file_size);
            ttzip_diag_set_error(TTZIP_ERR_INVALID_PASSWORD, "password required for encrypted 7z");
            ttzip_diag_leave();
            return TTZIP_ERR_INVALID_PASSWORD;
        }

        uint8_t key[32] = {0};
        int kdf_res = ttzip_7z_kdf_sha256_neon(password, info.aes_salt, info.aes_salt_len, info.aes_num_cycles_power, key);
        if (kdf_res != 0) {
            ttzip_7z_free_header_info(&info);
            munmap(mapped, file_size);
            ttzip_diag_set_error(TTZIP_ERR_INVALID_PASSWORD, "7z KDF derivation failed");
            ttzip_diag_leave();
            return TTZIP_ERR_INVALID_PASSWORD;
        }

        posix_memalign((void**)&decrypted_payload, 64, payload_len + 16);
        if (!decrypted_payload) {
            ttzip_7z_free_header_info(&info);
            munmap(mapped, file_size);
            ttzip_diag_set_error(TTZIP_ERR_OUT_OF_MEMORY, "failed to allocate decrypt buffer");
            ttzip_diag_leave();
            return TTZIP_ERR_OUT_OF_MEMORY;
        }

        int dec_res = ttzip_7z_aes256_cbc_decrypt_neon(key, info.aes_iv, payload_start, payload_len, decrypted_payload);
        if (dec_res != 0) {
            free(decrypted_payload);
            ttzip_7z_free_header_info(&info);
            munmap(mapped, file_size);
            ttzip_diag_set_error(TTZIP_ERR_INVALID_PASSWORD, "7z AES decryption failed");
            ttzip_diag_leave();
            return TTZIP_ERR_INVALID_PASSWORD;
        }
        payload_start = decrypted_payload;
    }

    // 3. 执行多核并行多块解码
    uint8_t* unpack_buf = NULL;
    size_t total_unpack_bytes = 0;
    if (payload_len > 0) {
        int dec_status = ttzip_7z_decode_payload_parallel(
            payload_start,
            payload_len,
            info.primary_method_id,
            info.coder_props,
            info.coder_props_len,
            info.stream_sizes,
            info.num_stream_sizes,
            info.coder_unpack_sizes,
            info.num_coder_unpack_sizes,
            &unpack_buf,
            &total_unpack_bytes
        );
        ttzip_log(0, "[7zDecoder] dec_status=%d, unpack_buf=%p, total_unpack_bytes=%zu", dec_status, unpack_buf, total_unpack_bytes);

        if (dec_status != TTZIP_OK || !unpack_buf) {
            if (decrypted_payload) free(decrypted_payload);
            ttzip_7z_free_header_info(&info);
            munmap(mapped, file_size);
            ttzip_diag_set_error(dec_status != TTZIP_OK ? dec_status : TTZIP_ERR_CORRUPT_HEADER, "decode failed");
            ttzip_diag_leave();
            return dec_status != TTZIP_OK ? dec_status : TTZIP_ERR_CORRUPT_HEADER;
        }
    }

    if (decrypted_payload) {
        free(decrypted_payload);
    }

    // 4. 目录树恢复与文件写盘聚合
    TTZIP_SLICE_SCOPE_BEGIN("3_7zDec_DiskWrite");
    bool crc_mismatch = false;
    if (info.num_files > 0) {
        size_t wr_offset = 0;
        size_t size_idx = 0;
        size_t crc_idx = 0;
        uint64_t sum_sizes = 0;

        char last_parent_dir[1024] = {0};
        struct {
            uint32_t hash;
            char path[512];
        } mkdir_cache[64];
        memset(mkdir_cache, 0, sizeof(mkdir_cache));

        for (size_t f = 0; f < info.num_files; f++) {
            if (info.files[f].rel_path[0] == '\0') continue;

            char full_out[4096];
            if (ttzip_common_join_path(full_out, sizeof(full_out), destination_dir, info.files[f].rel_path) != TTZIP_OK) {
                continue;
            }

            if (info.files[f].is_dir) {
                ttzip_common_mkdir_p(full_out);
                continue;
            }

            char parent_dir[1024];
            snprintf(parent_dir, sizeof(parent_dir), "%s", full_out);
            char* last_slash = strrchr(parent_dir, '/');
            if (last_slash) {
                *last_slash = '\0';
                if (last_parent_dir[0] != '\0' && strcmp(parent_dir, last_parent_dir) == 0) {
                    // L1 Hit: Skip mkdir_p
                } else {
                    uint32_t h = 2166136261u;
                    for (const char* p = parent_dir; *p; p++) {
                        h = (h ^ (uint8_t)*p) * 16777619u;
                    }
                    size_t slot = (size_t)(h & 63);
                    if (mkdir_cache[slot].hash == h && strcmp(mkdir_cache[slot].path, parent_dir) == 0) {
                        // L2 Hit: Skip mkdir_p
                    } else {
                        ttzip_common_mkdir_p(parent_dir);
                        mkdir_cache[slot].hash = h;
                        snprintf(mkdir_cache[slot].path, sizeof(mkdir_cache[slot].path), "%s", parent_dir);
                    }
                    snprintf(last_parent_dir, sizeof(last_parent_dir), "%s", parent_dir);
                }
            }

            size_t fsize = 0;
            if (!info.files[f].is_empty_stream) {
                if (size_idx < info.num_stream_sizes) {
                    fsize = (size_t)info.stream_sizes[size_idx++];
                    sum_sizes += fsize;
                } else {
                    fsize = total_unpack_bytes > sum_sizes ? (size_t)(total_unpack_bytes - sum_sizes) : 0;
                }

                if (crc_idx < info.num_stream_crcs && fsize > 0 && wr_offset + fsize <= total_unpack_bytes && unpack_buf) {
                    uint32_t expected_crc = info.stream_crcs[crc_idx++];
                    if (expected_crc != 0) {
                        uint32_t computed_crc = ttzip_compute_buffer_crc32_neon(0, unpack_buf + wr_offset, fsize);
                        if (computed_crc != expected_crc) {
                            crc_mismatch = true;
                        }
                    }
                }
            }

            if (!crc_mismatch) {
                int out_fd = open(full_out, O_RDWR | O_CREAT | O_TRUNC | O_NOFOLLOW, 0644);
                if (out_fd >= 0) {
                    if (fsize > 0 && wr_offset + fsize <= total_unpack_bytes && unpack_buf) {
                        ttzip_io_write_all(out_fd, unpack_buf + wr_offset, fsize);
                    }
                    close(out_fd);
                }
            }
            wr_offset += fsize;
        }
    }
    TTZIP_SLICE_SCOPE_END("3_7zDec_DiskWrite");

    if (crc_mismatch) {
        if (unpack_buf) free(unpack_buf);
        ttzip_7z_free_header_info(&info);
        munmap(mapped, file_size);
        ttzip_diag_set_error(TTZIP_ERR_INVALID_PASSWORD, "CRC mismatch (wrong password)");
        ttzip_diag_leave();
        return TTZIP_ERR_INVALID_PASSWORD;
    }

    if (unpack_buf) {
        free(unpack_buf);
    }
    ttzip_7z_free_header_info(&info);
    munmap(mapped, file_size);
    ttzip_diag_leave();
    return TTZIP_OK;
}
