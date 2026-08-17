#include "include/CTTZipCRC32Neon.h"

#include <string.h>

#if defined(__ARM_NEON) || defined(__aarch64__)
#include <arm_neon.h>
#endif

#include <libdeflate.h>

uint32_t ttzip_core_crc32_neon_single(uint32_t crc, const uint8_t* buf, size_t len) {
    if (!buf || len == 0) return crc;
    return libdeflate_crc32(crc, buf, len);
}
