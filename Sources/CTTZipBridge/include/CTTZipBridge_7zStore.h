#ifndef CTTZipBridge_7zStore_h
#define CTTZipBridge_7zStore_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_create_7z_store_fast_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count
);

int ttzip_create_7z_solid_fast_c(
    const char* output_path,
    const char* const* input_paths,
    size_t input_count,
    int level
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_7zStore_h
