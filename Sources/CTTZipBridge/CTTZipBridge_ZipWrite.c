// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipBridge_ZipWrite.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipBridge_Crypto.h"
#include "include/CTTZipBridge_Archive.h"
#include "include/CTTZipZipWriteInternal.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <libgen.h>
#include <dirent.h>
#include <libdeflate.h>
#include "include/ttzip_threadpool.h"
#include <errno.h>

#define write_all ttzip_io_write_all

static bool is_mac_junk_path_zip(const char* path) {
    if (!path) return false;
    if (strstr(path, "/.DS_Store") || strstr(path, "/__MACOSX/")) return true;
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    return (strcmp(base, ".DS_Store") == 0 || strncmp(base, "._", 2) == 0);
}

static void collect_c_items_recursive(const char* src_path, const char* rel_path, bool skip_mac_junk, ttzip_c_item_list_t* list) {
    if (!src_path || !rel_path) return;
    if (skip_mac_junk && is_mac_junk_path_zip(src_path)) return;
    
    struct stat st;
    if (lstat(src_path, &st) != 0) return;
    
    if (list->count >= list->capacity) {
        size_t new_cap = (list->capacity == 0) ? 512 : list->capacity * 2;
        ttzip_c_item_t* new_items = (ttzip_c_item_t*)realloc(list->items, new_cap * sizeof(ttzip_c_item_t));
        if (!new_items) return;
        memset(new_items + list->capacity, 0, (new_cap - list->capacity) * sizeof(ttzip_c_item_t));
        list->items = new_items;
        list->capacity = new_cap;
    }
    
    ttzip_c_item_t* item = &list->items[list->count++];
    memset(item, 0, sizeof(ttzip_c_item_t));
    strncpy(item->src_path, src_path, sizeof(item->src_path) - 1);
    strncpy(item->rel_path, rel_path, sizeof(item->rel_path) - 1);
    item->is_directory = S_ISDIR(st.st_mode);
    if (item->is_directory) {
        size_t rlen = strlen(item->rel_path);
        if (rlen > 0 && item->rel_path[rlen - 1] != '/' && rlen + 1 < sizeof(item->rel_path)) {
            item->rel_path[rlen] = '/';
            item->rel_path[rlen + 1] = '\0';
        }
        item->uncompressed_size = 0;
        item->compressed_size = 0;
        item->crc32 = 0;
        item->compression_method = 0;
        item->actual_method = 0;
        item->compressed_payload = NULL;
        item->is_mmapped = false;

        DIR *dir = opendir(src_path);
        if (dir) {
            int dfd = dirfd(dir);
            struct dirent *de;
            while ((de = readdir(dir)) != NULL) {
                if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) continue;
                if (skip_mac_junk && (strcmp(de->d_name, ".DS_Store") == 0 || strncmp(de->d_name, "._", 2) == 0)) continue;
                char child_src[4096];
                char child_rel[4096];
                snprintf(child_src, sizeof(child_src), "%s/%s", src_path, de->d_name);
                snprintf(child_rel, sizeof(child_rel), "%s/%s", rel_path, de->d_name);

                if (de->d_type == DT_REG) {
                    struct stat cst;
                    if (fstatat(dfd, de->d_name, &cst, AT_SYMLINK_NOFOLLOW) == 0) {
                        if (list->count >= list->capacity) {
                            size_t new_cap = list->capacity * 2;
                            ttzip_c_item_t* new_items = (ttzip_c_item_t*)realloc(list->items, new_cap * sizeof(ttzip_c_item_t));
                            if (new_items) {
                                memset(new_items + list->capacity, 0, (new_cap - list->capacity) * sizeof(ttzip_c_item_t));
                                list->items = new_items;
                                list->capacity = new_cap;
                            }
                        }
                        if (list->count < list->capacity) {
                            ttzip_c_item_t* citem = &list->items[list->count++];
                            memset(citem, 0, sizeof(ttzip_c_item_t));
                            strncpy(citem->src_path, child_src, sizeof(citem->src_path) - 1);
                            strncpy(citem->rel_path, child_rel, sizeof(citem->rel_path) - 1);
                            citem->is_directory = false;
                            citem->uncompressed_size = (int64_t)cst.st_size;
                            citem->compressed_size = 0;
                            citem->crc32 = 0;
                            citem->compression_method = 8;
                            citem->actual_method = 8;
                            citem->compressed_payload = NULL;
                            citem->is_mmapped = false;
                            continue;
                        }
                    }
                }
                collect_c_items_recursive(child_src, child_rel, skip_mac_junk, list);
            }
            closedir(dir);
        }
    } else {
        item->uncompressed_size = (int64_t)st.st_size;
        item->compressed_size = 0;
        item->crc32 = 0;
        item->compression_method = 8; // Deflate
        item->actual_method = 8;
        item->compressed_payload = NULL;
        item->is_mmapped = false;
    }
}

#include "include/CTTZipSysAlloc.h"
#include "include/CTTZipCacheTopology.h"

int ttzip_cluster_small_files_into_batches(
    const ttzip_c_item_list_t* list,
    size_t target_batch_bytes,
    size_t max_files_per_batch,
    ttzip_c_batch_list_t* out_batches
) {
    if (!list || !out_batches) return -1;
    out_batches->units = NULL;
    out_batches->count = 0;
    out_batches->capacity = 0;

    size_t curr_start = 0;
    while (curr_start < list->count) {
        ttzip_c_item_t* first_item = &list->items[curr_start];
        if (first_item->is_directory || first_item->uncompressed_size == 0) {
            if (out_batches->count >= out_batches->capacity) {
                size_t new_cap = (out_batches->capacity == 0) ? 64 : out_batches->capacity * 2;
                ttzip_c_batch_unit_t* new_units = (ttzip_c_batch_unit_t*)realloc(out_batches->units, new_cap * sizeof(ttzip_c_batch_unit_t));
                if (!new_units) return -1;
                out_batches->units = new_units;
                out_batches->capacity = new_cap;
            }
            ttzip_c_batch_unit_t* unit = &out_batches->units[out_batches->count++];
            unit->start_index = curr_start;
            unit->count = 1;
            unit->total_uncompressed_bytes = 0;
            unit->arena_offset = 0;
            unit->arena_cap = 0;
            curr_start++;
            continue;
        }

        if (first_item->uncompressed_size >= 64 * 1024) {
            if (out_batches->count >= out_batches->capacity) {
                size_t new_cap = (out_batches->capacity == 0) ? 64 : out_batches->capacity * 2;
                ttzip_c_batch_unit_t* new_units = (ttzip_c_batch_unit_t*)realloc(out_batches->units, new_cap * sizeof(ttzip_c_batch_unit_t));
                if (!new_units) return -1;
                out_batches->units = new_units;
                out_batches->capacity = new_cap;
            }
            ttzip_c_batch_unit_t* unit = &out_batches->units[out_batches->count++];
            unit->start_index = curr_start;
            unit->count = 1;
            unit->total_uncompressed_bytes = (uint64_t)first_item->uncompressed_size;
            unit->arena_offset = 0;
            unit->arena_cap = 0;
            curr_start++;
            continue;
        }

        size_t batch_count = 0;
        uint64_t batch_bytes = 0;
        size_t scan_idx = curr_start;

        while (scan_idx < list->count && batch_count < max_files_per_batch) {
            ttzip_c_item_t* item = &list->items[scan_idx];
            if (item->is_directory || item->uncompressed_size >= 64 * 1024) {
                break;
            }
            if (batch_bytes + (uint64_t)item->uncompressed_size > target_batch_bytes && batch_count > 0) {
                break;
            }
            batch_bytes += (uint64_t)item->uncompressed_size;
            batch_count++;
            scan_idx++;
        }

        if (batch_count == 0) {
            batch_count = 1;
            batch_bytes = (uint64_t)first_item->uncompressed_size;
        }

        if (out_batches->count >= out_batches->capacity) {
            size_t new_cap = (out_batches->capacity == 0) ? 64 : out_batches->capacity * 2;
            ttzip_c_batch_unit_t* new_units = (ttzip_c_batch_unit_t*)realloc(out_batches->units, new_cap * sizeof(ttzip_c_batch_unit_t));
            if (!new_units) return -1;
            out_batches->units = new_units;
            out_batches->capacity = new_cap;
        }
        ttzip_c_batch_unit_t* unit = &out_batches->units[out_batches->count++];
        unit->start_index = curr_start;
        unit->count = batch_count;
        unit->total_uncompressed_bytes = batch_bytes;
        unit->arena_offset = 0;
        unit->arena_cap = 0;

        curr_start += batch_count;
    }

    return 0;
}

typedef struct {
    ttzip_c_item_list_t* list;
    ttzip_c_batch_list_t* batch_list;
    uint8_t* payload_arena;
    int level;
    bool has_password;
    const char* password;
} zip_write_batch_arg_t;

static void zip_write_batch_worker(size_t batch_idx, void* user_data) {
    zip_write_batch_arg_t* ctx = (zip_write_batch_arg_t*)user_data;
    size_t start_idx = batch_idx;
    size_t item_span = 1;
    if (ctx->batch_list->units && batch_idx < ctx->batch_list->count) {
        start_idx = ctx->batch_list->units[batch_idx].start_index;
        item_span = ctx->batch_list->units[batch_idx].count;
    }

    for (size_t sub = 0; sub < item_span; sub++) {
        size_t idx = start_idx + sub;
        if (idx >= ctx->list->count) break;

        ttzip_c_item_t* item = &ctx->list->items[idx];
        if (item->is_directory || item->uncompressed_size == 0) {
            item->actual_method = 0;
            item->compressed_size = 0;
            item->crc32 = 0;
            continue;
        }

        size_t item_unc_size = ttzip_clamp_size((uint64_t)item->uncompressed_size);

        int fd = open(item->src_path, O_RDONLY);
        if (fd < 0) {
            continue;
        }

        uint8_t stack_in_buf[65536];
        uint8_t stack_out_buf[65536 + 512];
        void* src_buf = NULL;
        uint8_t* heap_src = NULL;

        if (item_unc_size <= sizeof(stack_in_buf)) {
            ssize_t read_bytes = pread(fd, stack_in_buf, item_unc_size, 0);
            if (read_bytes == (ssize_t)item_unc_size) {
                src_buf = stack_in_buf;
            }
        } else if (item_unc_size >= 64 * 1024) {
            src_buf = mmap(NULL, item_unc_size, PROT_READ, MAP_SHARED, fd, 0);
            if (src_buf != MAP_FAILED) {
                madvise(src_buf, item_unc_size, MADV_WILLNEED | MADV_SEQUENTIAL);
            }
        }

        if (!src_buf || src_buf == MAP_FAILED) {
            heap_src = (uint8_t*)malloc(item_unc_size);
            if (heap_src) {
                ssize_t read_bytes = pread(fd, heap_src, item_unc_size, 0);
                if (read_bytes == (ssize_t)item_unc_size) {
                    src_buf = heap_src;
                }
            }
        }

        if (!src_buf) {
            close(fd);
            continue;
        }

        uint32_t computed_crc = ttzip_compute_buffer_crc32_neon(0, src_buf, item_unc_size);
        uint8_t* arena_slot = (ctx->payload_arena && item->arena_cap >= item_unc_size) ? (ctx->payload_arena + item->arena_offset) : NULL;

        if (ctx->level == 0) {
            item->actual_method = 0;
            if (ctx->has_password) {
                size_t enc_size = item_unc_size + 18 + 10;
                uint8_t* enc_buf = arena_slot ? arena_slot : (uint8_t*)malloc(enc_size);
                if (enc_buf) {
                    arc4random_buf(enc_buf, 16);
                    uint8_t derived_keys[66];
                    size_t pass_len = strlen(ctx->password);
                    if (ttzip_pbkdf2_sha1_fast(ctx->password, pass_len, enc_buf, 16, 1000, derived_keys, 66) == 0) {
                        enc_buf[16] = derived_keys[64];
                        enc_buf[17] = derived_keys[65];
                        uint8_t* cipher_dst = enc_buf + 18;
                        ttzip_aes256_encrypt_and_hmac_fused(derived_keys, (const uint8_t*)src_buf, item_unc_size, cipher_dst, enc_buf + 18 + item_unc_size);
                        item->compressed_payload = enc_buf;
                        item->compressed_size = (int64_t)enc_size;
                    } else if (!arena_slot) {
                        free(enc_buf);
                    }
                    ttzip_secure_zero(derived_keys, sizeof(derived_keys));
                }
            } else {
                if (arena_slot) {
                    memcpy(arena_slot, src_buf, item_unc_size);
                    item->compressed_payload = arena_slot;
                } else if (src_buf == stack_in_buf) {
                    uint8_t* store_buf = (uint8_t*)malloc(item_unc_size);
                    if (store_buf) {
                        memcpy(store_buf, stack_in_buf, item_unc_size);
                        item->compressed_payload = store_buf;
                    }
                } else {
                    item->compressed_payload = src_buf;
                    item->is_mmapped = (heap_src == NULL);
                }
                item->compressed_size = item->uncompressed_size;
            }
        } else {
            struct libdeflate_compressor* compressor = ttzip_get_tls_compressor(ctx->level > 0 ? ctx->level : 6);
            if (compressor) {
                size_t max_comp_bound = libdeflate_deflate_compress_bound(compressor, item_unc_size);
                uint8_t* comp_buf = arena_slot ? arena_slot : ((max_comp_bound <= sizeof(stack_out_buf)) ? stack_out_buf : (uint8_t*)malloc(max_comp_bound));

                if (comp_buf) {
                    size_t actual_comp_size = libdeflate_deflate_compress(compressor, src_buf, item_unc_size, comp_buf, max_comp_bound);
                    if (actual_comp_size > 0 && (int64_t)actual_comp_size < item->uncompressed_size) {
                        item->actual_method = 8;
                        if (ctx->has_password) {
                            size_t enc_size = actual_comp_size + 18 + 10;
                            uint8_t* enc_buf = arena_slot ? arena_slot : (uint8_t*)malloc(enc_size);
                            if (enc_buf) {
                                uint8_t tmp_comp[65536];
                                uint8_t* safe_comp_src = comp_buf;
                                if (comp_buf == arena_slot && actual_comp_size <= sizeof(tmp_comp)) {
                                    memcpy(tmp_comp, comp_buf, actual_comp_size);
                                    safe_comp_src = tmp_comp;
                                }
                                arc4random_buf(enc_buf, 16);
                                uint8_t derived_keys[66];
                                size_t pass_len = strlen(ctx->password);
                                if (ttzip_pbkdf2_sha1_fast(ctx->password, pass_len, enc_buf, 16, 1000, derived_keys, 66) == 0) {
                                    enc_buf[16] = derived_keys[64];
                                    enc_buf[17] = derived_keys[65];
                                    uint8_t* cipher_dst = enc_buf + 18;
                                    ttzip_aes256_encrypt_and_hmac_fused(derived_keys, safe_comp_src, actual_comp_size, cipher_dst, enc_buf + 18 + actual_comp_size);
                                    item->compressed_payload = enc_buf;
                                    item->compressed_size = (int64_t)enc_size;
                                } else if (!arena_slot) {
                                    free(enc_buf);
                                }
                                ttzip_secure_zero(derived_keys, sizeof(derived_keys));
                            }
                        } else {
                            if (arena_slot) {
                                item->compressed_payload = arena_slot;
                                item->compressed_size = (int64_t)actual_comp_size;
                            } else {
                                uint8_t* final_comp = (uint8_t*)malloc(actual_comp_size);
                                if (final_comp) {
                                    memcpy(final_comp, comp_buf, actual_comp_size);
                                    item->compressed_payload = final_comp;
                                    item->compressed_size = (int64_t)actual_comp_size;
                                }
                            }
                        }
                    } else {
                        item->actual_method = 0;
                        if (ctx->has_password) {
                            size_t enc_size = item_unc_size + 18 + 10;
                            uint8_t* enc_buf = arena_slot ? arena_slot : (uint8_t*)malloc(enc_size);
                            if (enc_buf) {
                                arc4random_buf(enc_buf, 16);
                                uint8_t derived_keys[66];
                                size_t pass_len = strlen(ctx->password);
                                if (ttzip_pbkdf2_sha1_fast(ctx->password, pass_len, enc_buf, 16, 1000, derived_keys, 66) == 0) {
                                    enc_buf[16] = derived_keys[64];
                                    enc_buf[17] = derived_keys[65];
                                    uint8_t* cipher_dst = enc_buf + 18;
                                    ttzip_aes256_encrypt_and_hmac_fused(derived_keys, (const uint8_t*)src_buf, item_unc_size, cipher_dst, enc_buf + 18 + item_unc_size);
                                    item->compressed_payload = enc_buf;
                                    item->compressed_size = (int64_t)enc_size;
                                } else if (!arena_slot) {
                                    free(enc_buf);
                                }
                                ttzip_secure_zero(derived_keys, sizeof(derived_keys));
                            }
                        } else {
                            if (arena_slot) {
                                memcpy(arena_slot, src_buf, item_unc_size);
                                item->compressed_payload = arena_slot;
                            } else if (src_buf == stack_in_buf) {
                                uint8_t* store_buf = (uint8_t*)malloc(item_unc_size);
                                if (store_buf) {
                                    memcpy(store_buf, stack_in_buf, item_unc_size);
                                    item->compressed_payload = store_buf;
                                }
                            } else {
                                item->compressed_payload = src_buf;
                                item->is_mmapped = (heap_src == NULL);
                            }
                            item->compressed_size = item->uncompressed_size;
                        }
                    }
                    if (!arena_slot && comp_buf != stack_out_buf && item->compressed_payload != comp_buf) {
                        free(comp_buf);
                    }
                }
            }
        }

        item->crc32 = computed_crc;

        if (item->compressed_payload != src_buf && src_buf != stack_in_buf) {
            if (heap_src) {
                free(heap_src);
            } else if (src_buf && src_buf != MAP_FAILED) {
                munmap(src_buf, (size_t)item->uncompressed_size);
            }
        }
        close(fd);
    }
}

int ttzip_create_zip_parallel_c(
    const char* output_zip_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    bool skip_mac_junk,
    const char* password
) {
    if (!output_zip_path || !input_paths || input_count == 0) return TTZIP_ERR_INVALID_PARAM;
    
    ttzip_c_item_list_t list = { NULL, 0, 0 };
    for (size_t i = 0; i < input_count; i++) {
        const char* src_path = input_paths[i];
        if (!src_path || strlen(src_path) == 0) continue;
        const char* last_slash = strrchr(src_path, '/');
        const char* base_name = last_slash ? (last_slash + 1) : src_path;
        collect_c_items_recursive(src_path, base_name, skip_mac_junk, &list);
    }
    
    if (list.count == 0) {
        if (list.items) free(list.items);
        return TTZIP_ERR_INVALID_PARAM;
    }

    bool has_password = (password && strlen(password) > 0);

    // 1. Calculate total uncompressed bytes and construct 128-byte cache-line aligned payload Arena
    uint64_t total_uncompressed_bytes = 0;
    for (size_t i = 0; i < list.count; i++) {
        if (!list.items[i].is_directory && list.items[i].uncompressed_size > 0) {
            total_uncompressed_bytes += (uint64_t)list.items[i].uncompressed_size;
        }
    }

    uint8_t* payload_arena = NULL;
    if (total_uncompressed_bytes > 0 && total_uncompressed_bytes <= 128 * 1024 * 1024) {
        size_t curr_off = 0;
        for (size_t i = 0; i < list.count; i++) {
            if (!list.items[i].is_directory && list.items[i].uncompressed_size > 0) {
                size_t unc = (size_t)list.items[i].uncompressed_size;
                size_t bound = (level == 0) ? (unc + 64) : (unc + 1024 + unc / 8);
                size_t aligned_bound = (bound + 127) & ~((size_t)127);
                list.items[i].arena_offset = curr_off;
                list.items[i].arena_cap = aligned_bound;
                curr_off += aligned_bound;
            }
        }
        size_t arena_cap = curr_off + 128;
        payload_arena = (uint8_t*)ttzip_core_aligned_alloc_128b(arena_cap);
    }

    // 2. Cluster small files into dynamic cache-optimal batch units
    size_t target_batch_bytes = ttzip_cache_get_optimal_batch_size();
    size_t max_files = ttzip_cache_get_optimal_max_files();
    ttzip_c_batch_list_t batch_list = { NULL, 0, 0 };
    if (ttzip_cluster_small_files_into_batches(&list, target_batch_bytes, max_files, &batch_list) != 0 || batch_list.count == 0) {
        // Fallback to 1:1 mapping if batch clustering fails
        batch_list.units = (ttzip_c_batch_unit_t*)malloc(list.count * sizeof(ttzip_c_batch_unit_t));
        if (batch_list.units) {
            batch_list.count = list.count;
            batch_list.capacity = list.count;
            for (size_t i = 0; i < list.count; i++) {
                batch_list.units[i].start_index = i;
                batch_list.units[i].count = 1;
                batch_list.units[i].total_uncompressed_bytes = (uint64_t)list.items[i].uncompressed_size;
                batch_list.units[i].arena_offset = list.items[i].arena_offset;
                batch_list.units[i].arena_cap = list.items[i].arena_cap;
            }
        }
    }

    // 3. Parallel zero-lock compression across batch units
    size_t batch_count_to_process = (batch_list.count > 0) ? batch_list.count : list.count;
    zip_write_batch_arg_t batch_arg = {
        .list = &list,
        .batch_list = &batch_list,
        .payload_arena = payload_arena,
        .level = level,
        .has_password = has_password,
        .password = password
    };
    ttzip_parallel_for(ttzip_threadpool_shared(), batch_count_to_process, zip_write_batch_worker, &batch_arg);

    if (batch_list.units) {
        free(batch_list.units);
    }

    int res = ttzip_write_zip_archive_disk(output_zip_path, &list, has_password);

    if (payload_arena) {
        ttzip_core_aligned_free_128b(payload_arena);
    } else {
        for (size_t i = 0; i < list.count; i++) {
            if (list.items[i].compressed_payload) {
                if (list.items[i].is_mmapped) {
                    munmap(list.items[i].compressed_payload, (size_t)list.items[i].uncompressed_size);
                } else {
                    free(list.items[i].compressed_payload);
                }
            }
        }
    }
    free(list.items);
    return res;
}
