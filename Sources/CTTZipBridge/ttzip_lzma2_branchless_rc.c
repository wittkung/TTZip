// ttzip_lzma2_branchless_rc.c
// TTZip 7Z ARM64 无分支 Range Coder 解码加速器

#include "include/ttzip_lzma2_branchless_rc.h"
#include <string.h>

void ttzip_lzma_rc_init(ttzip_lzma_rc_state_t* rc, const uint8_t* in_buf, size_t in_size) {
    if (!rc || !in_buf || in_size < 5) {
        if (rc) rc->corrupt = 1;
        return;
    }

    rc->range = 0xFFFFFFFF;
    rc->in_ptr = in_buf;
    rc->in_limit = in_buf + in_size;
    rc->corrupt = 0;

    // LZMA RC 初始加载 5 字节
    rc->code = ((uint32_t)in_buf[1] << 24) |
               ((uint32_t)in_buf[2] << 16) |
               ((uint32_t)in_buf[3] << 8) |
               ((uint32_t)in_buf[4]);
    rc->in_ptr += 5;
}

uint32_t ttzip_lzma_rc_decode_direct_bits(ttzip_lzma_rc_state_t* rc, unsigned num_bits) {
    uint32_t result = 0;
    for (unsigned i = 0; i < num_bits; i++) {
        rc->range >>= 1;
        rc->code -= rc->range;
        uint32_t t = 0 - (rc->code >> 31);
        rc->code += rc->range & t;
        result = (result << 1) | (t + 1);

        if (rc->range < 0x01000000) {
            rc->range <<= 8;
            if (rc->in_ptr < rc->in_limit) {
                rc->code = (rc->code << 8) | (*rc->in_ptr++);
            } else {
                rc->corrupt = 1;
            }
        }
    }
    return result;
}
