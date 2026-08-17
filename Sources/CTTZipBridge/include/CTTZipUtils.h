#ifndef CTTZipUtils_h
#define CTTZipUtils_h

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

char* ttzip_detect_charset(const char* bytes, size_t length);
const char* ttzip_detect_encoding_fast(const uint8_t* bytes, size_t len);
uint32_t ttzip_compute_buffer_crc32(const void* buf, size_t len);
uint32_t ttzip_compute_buffer_crc32_neon(uint32_t initial_crc, const void* buf, size_t len);
uint32_t ttzip_compute_buffer_crc32_parallel(const void* buf, size_t len);
uint32_t ttzip_compute_crc32_and_memcpy_parallel(void* dst, const void* src, size_t len);
void ttzip_neon_memcpy_64b(void* dst, const void* src, size_t len);
uint32_t ttzip_compute_file_crc32(const char* file_path);
double ttzip_estimate_buffer_entropy(const void* buf, size_t len);
double ttzip_estimate_buffer_entropy_dynamic(const void* buf, size_t len);
double ttzip_estimate_file_entropy_dynamic(const char* file_path);
bool ttzip_is_ascii_fast(const void* buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif // CTTZipUtils_h
