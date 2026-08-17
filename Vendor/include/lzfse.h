/*
 * Apple LZFSE Header Interface
 * Native C acceleration bridge for Antigravity TTZip Engine
 */

#ifndef LZFSE_H
#define LZFSE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

size_t lzfse_encode_scratch_size(void);
size_t lzfse_encode_buffer(uint8_t *dst_buffer, size_t dst_size,
                            const uint8_t *src_buffer, size_t src_size,
                            void *scratch_buffer);

size_t lzfse_decode_scratch_size(void);
size_t lzfse_decode_buffer(uint8_t *dst_buffer, size_t dst_size,
                            const uint8_t *src_buffer, size_t src_size,
                            void *scratch_buffer);

#ifdef __cplusplus
}
#endif

#endif /* LZFSE_H */
