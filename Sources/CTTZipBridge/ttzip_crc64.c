/**
 * @file ttzip_crc64.c
 * @brief ARM64 PMULL 硬件加速与标量回退 CRC64 (ECMA-182 / XZ) 校验引擎实现
 * @details 基于 ARMv8-A vmull_p64 无进位乘法实现 4 路 64 字节向量折叠与 Barrett 模约化。
 *          完全对齐 7Z/XZ 归档规范与 lzma_crc64 黄金标准（生成多项式 0xC96C5795D7870F42ULL，反转进出）。
 * @version 1.0
 * @author TTZip Core Engineering Team
 */

#include "include/ttzip_crc64.h"
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>

__attribute__((aligned(64)))
static const uint8_t vmasks_64[64] = {
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
	0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
};

static inline uint8x16_t clmul_00(uint8x16_t a, uint8x16_t b) {
	return (uint8x16_t)vmull_p64((poly64_t)vgetq_lane_u64(vreinterpretq_u64_u8(a), 0),
			(poly64_t)vgetq_lane_u64(vreinterpretq_u64_u8(b), 0));
}

static inline uint8x16_t clmul_10(uint8x16_t a, uint8x16_t b) {
	return (uint8x16_t)vmull_p64((poly64_t)vgetq_lane_u64(vreinterpretq_u64_u8(a), 0),
			(poly64_t)vgetq_lane_u64(vreinterpretq_u64_u8(b), 1));
}

static inline uint8x16_t clmul_11(uint8x16_t a, uint8x16_t b) {
	return (uint8x16_t)vmull_p64((poly64_t)vgetq_lane_u64(vreinterpretq_u64_u8(a), 1),
			(poly64_t)vgetq_lane_u64(vreinterpretq_u64_u8(b), 1));
}

static inline uint8x16_t fold(uint8x16_t v, uint8x16_t fold_const) {
	return veorq_u8(clmul_00(v, fold_const), clmul_11(v, fold_const));
}

__attribute__((flatten))
uint64_t ttzip_crc64_pmull(const uint8_t *buf, size_t size, uint64_t crc) {
	if (size == 0 || !buf) return crc;

	const uint8x16_t fold512 = (uint8x16_t)vcombine_u64(vcreate_u64(0x6ae3efbb9dd441f3ULL), vcreate_u64(0x081f6054a7842df4ULL));
	const uint8x16_t fold128 = (uint8x16_t)vcombine_u64(vcreate_u64(0xe05dd497ca393ae4ULL), vcreate_u64(0xdabe95afc7875f40ULL));
	const uint8x16_t mu_p = (uint8x16_t)vcombine_u64(vcreate_u64(0x92d8af2baf0e1e84ULL), vcreate_u64(0x9c3e466c172963d5ULL));

	uint8x16_t v0, v1, v2, v3;
	crc = ~crc;

	if (size < 8) {
		uint64_t x = crc;
		size_t i = 0;
		if (size & 4) { uint32_t t; memcpy(&t, buf, 4); x ^= t; buf += 4; i = 32; }
		if (size & 2) { uint16_t t; memcpy(&t, buf, 2); x ^= (uint64_t)t << i; buf += 2; i += 16; }
		if (size & 1) { x ^= (uint64_t)*buf << i; }
		v0 = (uint8x16_t)vsetq_lane_u64(x, vdupq_n_u64(0), 0);
		v0 = vqtbl1q_u8(v0, vld1q_u8(vmasks_64 + 32 - (8 - size)));
	} else if (size < 16) {
		uint64_t t; memcpy(&t, buf, 8);
		v0 = (uint8x16_t)vsetq_lane_u64(crc ^ t, vdupq_n_u64(0), 0);
		size -= 8;
		if (size > 0) {
			const size_t padding = 8 - size;
			uint64_t high; memcpy(&high, buf + size, 8); high >>= (padding * 8);
			v0 = (uint8x16_t)vsetq_lane_u64(high, vreinterpretq_u64_u8(v0), 1);
			v0 = vqtbl1q_u8(v0, vld1q_u8(vmasks_64 + 32 - padding));
			v1 = vextq_u8(v0, vdupq_n_u8(0), 8);
			v0 = clmul_10(v0, fold128);
			v0 = veorq_u8(v0, v1);
		}
	} else {
		v0 = (uint8x16_t)vsetq_lane_u64(crc, vdupq_n_u64(0), 0);
		v0 = veorq_u8(v0, vld1q_u8(buf));
		buf += 16; size -= 16;

		if (size >= 48) {
			v1 = vld1q_u8(buf); v2 = vld1q_u8(buf + 16); v3 = vld1q_u8(buf + 32);
			buf += 48; size -= 48;
			while (size >= 64) {
				v0 = veorq_u8(fold(v0, fold512), vld1q_u8(buf));
				v1 = veorq_u8(fold(v1, fold512), vld1q_u8(buf + 16));
				v2 = veorq_u8(fold(v2, fold512), vld1q_u8(buf + 32));
				v3 = veorq_u8(fold(v3, fold512), vld1q_u8(buf + 48));
				buf += 64; size -= 64;
			}
			v0 = veorq_u8(v1, fold(v0, fold128));
			v0 = veorq_u8(v2, fold(v0, fold128));
			v0 = veorq_u8(v3, fold(v0, fold128));
		}

		while (size >= 16) {
			v0 = veorq_u8(fold(v0, fold128), vld1q_u8(buf));
			buf += 16; size -= 16;
		}

		if (size > 0) {
			v1 = vld1q_u8(buf + size - 16);
			v1 = vandq_u8(v1, vld1q_u8(vmasks_64 + size));
			v1 = vorrq_u8(v1, vqtbl1q_u8(v0, vld1q_u8(vmasks_64 + 32 + size)));
			v0 = vqtbl1q_u8(v0, vld1q_u8(vmasks_64 + 32 - (16 - size)));
			v0 = veorq_u8(v1, fold(v0, fold128));
		}

		v1 = vextq_u8(v0, vdupq_n_u8(0), 8);
		v0 = clmul_10(v0, fold128);
		v0 = veorq_u8(v0, v1);
	}

	// Barrett Reduction
	v1 = clmul_10(v0, mu_p);
	v2 = vextq_u8(vdupq_n_u8(0), v1, 8);
	v1 = clmul_00(v1, mu_p);
	v0 = veorq_u8(v0, v2);
	v0 = veorq_u8(v0, v1);

	return ~vgetq_lane_u64(vreinterpretq_u64_u8(v0), 1);
}
#else
uint64_t ttzip_crc64_pmull(const uint8_t *buf, size_t size, uint64_t crc) {
	return ttzip_crc64_scalar(buf, size, crc);
}
#endif

uint64_t ttzip_crc64_scalar(const uint8_t *buf, size_t size, uint64_t crc) {
	if (size == 0 || !buf) return crc;
	crc = ~crc;

	static uint64_t table[256];
	static bool table_initialized = false;
	if (!table_initialized) {
		for (uint32_t i = 0; i < 256; i++) {
			uint64_t c = (uint64_t)i;
			for (int j = 0; j < 8; j++) {
				if (c & 1) {
					c = (c >> 1) ^ 0xC96C5795D7870F42ULL;
				} else {
					c >>= 1;
				}
			}
			table[i] = c;
		}
		table_initialized = true;
	}

	for (size_t i = 0; i < size; i++) {
		crc = table[(crc ^ buf[i]) & 0xFF] ^ (crc >> 8);
	}

	return ~crc;
}

uint64_t ttzip_crc64(const uint8_t *buf, size_t size, uint64_t crc) {
#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
	return ttzip_crc64_pmull(buf, size, crc);
#else
	return ttzip_crc64_scalar(buf, size, crc);
#endif
}
