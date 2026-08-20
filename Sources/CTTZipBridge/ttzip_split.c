// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_split.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct ttzip_split_writer {
    char base_path[1024];
    uint64_t max_volume_bytes;
    ttzip_split_style_t style;
    uint32_t current_volume_idx;
    uint64_t current_volume_written;
    uint64_t total_written;
    FILE *current_fp;
};

static void get_volume_path(const ttzip_split_writer_t *w, uint32_t idx, char *dst, size_t dst_cap) {
    if (w->style == TTZIP_SPLIT_ZIP) {
        snprintf(dst, dst_cap, "%s.z%02u", w->base_path, idx + 1);
    } else if (w->style == TTZIP_SPLIT_7Z) {
        snprintf(dst, dst_cap, "%s.%03u", w->base_path, idx + 1);
    } else {
        snprintf(dst, dst_cap, "%s.part%u", w->base_path, idx + 1);
    }
}

ttzip_split_writer_t *ttzip_split_writer_open(
    const char *base_path,
    uint64_t max_volume_bytes,
    ttzip_split_style_t style
) {
    if (!base_path || max_volume_bytes == 0) return NULL;

    ttzip_split_writer_t *w = (ttzip_split_writer_t *)calloc(1, sizeof(ttzip_split_writer_t));
    if (!w) return NULL;

    strncpy(w->base_path, base_path, sizeof(w->base_path) - 1);
    w->max_volume_bytes = max_volume_bytes;
    w->style = style;
    w->current_volume_idx = 0;

    char first_path[1024];
    get_volume_path(w, 0, first_path, sizeof(first_path));
    w->current_fp = fopen(first_path, "wb");
    if (!w->current_fp) {
        free(w);
        return NULL;
    }

    return w;
}

size_t ttzip_split_writer_write(
    ttzip_split_writer_t *writer,
    const void *buf,
    size_t len
) {
    if (!writer || !buf || len == 0 || !writer->current_fp) return 0;

    const uint8_t *src = (const uint8_t *)buf;
    size_t remaining = len;

    while (remaining > 0) {
        uint64_t room = writer->max_volume_bytes > writer->current_volume_written ?
            (writer->max_volume_bytes - writer->current_volume_written) : 0;

        if (room == 0) {
            /* Rotate to next volume */
            fclose(writer->current_fp);
            writer->current_volume_idx++;
            writer->current_volume_written = 0;

            char next_path[1024];
            get_volume_path(writer, writer->current_volume_idx, next_path, sizeof(next_path));
            writer->current_fp = fopen(next_path, "wb");
            if (!writer->current_fp) {
                return len - remaining;
            }
            room = writer->max_volume_bytes;
        }

        size_t chunk = (remaining < room) ? remaining : (size_t)room;
        size_t written = fwrite(src, 1, chunk, writer->current_fp);
        if (written == 0) break;

        writer->current_volume_written += written;
        writer->total_written += written;
        src += written;
        remaining -= written;
    }

    return len - remaining;
}

int ttzip_split_writer_close(ttzip_split_writer_t *writer) {
    if (!writer) return -1;
    int res = 0;
    if (writer->current_fp) {
        res = fclose(writer->current_fp);
        writer->current_fp = NULL;
    }
    free(writer);
    return res;
}
