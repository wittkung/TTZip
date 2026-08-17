#ifndef CTTZipBridge_7zParallel_h
#define CTTZipBridge_7zParallel_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_7z_extract_parallel_c(
    const char* archive_path,
    const char* destination_dir,
    const char* password
);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_7zParallel_h
