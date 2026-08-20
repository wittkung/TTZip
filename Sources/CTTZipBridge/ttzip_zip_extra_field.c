// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_zip_extra_field.h"
#include "include/CTTZipChecksum.h"
#include <string.h>

static inline uint16_t read_u16_le(const uint8_t* p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static inline uint32_t read_u32_le(const uint8_t* p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static inline uint64_t read_u64_le(const uint8_t* p) {
    return (uint64_t)read_u32_le(p) | ((uint64_t)read_u32_le(p + 4) << 32);
}

int ttzip_zip_parse_extra_fields(
    const uint8_t* extra_data,
    size_t extra_len,
    const char* standard_filename,
    ttzip_zip_extra_fields_t* out_fields
) {
    if (!out_fields) return -1;
    memset(out_fields, 0, sizeof(*out_fields));
    if (!extra_data || extra_len < 4) return 0;

    size_t offset = 0;
    while (offset + 4 <= extra_len) {
        uint16_t header_id = read_u16_le(extra_data + offset);
        uint16_t data_size = read_u16_le(extra_data + offset + 2);

        size_t payload_offset = offset + 4;
        if (payload_offset + data_size > extra_len) {
            break; // Truncated block
        }

        const uint8_t* payload = extra_data + payload_offset;

        switch (header_id) {
            case TTZIP_ZIP_TAG_EXT_TIMESTAMP: { // 0x5455 ("UT")
                if (data_size >= 1) {
                    out_fields->has_extended_timestamp = true;
                    uint8_t flags = payload[0];
                    out_fields->timestamp_flags = flags;
                    size_t cursor = 1;
                    if ((flags & 0x01) && cursor + 4 <= data_size) {
                        out_fields->mod_time = read_u32_le(payload + cursor);
                        cursor += 4;
                    }
                    if ((flags & 0x02) && cursor + 4 <= data_size) {
                        out_fields->acc_time = read_u32_le(payload + cursor);
                        cursor += 4;
                    }
                    if ((flags & 0x04) && cursor + 4 <= data_size) {
                        out_fields->create_time = read_u32_le(payload + cursor);
                        cursor += 4;
                    }
                }
                break;
            }

            case TTZIP_ZIP_TAG_UNICODE_PATH: { // 0x7075 ("up")
                if (data_size >= 5 && payload[0] == 1) { // Version 1
                    uint32_t expected_crc = read_u32_le(payload + 1);
                    out_fields->unicode_path_crc32 = expected_crc;
                    out_fields->unicode_path = (const char*)(payload + 5);
                    out_fields->unicode_path_len = data_size - 5;

                    if (standard_filename) {
                        uint32_t std_crc = ttzip_crc32_fast(0, (const uint8_t*)standard_filename, strlen(standard_filename));
                        out_fields->unicode_path_crc_valid = (std_crc == expected_crc);
                    } else {
                        out_fields->unicode_path_crc_valid = true;
                    }
                }
                break;
            }

            case TTZIP_ZIP_TAG_INFOZIP_UNIX: { // 0x7875 ("ux")
                if (data_size >= 4 && payload[0] == 1) { // Version 1
                    uint8_t uid_size = payload[1];
                    size_t cursor = 2;
                    if (cursor + uid_size <= data_size) {
                        if (uid_size == 2) out_fields->uid = read_u16_le(payload + cursor);
                        else if (uid_size == 4) out_fields->uid = read_u32_le(payload + cursor);
                        cursor += uid_size;
                    }
                    if (cursor < data_size) {
                        uint8_t gid_size = payload[cursor++];
                        if (cursor + gid_size <= data_size) {
                            if (gid_size == 2) out_fields->gid = read_u16_le(payload + cursor);
                            else if (gid_size == 4) out_fields->gid = read_u32_le(payload + cursor);
                        }
                    }
                    out_fields->has_posix_permissions = true;
                }
                break;
            }

            case TTZIP_ZIP_TAG_ZIP64: { // 0x0001
                out_fields->has_zip64 = true;
                size_t cursor = 0;
                if (cursor + 8 <= data_size) {
                    out_fields->uncompressed_size = read_u64_le(payload + cursor);
                    out_fields->zip64_presence_mask |= (1 << 0);
                    cursor += 8;
                }
                if (cursor + 8 <= data_size) {
                    out_fields->compressed_size = read_u64_le(payload + cursor);
                    out_fields->zip64_presence_mask |= (1 << 1);
                    cursor += 8;
                }
                if (cursor + 8 <= data_size) {
                    out_fields->relative_offset = read_u64_le(payload + cursor);
                    out_fields->zip64_presence_mask |= (1 << 2);
                    cursor += 8;
                }
                if (cursor + 4 <= data_size) {
                    out_fields->disk_number = read_u32_le(payload + cursor);
                    out_fields->zip64_presence_mask |= (1 << 3);
                    cursor += 4;
                }
                break;
            }

            case TTZIP_ZIP_TAG_WINZIP_AES: { // 0x9901 ("AE")
                if (data_size >= 7) {
                    out_fields->has_winzip_aes = true;
                    out_fields->aes_version = read_u16_le(payload);
                    out_fields->aes_vendor_id = read_u16_le(payload + 2);
                    uint8_t mode = payload[4];
                    out_fields->aes_strength = (mode == 1) ? 128 : (mode == 2 ? 192 : (mode == 3 ? 256 : 0));
                    out_fields->aes_actual_method = read_u16_le(payload + 5);
                }
                break;
            }

            default:
                break;
        }

        offset = payload_offset + data_size;
    }

    return 0;
}
