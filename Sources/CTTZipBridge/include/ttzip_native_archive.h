#ifndef TTZIP_NATIVE_ARCHIVE_H
#define TTZIP_NATIVE_ARCHIVE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    TTZIP_NATIVE_FMT_UNKNOWN = 0,
    TTZIP_NATIVE_FMT_ZIP,
    TTZIP_NATIVE_FMT_TAR,
    TTZIP_NATIVE_FMT_7Z,
    TTZIP_NATIVE_FMT_GZ,
    TTZIP_NATIVE_FMT_ZSTD,
    TTZIP_NATIVE_FMT_LZ4,
    TTZIP_NATIVE_FMT_XZ,
    TTZIP_NATIVE_FMT_BZ2
} ttzip_native_fmt_t;

ttzip_native_fmt_t ttzip_detect_format_from_header(const uint8_t* buffer, size_t len);
ttzip_native_fmt_t ttzip_detect_format_from_filename(const char* filename);

typedef void (*ttzip_native_entry_cb)(void* context, const char* path, int64_t size, bool is_dir);

int ttzip_native_inspect_archive(const char* archive_path, void* context, ttzip_native_entry_cb callback);
int ttzip_native_extract_archive(const char* archive_path, const char* dest_dir, bool skip_mac_junk, const char* password);

#ifdef __cplusplus
}
#endif

#endif // TTZIP_NATIVE_ARCHIVE_H
