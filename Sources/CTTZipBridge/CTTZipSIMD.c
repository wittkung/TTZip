#include "include/CTTZipSIMD.h"
#include <libdeflate.h>

uint32_t ttzip_simd_crc32(uint32_t crc, const void* buf, size_t len) {
    if (!buf || len == 0) return crc;
    return libdeflate_crc32(crc, buf, len);
}

size_t ttzip_varint_write_u64(uint8_t* dst, uint64_t value) {
    if (!dst) return 0;
    if (value < 0x80) {
        dst[0] = (uint8_t)value;
        return 1;
    }
    uint8_t mask = 0x80;
    size_t extra = 0;
    for (int i = 1; i <= 8; i++) {
        if (value < (1ULL << (7 * i))) {
            extra = (size_t)i;
            break;
        }
        mask |= (0x80 >> i);
    }
    if (extra == 0) extra = 8;
    dst[0] = mask | (uint8_t)(value >> (extra * 8));
    for (size_t i = 0; i < extra; i++) {
        dst[1 + i] = (uint8_t)(value >> (i * 8));
    }
    return 1 + extra;
}
