#ifndef CTTZIP_7Z_STORE_INTERNAL_H
#define CTTZIP_7Z_STORE_INTERNAL_H

#include "CTTZipBridge_7zStore.h"
#include "CTTZipCommon.h"
#include "CTTZipIO.h"
#include "CTTZipSIMD.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

typedef ttzip_io_entry_t ttzip_7z_store_entry_t;
typedef ttzip_io_file_list_t ttzip_7z_store_list_t;

#define ttzip_7z_collect_recursive ttzip_io_collect_recursive
#define ttzip_7z_write_varint ttzip_varint_write_u64
#define ttzip_7z_write_all ttzip_io_write_all

#endif
