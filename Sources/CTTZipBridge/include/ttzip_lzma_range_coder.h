#ifndef TTZIP_LZMA_RANGE_CODER_H
#define TTZIP_LZMA_RANGE_CODER_H

#include <stdint.h>
#include <stddef.h>

#define TTZIP_RC_BIT_MODEL_TOTAL_BITS 11
#define TTZIP_RC_BIT_MODEL_TOTAL (1 << TTZIP_RC_BIT_MODEL_TOTAL_BITS) // 2048
#define TTZIP_RC_MOVE_BITS 5
#define TTZIP_RC_PROB_INIT (TTZIP_RC_BIT_MODEL_TOTAL >> 1) // 1024
#define TTZIP_RC_TOP_VALUE (1U << 24)

typedef struct {
    uint64_t low;
    uint32_t range;
    uint8_t  cache;
    uint32_t cache_size;
    uint8_t* out_buf;
    size_t   out_pos;
    size_t   out_capacity;
} ttzip_range_enc_t;

static inline void ttzip_rc_init(ttzip_range_enc_t* rc, uint8_t* out_buf, size_t out_capacity) {
    if (!rc) return;
    rc->low = 0;
    rc->range = 0xFFFFFFFFU;
    rc->cache = 0;
    rc->cache_size = 1;
    rc->out_buf = out_buf;
    rc->out_pos = 0;
    rc->out_capacity = out_capacity;
}

static inline void ttzip_rc_shift_low(ttzip_range_enc_t* rc) {
    if (__builtin_expect((uint32_t)rc->low < 0xFF000000U || (uint32_t)(rc->low >> 32) != 0, 1)) {
        uint8_t temp = rc->cache;
        if (__builtin_expect(rc->cache_size == 1, 1)) {
            if (__builtin_expect(rc->out_pos < rc->out_capacity, 1)) {
                rc->out_buf[rc->out_pos++] = (uint8_t)(temp + (uint8_t)(rc->low >> 32));
            }
            rc->cache_size = 0;
        } else {
            do {
                if (rc->out_pos < rc->out_capacity) {
                    rc->out_buf[rc->out_pos++] = (uint8_t)(temp + (uint8_t)(rc->low >> 32));
                }
                temp = 0xFF;
            } while (--rc->cache_size != 0);
        }
        rc->cache = (uint8_t)((uint32_t)rc->low >> 24);
    }
    rc->cache_size++;
    rc->low = ((uint32_t)rc->low) << 8;
}

static inline void ttzip_rc_flush(ttzip_range_enc_t* rc) {
    for (int i = 0; i < 5; i++) {
        ttzip_rc_shift_low(rc);
    }
}

static inline size_t ttzip_rc_get_processed_size(const ttzip_range_enc_t* rc) {
    return rc ? rc->out_pos : 0;
}

static inline void ttzip_rc_encode_bit(ttzip_range_enc_t* rc, uint16_t* prob, int bit) {
    uint32_t t = *prob;
    uint32_t new_bound = (rc->range >> TTZIP_RC_BIT_MODEL_TOTAL_BITS) * t;
    
    if (bit == 0) {
        rc->range = new_bound;
        *prob = (uint16_t)(t + ((TTZIP_RC_BIT_MODEL_TOTAL - t) >> TTZIP_RC_MOVE_BITS));
    } else {
        rc->low += new_bound;
        rc->range -= new_bound;
        *prob = (uint16_t)(t - (t >> TTZIP_RC_MOVE_BITS));
    }
    
    if (__builtin_expect(rc->range < TTZIP_RC_TOP_VALUE, 0)) {
        rc->range <<= 8;
        ttzip_rc_shift_low(rc);
    }
}

static inline void ttzip_rc_encode_direct(ttzip_range_enc_t* rc, uint32_t value, int num_bits) {
    for (int i = num_bits - 1; i >= 0; i--) {
        rc->range >>= 1;
        if (((value >> i) & 1) != 0) {
            rc->low += rc->range;
        }
        if (rc->range < TTZIP_RC_TOP_VALUE) {
            rc->range <<= 8;
            ttzip_rc_shift_low(rc);
        }
    }
}

static inline void ttzip_rc_encode_bit_tree_8(ttzip_range_enc_t* rc, uint16_t* probs, uint32_t symbol) {
    uint32_t b7 = (symbol >> 7) & 1; ttzip_rc_encode_bit(rc, &probs[1], (int)b7);
    uint32_t m2 = 2 | b7;
    uint32_t b6 = (symbol >> 6) & 1; ttzip_rc_encode_bit(rc, &probs[m2], (int)b6);
    uint32_t m3 = (m2 << 1) | b6;
    uint32_t b5 = (symbol >> 5) & 1; ttzip_rc_encode_bit(rc, &probs[m3], (int)b5);
    uint32_t m4 = (m3 << 1) | b5;
    uint32_t b4 = (symbol >> 4) & 1; ttzip_rc_encode_bit(rc, &probs[m4], (int)b4);
    uint32_t m5 = (m4 << 1) | b4;
    uint32_t b3 = (symbol >> 3) & 1; ttzip_rc_encode_bit(rc, &probs[m5], (int)b3);
    uint32_t m6 = (m5 << 1) | b3;
    uint32_t b2 = (symbol >> 2) & 1; ttzip_rc_encode_bit(rc, &probs[m6], (int)b2);
    uint32_t m7 = (m6 << 1) | b2;
    uint32_t b1 = (symbol >> 1) & 1; ttzip_rc_encode_bit(rc, &probs[m7], (int)b1);
    uint32_t m8 = (m7 << 1) | b1;
    uint32_t b0 = symbol & 1; ttzip_rc_encode_bit(rc, &probs[m8], (int)b0);
}

static inline void ttzip_rc_encode_bit_tree(ttzip_range_enc_t* rc, uint16_t* probs, int num_bits, uint32_t symbol) {
    if (num_bits == 8) {
        ttzip_rc_encode_bit_tree_8(rc, probs, symbol);
        return;
    }
    uint32_t m = 1;
    for (int i = num_bits - 1; i >= 0; i--) {
        uint32_t bit = (symbol >> i) & 1;
        ttzip_rc_encode_bit(rc, &probs[m], (int)bit);
        m = (m << 1) | bit;
    }
}

static inline void ttzip_rc_encode_reverse_bit_tree(ttzip_range_enc_t* rc, uint16_t* probs, int num_bits, uint32_t symbol) {
    uint32_t m = 1;
    for (int i = 0; i < num_bits; i++) {
        uint32_t bit = symbol & 1;
        ttzip_rc_encode_bit(rc, &probs[m], (int)bit);
        m = (m << 1) | bit;
        symbol >>= 1;
    }
}

#endif // TTZIP_LZMA_RANGE_CODER_H
