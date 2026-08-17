#include "include/CTTZipBridge_7zStore.h"
#include "include/CTTZip7zStoreInternal.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipCoreArchitecture.h"
#include "include/CTTZipBridge_Archive.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libdeflate.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <dispatch/dispatch.h>
#include <errno.h>

static uint64_t ttzip_posix_to_filetime(time_t sec) {
    return ((uint64_t)sec + 11644473600ULL) * 10000000ULL;
}

int ttzip_create_7z_store_fast_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count
) {
    if (!output_path || !input_paths || input_count == 0) return TTZIP_ERR_INVALID_PARAM;

    ttzip_7z_store_list_t list = {NULL, 0, 0};
    for (size_t i = 0; i < input_count; i++) {
        if (!input_paths[i]) continue;
        const char* base = strrchr(input_paths[i], '/');
        base = base ? base + 1 : input_paths[i];
        ttzip_7z_collect_recursive(input_paths[i], base, &list);
    }
    if (list.count == 0) {
        free(list.entries);
        return TTZIP_ERR_INVALID_PARAM;
    }

    unlink(output_path);
    int out_fd = open(output_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (out_fd < 0) {
        free(list.entries);
        return TTZIP_ERR_OPEN_FAILED;
    }

    uint64_t total_payload_bytes = 0;
    for (size_t i = 0; i < list.count; i++) {
        total_payload_bytes += list.entries[i].file_size;
    }
    uint64_t estimated_total = 32 + total_payload_bytes + (list.count * 512) + 4096;
    ttzip_core_apfs_preallocate_file(out_fd, (int64_t)estimated_total);
    ftruncate(out_fd, (off_t)estimated_total);

    uint8_t sig_header[32] = {
        0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C,
        0x00, 0x04,
        0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0
    };
    ttzip_7z_write_all(out_fd, sig_header, 32);

    uint64_t current_offset = 32;
    for (size_t i = 0; i < list.count; i++) {
        if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
            list.entries[i].payload_buf = (uint8_t*)current_offset;
            current_offset += list.entries[i].file_size;
        }
    }

    dispatch_queue_t concurrent_q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_semaphore_t fd_sem = dispatch_semaphore_create(128);
    dispatch_apply(list.count, concurrent_q, ^(size_t i) {
        ttzip_7z_store_entry_t* item = &list.entries[i];
        if (item->is_directory || item->file_size == 0) {
            item->crc32 = 0;
            return;
        }
        dispatch_semaphore_wait(fd_sem, DISPATCH_TIME_FOREVER);
        int in_fd = open(item->src_path, O_RDONLY);
        if (in_fd >= 0) {
            uint64_t offset = (uint64_t)item->payload_buf;
            char buf[65536];
            uint32_t crc = 0;
            size_t total_rd = 0;
            while (total_rd < (size_t)item->file_size) {
                ssize_t rd = read(in_fd, buf, sizeof(buf));
                if (rd <= 0) break;
                crc = libdeflate_crc32(crc, buf, (size_t)rd);
                ssize_t wr = pwrite(out_fd, buf, (size_t)rd, offset + total_rd);
                if (wr < 0) {
                    ttzip_log(1, "pwrite error: %s (fd=%d, offset=%llu, size=%zd)\n", strerror(errno), out_fd, offset + total_rd, (size_t)rd);
                }
                total_rd += rd;
            }
            if (total_rd != (size_t)item->file_size) {
                memset(buf, 0, sizeof(buf));
                while (total_rd < (size_t)item->file_size) {
                    size_t chunk = ((size_t)item->file_size - total_rd) > sizeof(buf) ? sizeof(buf) : ((size_t)item->file_size - total_rd);
                    crc = libdeflate_crc32(crc, buf, chunk);
                    pwrite(out_fd, buf, chunk, offset + total_rd);
                    total_rd += chunk;
                }
            }
            item->crc32 = crc;
            close(in_fd);
        } else {
            uint64_t offset = (uint64_t)item->payload_buf;
            char buf[65536] = {0};
            uint32_t crc = 0;
            size_t total_rd = 0;
            while (total_rd < (size_t)item->file_size) {
                size_t chunk = ((size_t)item->file_size - total_rd) > sizeof(buf) ? sizeof(buf) : ((size_t)item->file_size - total_rd);
                crc = libdeflate_crc32(crc, buf, chunk);
                pwrite(out_fd, buf, chunk, offset + total_rd);
                total_rd += chunk;
            }
            item->crc32 = crc;
        }
        dispatch_semaphore_signal(fd_sem);
    });

    size_t num_files = list.count;
    size_t num_streams = 0;
    size_t num_empty_streams = 0;
    size_t num_empty_files = 0;
    
    for (size_t i = 0; i < num_files; i++) {
        if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
            num_streams++;
        } else {
            num_empty_streams++;
            if (!list.entries[i].is_directory && list.entries[i].file_size == 0) {
                num_empty_files++;
            }
        }
    }

    size_t total_names_len = 0;
    for (size_t i = 0; i < list.count; i++) {
        if (list.entries[i].rel_path[0] != '\0') total_names_len += strlen(list.entries[i].rel_path);
    }
    size_t header_cap = 1024 * 1024 + num_files * 512 + total_names_len * 4;
    uint8_t* header_buf = (uint8_t*)malloc(header_cap);
    if (!header_buf) {
        close(out_fd);
        free(list.entries);
        return TTZIP_ERR_INVALID_PARAM;
    }
    size_t h_idx = 0;

    header_buf[h_idx++] = 0x01; // kHeader
    
    if (num_streams > 0) {
        header_buf[h_idx++] = 0x04; // kMainStreamsInfo

        header_buf[h_idx++] = 0x06; // kPackInfo
        h_idx += ttzip_7z_write_varint(header_buf + h_idx, 0);
        h_idx += ttzip_7z_write_varint(header_buf + h_idx, num_streams);
        header_buf[h_idx++] = 0x09; // kSize
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                h_idx += ttzip_7z_write_varint(header_buf + h_idx, list.entries[i].file_size);
            }
        }
        header_buf[h_idx++] = 0x00; // kEnd

        header_buf[h_idx++] = 0x07; // kUnpackInfo
        header_buf[h_idx++] = 0x0B; // kFolder
        h_idx += ttzip_7z_write_varint(header_buf + h_idx, num_streams);
        header_buf[h_idx++] = 0x00; // External
        for (size_t i = 0; i < num_streams; i++) {
            h_idx += ttzip_7z_write_varint(header_buf + h_idx, 1);
            header_buf[h_idx++] = 0x01;
            header_buf[h_idx++] = 0x00; // Copy
        }
        header_buf[h_idx++] = 0x0C; // kCodersUnpackSize
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                h_idx += ttzip_7z_write_varint(header_buf + h_idx, list.entries[i].file_size);
            }
        }
        header_buf[h_idx++] = 0x0A; // kCRC
        header_buf[h_idx++] = 0x01; // AllAreDefined = 1
        for (size_t i = 0; i < num_files; i++) {
            if (!list.entries[i].is_directory && list.entries[i].file_size > 0) {
                uint32_t c = list.entries[i].crc32;
                memcpy(header_buf + h_idx, &c, 4);
                h_idx += 4;
            }
        }

        header_buf[h_idx++] = 0x00; // kEnd of kUnpackInfo

        header_buf[h_idx++] = 0x08; // kSubStreamsInfo
        header_buf[h_idx++] = 0x00; // kEnd of kSubStreamsInfo
        header_buf[h_idx++] = 0x00; // kEnd of kMainStreamsInfo
    } // end kMainStreamsInfo

    header_buf[h_idx++] = 0x05; // kFilesInfo
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, num_files);
    
    if (num_empty_streams > 0) {
        header_buf[h_idx++] = 0x0E; // kEmptyStream
        size_t empty_stream_bytes = (num_files + 7) / 8;
        h_idx += ttzip_7z_write_varint(header_buf + h_idx, empty_stream_bytes);
        memset(header_buf + h_idx, 0, empty_stream_bytes);
        for (size_t i = 0; i < num_files; i++) {
            if (list.entries[i].is_directory || list.entries[i].file_size == 0) {
                header_buf[h_idx + i / 8] |= (1 << (7 - (i % 8)));
            }
        }
        h_idx += empty_stream_bytes;

        if (num_empty_files > 0) {
            header_buf[h_idx++] = 0x0F; // kEmptyFile
            size_t empty_file_bytes = (num_empty_streams + 7) / 8;
            h_idx += ttzip_7z_write_varint(header_buf + h_idx, empty_file_bytes);
            memset(header_buf + h_idx, 0, empty_file_bytes);
            size_t empty_idx = 0;
            for (size_t i = 0; i < num_files; i++) {
                if (list.entries[i].is_directory || list.entries[i].file_size == 0) {
                    if (!list.entries[i].is_directory && list.entries[i].file_size == 0) {
                        header_buf[h_idx + empty_idx / 8] |= (1 << (7 - (empty_idx % 8)));
                    }
                    empty_idx++;
                }
            }
            h_idx += empty_file_bytes;
        }
    }

    header_buf[h_idx++] = 0x11; // kName
    size_t name_data_len = 1;
    for (size_t i = 0; i < list.count; i++) {
        name_data_len += (strlen(list.entries[i].rel_path) + 1) * 2;
    }
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, name_data_len);
    header_buf[h_idx++] = 0x00;
    for (size_t i = 0; i < list.count; i++) {
        const char* rpath = list.entries[i].rel_path;
        size_t rlen = strlen(rpath);
        for (size_t j = 0; j < rlen; j++) {
            uint16_t u16 = (uint16_t)(uint8_t)rpath[j];
            memcpy(header_buf + h_idx, &u16, 2);
            h_idx += 2;
        }
        uint16_t zero = 0;
        memcpy(header_buf + h_idx, &zero, 2);
        h_idx += 2;
    }

    header_buf[h_idx++] = 0x14;
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, 2 + list.count * 8);
    header_buf[h_idx++] = 0x01; // AllAreDefined = 1
    header_buf[h_idx++] = 0x00; // External = 0
    for (size_t i = 0; i < list.count; i++) {
        uint64_t ft = ttzip_posix_to_filetime(list.entries[i].mtime);
        memcpy(header_buf + h_idx, &ft, 8);
        h_idx += 8;
    }

    header_buf[h_idx++] = 0x15;
    h_idx += ttzip_7z_write_varint(header_buf + h_idx, 2 + list.count * 4);
    header_buf[h_idx++] = 0x01; // AllAreDefined = 1
    header_buf[h_idx++] = 0x00; // External = 0
    for (size_t i = 0; i < list.count; i++) {
        uint32_t attr = list.entries[i].is_directory ? 0x10 : 0x20;
        memcpy(header_buf + h_idx, &attr, 4);
        h_idx += 4;
    }

    header_buf[h_idx++] = 0x00;
    header_buf[h_idx++] = 0x00;

    lseek(out_fd, 32 + total_payload_bytes, SEEK_SET);
    write(out_fd, header_buf, h_idx);

    uint64_t next_header_offset = total_payload_bytes;
    uint64_t next_header_size = h_idx;
    uint32_t next_header_crc = ttzip_compute_buffer_crc32(header_buf, h_idx);

    memcpy(sig_header + 12, &next_header_offset, 8);
    memcpy(sig_header + 20, &next_header_size, 8);
    memcpy(sig_header + 28, &next_header_crc, 4);

    uint32_t start_header_crc = ttzip_compute_buffer_crc32(sig_header + 12, 20);
    memcpy(sig_header + 8, &start_header_crc, 4);

    lseek(out_fd, 0, SEEK_SET);
    write(out_fd, sig_header, 32);

    ftruncate(out_fd, (off_t)(32 + total_payload_bytes + h_idx));

    close(out_fd);
    free(header_buf);
    free(list.entries);
    return TTZIP_OK;
}
