#ifndef CTTZipBridge_7zNativeDecoder_h
#define CTTZipBridge_7zNativeDecoder_h

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_7z_extract_native_parallel_c(
    const char* archive_path,
    const char* destination_dir,
    const char* password
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_7zNativeDecoder_h
