#ifndef CTTZipBridge_Mmap_h
#define CTTZipBridge_Mmap_h

#include "CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_mmap_zip_inspect(const char* archive_path, void* context, ttzip_entry_callback callback);

#ifdef __cplusplus
}
#endif

#endif // CTTZipBridge_Mmap_h
