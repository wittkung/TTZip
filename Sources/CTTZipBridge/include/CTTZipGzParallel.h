#ifndef CTTZIP_GZ_PARALLEL_H
#define CTTZIP_GZ_PARALLEL_H

#include <stddef.h>
#include <stdbool.h>
#include <sys/types.h>

typedef struct parallel_gz_ctx parallel_gz_ctx;

parallel_gz_ctx* init_parallel_gz(const char* path, int level);
parallel_gz_ctx* init_parallel_bz2(const char* path, int level);
parallel_gz_ctx* init_parallel_lz4(const char* path, int level);
parallel_gz_ctx* init_parallel_xz(const char* path, int level);
ssize_t ttzip_archive_gz_write_cb(void *a, void *client_data, const void *buffer, size_t length);
int ttzip_archive_gz_close_cb(void *a, void *client_data);

int ttzip_compress_gz_parallel(const char* src_path, const char* dst_path, int level);

#endif
