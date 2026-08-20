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
static ttzip_cpu_topology_t g_cached_topology = {0};
static ttzip_once_t g_topology_once = TTZIP_ONCE_INIT;

static void ttzip_cpu_topology_detect_internal(void) {
    uint32_t total = 1;
    uint32_t p_cores = 0;
    uint32_t e_cores = 0;
    uint32_t nperflevels = 1;
    uint64_t p_l2 = 0;
    uint32_t p_cpus_per_l2 = 0;
    uint64_t p_l1d = 0;
    uint64_t e_l2 = 0;
    uint32_t e_cpus_per_l2 = 0;
    uint64_t e_l1d = 0;
    uint32_t cachelinesize = 64;

#if defined(__APPLE__)
    size_t size = sizeof(total);
    if (sysctlbyname("hw.logicalcpu", &total, &size, NULL, 0) != 0 || total == 0) {
        total = 1;
    }
    
    uint32_t nlevels = 1;
    size = sizeof(nlevels);
    if (sysctlbyname("hw.nperflevels", &nlevels, &size, NULL, 0) == 0 && nlevels > 0) {
        nperflevels = nlevels;
    }
    
    uint32_t p = 0;
    size = sizeof(p);
    if (sysctlbyname("hw.perflevel0.logicalcpu", &p, &size, NULL, 0) == 0 && p > 0) {
        p_cores = p;
    }
    
    uint64_t pl2 = 0;
    size = sizeof(pl2);
    if (sysctlbyname("hw.perflevel0.l2cachesize", &pl2, &size, NULL, 0) == 0 && pl2 > 0) {
        p_l2 = pl2;
    }
    
    uint32_t p_cpl2 = 0;
    size = sizeof(p_cpl2);
    if (sysctlbyname("hw.perflevel0.cpusperl2", &p_cpl2, &size, NULL, 0) == 0 && p_cpl2 > 0) {
        p_cpus_per_l2 = p_cpl2;
    }
    
    uint64_t pl1d = 0;
    size = sizeof(pl1d);
    if (sysctlbyname("hw.perflevel0.l1dcachesize", &pl1d, &size, NULL, 0) == 0 && pl1d > 0) {
        p_l1d = pl1d;
    }

    uint32_t e = 0;
    size = sizeof(e);
    if (sysctlbyname("hw.perflevel1.logicalcpu", &e, &size, NULL, 0) == 0 && e > 0) {
        e_cores = e;
    }
    
    uint64_t el2 = 0;
    size = sizeof(el2);
    if (sysctlbyname("hw.perflevel1.l2cachesize", &el2, &size, NULL, 0) == 0 && el2 > 0) {
        e_l2 = el2;
    }
    
    uint32_t e_cpl2 = 0;
    size = sizeof(e_cpl2);
    if (sysctlbyname("hw.perflevel1.cpusperl2", &e_cpl2, &size, NULL, 0) == 0 && e_cpl2 > 0) {
        e_cpus_per_l2 = e_cpl2;
    }
    
    uint64_t el1d = 0;
    size = sizeof(el1d);
    if (sysctlbyname("hw.perflevel1.l1dcachesize", &el1d, &size, NULL, 0) == 0 && el1d > 0) {
        e_l1d = el1d;
    }

    uint32_t cls = 0;
    size = sizeof(cls);
    if (sysctlbyname("hw.cachelinesize", &cls, &size, NULL, 0) == 0 && cls > 0) {
        cachelinesize = cls;
    } else {
        cachelinesize = 128;
    }

    if (p_cores == 0) {
        p_cores = total;
    }
    if (p_l2 == 0) {
        uint64_t l2 = 0;
        size = sizeof(l2);
        if (sysctlbyname("hw.l2cachesize", &l2, &size, NULL, 0) == 0 && l2 > 0) {
            p_l2 = l2;
        } else {
            p_l2 = 16ULL * 1024ULL * 1024ULL;
        }
    }
    if (p_cpus_per_l2 == 0) p_cpus_per_l2 = p_cores;
#elif defined(_WIN32) || defined(_WIN64)
    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    total = (uint32_t)sysinfo.dwNumberOfProcessors;
    if (total == 0) total = 1;
    p_cores = total;
    e_cores = 0;
    nperflevels = 1;
    p_l2 = 1024ULL * 1024ULL;
    p_cpus_per_l2 = total;
    cachelinesize = 64;
#else
    long nprocs = sysconf(_SC_NPROCESSORS_ONLN);
    if (nprocs > 0) {
        total = (uint32_t)nprocs;
    } else {
        total = 1;
    }
    p_cores = total;
    e_cores = 0;
    nperflevels = 1;
    p_l2 = 1024ULL * 1024ULL;
    p_cpus_per_l2 = total;
    cachelinesize = 64;
#endif

    g_cached_topology.total_logical_cores = total;
    g_cached_topology.p_cores = p_cores;
    g_cached_topology.e_cores = e_cores;
    g_cached_topology.default_threads = (p_cores > 0) ? p_cores : total;
    g_cached_topology.nperflevels = nperflevels;
    g_cached_topology.p_l2_cache_bytes = p_l2;
    g_cached_topology.p_cpus_per_l2 = p_cpus_per_l2;
    g_cached_topology.p_l1d_cache_bytes = p_l1d;
    g_cached_topology.e_l2_cache_bytes = e_l2;
    g_cached_topology.e_cpus_per_l2 = e_cpus_per_l2;
    g_cached_topology.e_l1d_cache_bytes = e_l1d;
    g_cached_topology.cacheline_bytes = cachelinesize;
}

ttzip_cpu_topology_t ttzip_cpu_topology_detect(void) {
    ttzip_once(&g_topology_once, ttzip_cpu_topology_detect_internal);
    return g_cached_topology;
}

size_t ttzip_compute_optimal_chunk_size(bool is_p_core, size_t file_size) {
    ttzip_cpu_topology_t topo = ttzip_cpu_topology_detect();
    size_t chunk_size;
    if (is_p_core) {
        uint64_t l2 = topo.p_l2_cache_bytes > 0 ? topo.p_l2_cache_bytes : (16ULL * 1024ULL * 1024ULL);
        uint32_t cpus = topo.p_cpus_per_l2 > 0 ? topo.p_cpus_per_l2 : (topo.p_cores > 0 ? topo.p_cores : 1);
        chunk_size = (size_t)(l2 / cpus);
        if (chunk_size < 256 * 1024) chunk_size = 256 * 1024;
        if (chunk_size > 4 * 1024 * 1024) chunk_size = 4 * 1024 * 1024;
    } else {
        uint64_t l2 = topo.e_l2_cache_bytes > 0 ? topo.e_l2_cache_bytes : (4ULL * 1024ULL * 1024ULL);
        uint32_t cpus = topo.e_cpus_per_l2 > 0 ? topo.e_cpus_per_l2 : (topo.e_cores > 0 ? topo.e_cores : 1);
        chunk_size = (size_t)(l2 / cpus);
        if (chunk_size < 64 * 1024) chunk_size = 64 * 1024;
        if (chunk_size > 1024 * 1024) chunk_size = 1024 * 1024;
    }
    
    // Align to 128-byte cacheline
    chunk_size = (chunk_size + 127) & ~((size_t)127);
    if (file_size > 0 && chunk_size > file_size) {
        chunk_size = (file_size + 127) & ~((size_t)127);
    }
    return chunk_size;
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
