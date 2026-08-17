#ifndef CTTZIP_BRIDGE_PIPES_H
#define CTTZIP_BRIDGE_PIPES_H

#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

int ttzip_compress_tar_pbzip2(const char* tar_bin, const char* pbzip2_bin, const char* input_dir, const char* output_path, int level, int cores);
int ttzip_compress_tar_pixz(const char* tar_bin, const char* pixz_bin, const char* input_dir, const char* output_path, int level, int cores);
int ttzip_decompress_tar_pixz(const char* pixz_bin, const char* tar_bin, const char* archive_path, const char* dest_dir, int cores);
int ttzip_compress_tar_plzip(const char* tar_bin, const char* plzip_bin, const char* input_dir, const char* output_path, int level, int cores);
int ttzip_compress_plzip(const char* plzip_bin, const char* input_path, const char* output_path, int level, int cores);
int ttzip_decompress_tar_plzip(const char* plzip_bin, const char* tar_bin, const char* archive_path, const char* dest_dir, int cores);
int ttzip_decompress_plzip(const char* plzip_bin, const char* archive_path, const char* output_path, int cores);

#ifdef __cplusplus
}
#endif

#endif /* CTTZIP_BRIDGE_PIPES_H */
