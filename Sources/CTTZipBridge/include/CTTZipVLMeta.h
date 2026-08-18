// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#ifndef CTTZipVLMeta_h
#define CTTZipVLMeta_h

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TTZIP_VLMETA_MAGIC "TTZIPVLM"
#define TTZIP_VLMETA_VERSION 1

typedef struct {
    char name[64];           // Layer name (e.g. "quicklook_thumb", "search_index")
    const uint8_t* payload;  // Raw uncompressed metadata payload
    size_t payload_size;     // Size in bytes
} ttzip_vlmeta_entry_t;

/**
 * @brief Appends a self-compressed VLMeta trailer to an existing archive file at EOF.
 * Operates in O(1) time without rewriting or modifying pre-existing file payload.
 */
int ttzip_vlmeta_append_trailer(
    const char* archive_path,
    const ttzip_vlmeta_entry_t* entries,
    size_t entry_count
);

/**
 * @brief Probes and extracts a specific VLMeta layer by name from an archive trailer.
 */
int ttzip_vlmeta_read_layer(
    const char* archive_path,
    const char* layer_name,
    uint8_t** out_payload,
    size_t* out_size
);

/**
 * @brief Frees payload allocated by ttzip_vlmeta_read_layer.
 */
void ttzip_vlmeta_free_payload(uint8_t* payload);

#ifdef __cplusplus
}
#endif

#endif // CTTZipVLMeta_h
