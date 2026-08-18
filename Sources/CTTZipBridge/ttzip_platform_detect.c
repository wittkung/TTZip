// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

/**
 * @file ttzip_platform_detect.c
 * @brief Dynamic CPU instruction set and hardware capability detection routines.
 */

#include "include/CTTZipStreamCoder.h"
#include "include/CTTZipPlatform.h"
#include <string.h>

#if defined(__APPLE__)
#include <sys/types.h>
#include <sys/sysctl.h>
#elif defined(_WIN32)
#include <windows.h>
#include <intrin.h>
#endif

ttzip_hardware_capabilities_t ttzip_detect_cpu_features(void) {
    ttzip_hardware_capabilities_t caps;
    memset(&caps, 0, sizeof(caps));

#if defined(__APPLE__)
    #if defined(__aarch64__) || defined(__arm64__)
    caps.has_arm_neon = true;
    int val = 0;
    size_t size = sizeof(val);
    if (sysctlbyname("hw.optional.arm.FEAT_CRC32", &val, &size, NULL, 0) == 0 && val != 0) {
        caps.has_arm_crc32 = true;
    } else {
        caps.has_arm_crc32 = true; // All Apple Silicon M1/M2/M3/M4 have hardware CRC32
    }
    #elif defined(__x86_64__)
    int val = 0;
    size_t size = sizeof(val);
    if (sysctlbyname("hw.optional.avx2_0", &val, &size, NULL, 0) == 0 && val != 0) {
        caps.has_x86_avx2 = true;
    }
    if (sysctlbyname("hw.optional.avx512f", &val, &size, NULL, 0) == 0 && val != 0) {
        caps.has_x86_avx512 = true;
    }
    #endif

#elif defined(_WIN32)
    #if defined(_M_ARM64)
    caps.has_arm_neon = true;
    if (IsProcessorFeaturePresent(PF_ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE)) {
        caps.has_arm_crc32 = true;
    }
    #elif defined(_M_X64)
    int cpu_info[4];
    __cpuid(cpu_info, 1);
    if ((cpu_info[2] & (1 << 1)) != 0) { // PCLMULQDQ
        caps.has_x86_vpclmul = true;
    }
    __cpuidex(cpu_info, 7, 0);
    if ((cpu_info[1] & (1 << 5)) != 0) { // AVX2
        caps.has_x86_avx2 = true;
    }
    if ((cpu_info[1] & (1 << 16)) != 0) { // AVX-512F
        caps.has_x86_avx512 = true;
    }
    #endif

#else // Linux / Generic POSIX
    #if defined(__aarch64__) || defined(__arm64__)
    caps.has_arm_neon = true;
    caps.has_arm_crc32 = true;
    #elif defined(__x86_64__)
    #if defined(__AVX2__)
    caps.has_x86_avx2 = true;
    #endif
    #if defined(__AVX512F__)
    caps.has_x86_avx512 = true;
    #endif
    #endif
#endif

    return caps;
}
