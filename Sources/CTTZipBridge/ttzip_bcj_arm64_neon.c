// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_bcj_arm64_neon.c
 * @brief ARM64 NEON vectorized BCJ executable branch target converter.
 */

#include "include/ttzip_bcj_arm64_neon.h"
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

size_t ttzip_arm64_bcj_encode_neon(uint8_t* data, size_t size, uint32_t ip) {
    if (!data || size < 4) return 0;
    
    size_t i = 0;
    const size_t limit = size - 4;

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    const uint32x4_t mask_op = vdupq_n_u32(0x7C000000);
    const uint32x4_t pattern_b = vdupq_n_u32(0x14000000);
    
    while (i + 16 <= size) {
        uint32x4_t v = vld1q_u32((const uint32_t*)(data + i));
        uint32x4_t match = vceqq_u32(vandq_u32(v, mask_op), pattern_b);
        
        // If none of the 4 instructions are B/BL jumps, skip 16 bytes
        if (vmaxvq_u32(match) == 0) {
            i += 16;
            continue;
        }
        
        for (int lane = 0; lane < 4; lane++) {
            size_t pos = i + lane * 4;
            uint32_t instr;
            memcpy(&instr, data + pos, 4);
            if ((instr & 0x7C000000) == 0x14000000) {
                uint32_t curr_ip = ip + (uint32_t)pos;
                uint32_t imm26 = instr & 0x03FFFFFF;
                int32_t signed_offset = (imm26 & 0x02000000) ? (int32_t)(imm26 | 0xFC000000) : (int32_t)imm26;
                uint32_t abs_target = curr_ip + (uint32_t)(signed_offset << 2);
                uint32_t new_imm26 = (abs_target >> 2) & 0x03FFFFFF;
                instr = (instr & 0xFC000000) | new_imm26;
                memcpy(data + pos, &instr, 4);
            }
        }
        i += 16;
    }
#endif

    while (i <= limit) {
        uint32_t instr;
        memcpy(&instr, data + i, 4);
        if ((instr & 0x7C000000) == 0x14000000) {
            uint32_t curr_ip = ip + (uint32_t)i;
            uint32_t imm26 = instr & 0x03FFFFFF;
            int32_t signed_offset = (imm26 & 0x02000000) ? (int32_t)(imm26 | 0xFC000000) : (int32_t)imm26;
            uint32_t abs_target = curr_ip + (uint32_t)(signed_offset << 2);
            uint32_t new_imm26 = (abs_target >> 2) & 0x03FFFFFF;
            instr = (instr & 0xFC000000) | new_imm26;
            memcpy(data + i, &instr, 4);
        }
        i += 4;
    }

    return i;
}

size_t ttzip_arm64_bcj_decode_neon(uint8_t* data, size_t size, uint32_t ip) {
    if (!data || size < 4) return 0;
    
    size_t i = 0;
    const size_t limit = size - 4;

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    const uint32x4_t mask_op = vdupq_n_u32(0x7C000000);
    const uint32x4_t pattern_b = vdupq_n_u32(0x14000000);
    
    while (i + 16 <= size) {
        uint32x4_t v = vld1q_u32((const uint32_t*)(data + i));
        uint32x4_t match = vceqq_u32(vandq_u32(v, mask_op), pattern_b);
        
        if (vmaxvq_u32(match) == 0) {
            i += 16;
            continue;
        }
        
        for (int lane = 0; lane < 4; lane++) {
            size_t pos = i + lane * 4;
            uint32_t instr;
            memcpy(&instr, data + pos, 4);
            if ((instr & 0x7C000000) == 0x14000000) {
                uint32_t curr_ip = ip + (uint32_t)pos;
                uint32_t abs_target = (instr & 0x03FFFFFF) << 2;
                int32_t rel_offset = (int32_t)(abs_target - curr_ip) >> 2;
                uint32_t imm26 = ((uint32_t)rel_offset) & 0x03FFFFFF;
                instr = (instr & 0xFC000000) | imm26;
                memcpy(data + pos, &instr, 4);
            }
        }
        i += 16;
    }
#endif

    while (i <= limit) {
        uint32_t instr;
        memcpy(&instr, data + i, 4);
        if ((instr & 0x7C000000) == 0x14000000) {
            uint32_t curr_ip = ip + (uint32_t)i;
            uint32_t abs_target = (instr & 0x03FFFFFF) << 2;
            int32_t rel_offset = (int32_t)(abs_target - curr_ip) >> 2;
            uint32_t imm26 = ((uint32_t)rel_offset) & 0x03FFFFFF;
            instr = (instr & 0xFC000000) | imm26;
            memcpy(data + i, &instr, 4);
        }
        i += 4;
    }

    return i;
}
