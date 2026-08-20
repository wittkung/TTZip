// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/ttzip_thread_budget.h"
#include "include/ttzip_threadpool.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#if defined(__APPLE__)
#include <sys/types.h>
#include <sys/sysctl.h>
#include <unistd.h>
#elif defined(_WIN32) || defined(_WIN64)
#include <windows.h>
#else
#include <unistd.h>
#endif

static _Atomic uint32_t g_thread_override = 0;
static ttzip_cpu_topology_t g_cached_topology = {0, 0, 0, 0};
static ttzip_once_t g_topology_once = TTZIP_ONCE_INIT;

static void ttzip_cpu_topology_detect_internal(void) {
    uint32_t total = 1;
    uint32_t p_cores = 0;
    uint32_t e_cores = 0;

#if defined(__APPLE__)
    size_t size = sizeof(total);
    if (sysctlbyname("hw.logicalcpu", &total, &size, NULL, 0) != 0 || total == 0) {
        total = 1;
    }
    
    uint32_t p = 0;
    size = sizeof(p);
    if (sysctlbyname("hw.perflevel0.logicalcpu", &p, &size, NULL, 0) == 0 && p > 0) {
        p_cores = p;
    }
    
    uint32_t e = 0;
    size = sizeof(e);
    if (sysctlbyname("hw.perflevel1.logicalcpu", &e, &size, NULL, 0) == 0 && e > 0) {
        e_cores = e;
    }
    
    if (p_cores == 0) {
        p_cores = total;
    }
#elif defined(_WIN32) || defined(_WIN64)
    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    total = (uint32_t)sysinfo.dwNumberOfProcessors;
    if (total == 0) total = 1;
    p_cores = total;
    e_cores = 0;
#else
    long nprocs = sysconf(_SC_NPROCESSORS_ONLN);
    if (nprocs > 0) {
        total = (uint32_t)nprocs;
    } else {
        total = 1;
    }
    p_cores = total;
    e_cores = 0;
#endif

    g_cached_topology.total_logical_cores = total;
    g_cached_topology.p_cores = p_cores;
    g_cached_topology.e_cores = e_cores;
    g_cached_topology.default_threads = (p_cores > 0) ? p_cores : total;
}

ttzip_cpu_topology_t ttzip_cpu_topology_detect(void) {
    ttzip_once(&g_topology_once, ttzip_cpu_topology_detect_internal);
    return g_cached_topology;
}

uint32_t ttzip_thread_budget_get(uint32_t requested_threads) {
    ttzip_cpu_topology_t topo = ttzip_cpu_topology_detect();
    uint32_t override_val = atomic_load_explicit(&g_thread_override, memory_order_relaxed);
    
    uint32_t target = (requested_threads > 0) ? requested_threads : topo.default_threads;
    if (override_val > 0 && target > override_val) {
        target = override_val;
    }
    if (target == 0) target = 1;
    if (target > 256) target = 256;
    return target;
}

void ttzip_thread_budget_set_override(uint32_t max_threads) {
    atomic_store_explicit(&g_thread_override, max_threads, memory_order_relaxed);
}
