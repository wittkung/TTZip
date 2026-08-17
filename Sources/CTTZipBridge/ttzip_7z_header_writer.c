// ttzip_7z_header_writer.c
// TTZip 原生 7z 容器头部元数据序列化与落盘中枢 (拆分自 ttzip_lzma2_enc_native.c，严格控制单文件 < 500 行)

#include "include/ttzip_7z_header_writer.h"
#include "include/CTTZipBridge.h"
#include "include/CTTZipCommon.h"
#include "include/CTTZipSliceProfiler.h"
#include "include/CTTZipIO.h"

#include <stdlib.h>
#include <string.h>
#include <unistd.h>

size_t ttzip_7z_enc_write_varint(uint8_t* buf, uint64_t val) {
    if (val < 0x80) {
        buf[0] = (uint8_t)val;
        return 1;
    }
    for (uint8_t extra_bytes = 1; extra_bytes <= 8; extra_bytes++) {
        uint8_t high_bits_count = 8 - (extra_bytes + 1);
        uint64_t max_val = ((uint64_t)1 << (8 * extra_bytes + high_bits_count)) - 1;
        if (val <= max_val || extra_bytes == 8) {
            uint8_t first_mask = (uint8_t)(0xFF << (8 - extra_bytes));
            uint8_t high_val = (uint8_t)(val >> (8 * extra_bytes));
            buf[0] = first_mask | high_val;
            for (size_t i = 1; i <= extra_bytes; i++) {
                buf[i] = (uint8_t)(val >> ((i - 1) * 8));
            }
            return 1 + extra_bytes;
        }
    }
    return 0;
}

size_t ttzip_7z_enc_utf8_to_utf16le(const char* utf8, uint8_t* out_utf16) {
    size_t in_len = strlen(utf8);
    size_t out_idx = 0;
    size_t i = 0;
    while (i < in_len) {
        uint32_t codepoint = 0;
        uint8_t b0 = (uint8_t)utf8[i++];
        if (b0 < 0x80) {
            codepoint = b0;
        } else if ((b0 & 0xE0) == 0xC0 && i < in_len) {
            uint8_t b1 = (uint8_t)utf8[i++];
            codepoint = ((b0 & 0x1F) << 6) | (b1 & 0x3F);
        } else if ((b0 & 0xF0) == 0xE0 && i + 1 < in_len) {
            uint8_t b1 = (uint8_t)utf8[i++];
            uint8_t b2 = (uint8_t)utf8[i++];
            codepoint = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F);
        } else if ((b0 & 0xF8) == 0xF0 && i + 2 < in_len) {
            uint8_t b1 = (uint8_t)utf8[i++];
            uint8_t b2 = (uint8_t)utf8[i++];
            uint8_t b3 = (uint8_t)utf8[i++];
            codepoint = ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F);
        } else {
            codepoint = 0xFFFD;
        }

        if (codepoint < 0x10000) {
            if (out_utf16) {
                out_utf16[out_idx] = (uint8_t)(codepoint & 0xFF);
                out_utf16[out_idx + 1] = (uint8_t)((codepoint >> 8) & 0xFF);
            }
            out_idx += 2;
        } else {
            codepoint -= 0x10000;
            uint16_t high = (uint16_t)(0xD800 + (codepoint >> 10));
            uint16_t low = (uint16_t)(0xDC00 + (codepoint & 0x3FF));
            if (out_utf16) {
                out_utf16[out_idx] = (uint8_t)(high & 0xFF);
                out_utf16[out_idx + 1] = (uint8_t)((high >> 8) & 0xFF);
                out_utf16[out_idx + 2] = (uint8_t)(low & 0xFF);
                out_utf16[out_idx + 3] = (uint8_t)((low >> 8) & 0xFF);
            }
            out_idx += 4;
        }
    }
    return out_idx;
}

uint8_t ttzip_7z_enc_dict_to_prop(uint32_t dict_size) {
    if (dict_size == 0) return 0;
    for (uint8_t p = 0; p < 40; p++) {
        uint32_t sz = (2 | (p & 1)) << (p / 2 + 11);
        if (sz >= dict_size) return p;
    }
    return 39;
}

int ttzip_7z_write_metadata_and_flush(
    int out_fd,
    const ttzip_7z_store_list_t* list,
    const ttzip_7z_header_params_t* params
) {
    if (!list || !params || out_fd < 0) return TTZIP_ERR_INVALID_PARAM;

    size_t num_files = list->count;
    size_t total_names_len = 0;
    for (size_t i = 0; i < list->count; i++) {
        if (list->entries[i].rel_path[0] != '\0')
            total_names_len += strlen(list->entries[i].rel_path);
    }
    size_t header_cap = 1024 * 1024 + num_files * 512 + total_names_len * 4;
    uint8_t* header_buf = (uint8_t*)malloc(header_cap);
    if (!header_buf) {
        return TTZIP_ERR_OUT_OF_MEMORY;
    }
    size_t h = 0;

    header_buf[h++] = 0x01; // kHeader
    header_buf[h++] = 0x04; // kMainStreamsInfo
    header_buf[h++] = 0x06; // kPackInfo
    h += ttzip_7z_enc_write_varint(header_buf + h, 0);
    h += ttzip_7z_enc_write_varint(header_buf + h, 1);
    header_buf[h++] = 0x09; // kSize
    h += ttzip_7z_enc_write_varint(header_buf + h, params->packed_stream_size);
    header_buf[h++] = 0x00; // End PackInfo

    header_buf[h++] = 0x07; // kUnpackInfo
    header_buf[h++] = 0x0B; // kFolder
    h += ttzip_7z_enc_write_varint(header_buf + h, 1); // NumFolders = 1
    header_buf[h++] = 0x00; // External = 0

    if (params->has_password) {
        // NumCoders = 2: (Copy / LZMA2) + AES-256-SHA-256
        header_buf[h++] = 0x02;

        // Coder 0: (Copy or LZMA2)
        if (params->level == 0) {
            header_buf[h++] = 0x01; // flags: id_size=1, has_attributes=0
            header_buf[h++] = 0x00; // Method ID: Copy (0x00)
        } else {
            header_buf[h++] = 0x21; // flags: id_size=1, has_attributes=1
            header_buf[h++] = 0x21; // Method ID: LZMA2
            header_buf[h++] = 0x01; // Attributes size = 1
            header_buf[h++] = ttzip_7z_enc_dict_to_prop(params->max_dict_size);
        }

        // Coder 1: AES-256-SHA-256
        uint8_t aes_props[2 + 16];
        aes_props[0] = (uint8_t)(params->num_cycles_power | 0x40);
        aes_props[1] = (uint8_t)(0x00 | (15 << 4)); // saltSize=0, ivSize=16
        if (params->aes_iv) {
            memcpy(aes_props + 2, params->aes_iv, 16);
        } else {
            memset(aes_props + 2, 0, 16);
        }
        size_t aes_props_len = 2 + 16;

        header_buf[h++] = 0x24; // flags: id_size=4, has_attributes=1 (0x20 | 0x04)
        header_buf[h++] = 0x06;
        header_buf[h++] = 0xF1;
        header_buf[h++] = 0x07;
        header_buf[h++] = 0x01;
        header_buf[h++] = (uint8_t)aes_props_len;
        memcpy(header_buf + h, aes_props, aes_props_len);
        h += aes_props_len;

        header_buf[h++] = 0x00; // BindPair InIndex
        header_buf[h++] = 0x01; // BindPair OutIndex
    } else {
        header_buf[h++] = 0x01;
        if (params->level == 0) {
            header_buf[h++] = 0x01;
            header_buf[h++] = 0x00;
        } else {
            header_buf[h++] = 0x21;
            header_buf[h++] = 0x21;
            header_buf[h++] = 0x01;
            header_buf[h++] = ttzip_7z_enc_dict_to_prop(params->max_dict_size);
        }
    }

    header_buf[h++] = 0x0C; // kCodersUnpackSize
    if (params->has_password) {
        h += ttzip_7z_enc_write_varint(header_buf + h, params->total_uncompressed_bytes);
        h += ttzip_7z_enc_write_varint(header_buf + h, params->total_compressed_len);
    } else {
        h += ttzip_7z_enc_write_varint(header_buf + h, params->total_uncompressed_bytes);
    }
    header_buf[h++] = 0x00; // End UnpackInfo

    header_buf[h++] = 0x08; // kSubStreamsInfo
    if (params->num_streams > 1) {
        header_buf[h++] = 0x0D; // kNumUnPackStream
        h += ttzip_7z_enc_write_varint(header_buf + h, params->num_streams);
        header_buf[h++] = 0x09; // kSize
        size_t stream_idx = 0;
        for (size_t i = 0; i < num_files; i++) {
            if (!list->entries[i].is_directory && list->entries[i].file_size > 0) {
                stream_idx++;
                if (stream_idx < params->num_streams) {
                    h += ttzip_7z_enc_write_varint(header_buf + h, list->entries[i].file_size);
                }
            }
        }
    }

    header_buf[h++] = 0x0A; // kCRC
    header_buf[h++] = 0x01; // AllAreDefined
    for (size_t i = 0; i < num_files; i++) {
        if (!list->entries[i].is_directory && list->entries[i].file_size > 0) {
            uint32_t c = list->entries[i].crc32;
            memcpy(header_buf + h, &c, 4);
            h += 4;
        }
    }
    header_buf[h++] = 0x00; // End SubStreamsInfo
    header_buf[h++] = 0x00; // End MainStreamsInfo

    header_buf[h++] = 0x05; // kFilesInfo
    h += ttzip_7z_enc_write_varint(header_buf + h, num_files);

    if (params->num_empty_streams > 0) {
        header_buf[h++] = 0x0E; // kEmptyStream
        size_t empty_stream_bytes = (num_files + 7) / 8;
        h += ttzip_7z_enc_write_varint(header_buf + h, empty_stream_bytes);
        memset(header_buf + h, 0, empty_stream_bytes);
        for (size_t i = 0; i < num_files; i++) {
            if (list->entries[i].is_directory || list->entries[i].file_size == 0) {
                header_buf[h + i / 8] |= (1 << (7 - (i % 8)));
            }
        }
        h += empty_stream_bytes;

        if (params->num_empty_files > 0) {
            header_buf[h++] = 0x0F; // kEmptyFile
            size_t empty_file_bytes = (params->num_empty_streams + 7) / 8;
            h += ttzip_7z_enc_write_varint(header_buf + h, empty_file_bytes);
            memset(header_buf + h, 0, empty_file_bytes);
            size_t empty_idx = 0;
            for (size_t i = 0; i < num_files; i++) {
                if (list->entries[i].is_directory || list->entries[i].file_size == 0) {
                    if (!list->entries[i].is_directory && list->entries[i].file_size == 0) {
                        header_buf[h + empty_idx / 8] |= (1 << (7 - (empty_idx % 8)));
                    }
                    empty_idx++;
                }
            }
            h += empty_file_bytes;
        }
    }

    header_buf[h++] = 0x11; // kName
    size_t name_data_len = 1;
    for (size_t i = 0; i < list->count; i++) {
        name_data_len += ttzip_7z_enc_utf8_to_utf16le(list->entries[i].rel_path, NULL) + 2;
    }
    h += ttzip_7z_enc_write_varint(header_buf + h, name_data_len);
    header_buf[h++] = 0x00;
    for (size_t i = 0; i < list->count; i++) {
        size_t written = ttzip_7z_enc_utf8_to_utf16le(list->entries[i].rel_path, header_buf + h);
        h += written;
        uint16_t zero = 0;
        memcpy(header_buf + h, &zero, 2);
        h += 2;
    }

    header_buf[h++] = 0x14; // kMTime
    h += ttzip_7z_enc_write_varint(header_buf + h, 2 + list->count * 8);
    header_buf[h++] = 0x01;
    header_buf[h++] = 0x00;
    for (size_t i = 0; i < list->count; i++) {
        uint64_t ft = ((uint64_t)list->entries[i].mtime + 11644473600ULL) * 10000000ULL;
        memcpy(header_buf + h, &ft, 8);
        h += 8;
    }

    header_buf[h++] = 0x15; // kAttributes
    h += ttzip_7z_enc_write_varint(header_buf + h, 2 + list->count * 4);
    header_buf[h++] = 0x01;
    header_buf[h++] = 0x00;
    for (size_t i = 0; i < list->count; i++) {
        uint32_t attr = list->entries[i].is_directory ? 0x10 : 0x20;
        memcpy(header_buf + h, &attr, 4);
        h += 4;
    }

    header_buf[h++] = 0x00; // End FilesInfo
    header_buf[h++] = 0x00; // End Header

    TTZIP_SLICE_SCOPE_BEGIN("6_HeaderWrite_and_Flush");
    uint32_t header_crc = ttzip_compute_buffer_crc32_neon(0, header_buf, h);
    ttzip_7z_write_all(out_fd, header_buf, h);
    free(header_buf);

    uint64_t next_header_offset = params->packed_stream_size;
    uint64_t header_size = h;

    uint8_t updated[32] = {
        0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C,
        0x00, 0x04,
        0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0
    };
    memcpy(updated + 12, &next_header_offset, 8);
    memcpy(updated + 20, &header_size, 8);
    memcpy(updated + 28, &header_crc, 4);
    uint32_t sig_crc = ttzip_compute_buffer_crc32_neon(0, updated + 12, 20);
    memcpy(updated + 8, &sig_crc, 4);

    lseek(out_fd, 0, SEEK_SET);
    ttzip_7z_write_all(out_fd, updated, 32);

    ftruncate(out_fd, (off_t)(32 + params->packed_stream_size + h));
    close(out_fd);
    TTZIP_SLICE_SCOPE_END("6_HeaderWrite_and_Flush");

    return TTZIP_OK;
}
