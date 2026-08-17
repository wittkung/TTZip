#ifndef CTTZipBridge_ZipWrite_h
#define CTTZipBridge_ZipWrite_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_create_zip_parallel_c(
    const char* output_zip_path,
    const char* const* input_paths,
    size_t input_count,
    int level,
    bool skip_mac_junk,
    const char* password
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_ZipWrite_h
