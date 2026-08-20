// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_mem_budget.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__)
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#elif defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#else
#include <sys/sysinfo.h>
#include <unistd.h>
#endif

static _Atomic uint64_t g_mem_override = 0;

ttzip_mem_budget_t ttzip_mem_budget_query(void) {
    ttzip_mem_budget_t b;
    memset(&b, 0, sizeof(b));

#if defined(__APPLE__)
    uint64_t memsize = 0;
    size_t size = sizeof(memsize);
    if (sysctlbyname("hw.memsize", &memsize, &size, NULL, 0) == 0 && memsize > 0) {
        b.total_physical_ram = memsize;
    } else {
        b.total_physical_ram = 8ULL * 1024 * 1024 * 1024; // 8GB default fallback
    }

    vm_size_t page_size = 4096;
    mach_port_t mach_port = mach_host_self();
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_page_size(mach_port, &page_size) == KERN_SUCCESS &&
        host_statistics64(mach_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &count) == KERN_SUCCESS) {
        uint64_t free_pages = vm_stat.free_count + vm_stat.inactive_count;
        b.available_physical_ram = free_pages * (uint64_t)page_size;
    } else {
        b.available_physical_ram = b.total_physical_ram / 2;
    }
#elif defined(_WIN32) || defined(_WIN64)
    MEMORYSTATUSEX statex;
    statex.dwLength = sizeof(statex);
    if (GlobalMemoryStatusEx(&statex)) {
        b.total_physical_ram = statex.ullTotalPhys;
        b.available_physical_ram = statex.ullAvailPhys;
    } else {
        b.total_physical_ram = 8ULL * 1024 * 1024 * 1024;
        b.available_physical_ram = 4ULL * 1024 * 1024 * 1024;
    }
#else
    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        b.total_physical_ram = (uint64_t)info.totalram * info.mem_unit;
        b.available_physical_ram = (uint64_t)info.freeram * info.mem_unit;
    } else {
        b.total_physical_ram = 8ULL * 1024 * 1024 * 1024;
        b.available_physical_ram = 4ULL * 1024 * 1024 * 1024;
    }
#endif

    // Safe budget is 75% of available physical RAM or 50% of total RAM, capped appropriately
    uint64_t safe_by_avail = (b.available_physical_ram * 3) / 4;
    uint64_t safe_by_total = b.total_physical_ram / 2;
    b.safe_budget_bytes = (safe_by_avail < safe_by_total && safe_by_avail > 0) ? safe_by_avail : safe_by_total;

    uint64_t override_val = atomic_load_explicit(&g_mem_override, memory_order_relaxed);
    if (override_val > 0) {
        b.safe_budget_bytes = override_val;
    }

    return b;
}

uint64_t ttzip_mem_budget_clamp(uint64_t desired_bytes, uint64_t min_bytes, uint64_t max_bytes) {
    ttzip_mem_budget_t b = ttzip_mem_budget_query();
    uint64_t target = desired_bytes;
    if (target > b.safe_budget_bytes) {
        target = b.safe_budget_bytes;
    }
    if (max_bytes > 0 && target > max_bytes) {
        target = max_bytes;
    }
    if (target < min_bytes) {
        target = min_bytes;
    }
    return target;
}

void ttzip_mem_budget_set_override(uint64_t max_budget_bytes) {
    atomic_store_explicit(&g_mem_override, max_budget_bytes, memory_order_relaxed);
}
