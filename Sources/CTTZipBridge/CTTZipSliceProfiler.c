// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#include "include/CTTZipSliceProfiler.h"
#include "include/CTTZipBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mach/mach_time.h>
#include <stdatomic.h>

#define MAX_SLICES 32

typedef struct {
    char name[64];
    _Atomic uint64_t total_nsec;
    _Atomic uint32_t call_count;
} ttzip_slice_entry_t;

static ttzip_slice_entry_t g_slices[MAX_SLICES];
static atomic_int g_num_slices = 0;
static atomic_bool g_slice_enabled = false;
static mach_timebase_info_data_t g_timebase_info;

static void init_timebase(void) {
    if (g_timebase_info.denom == 0) {
        mach_timebase_info(&g_timebase_info);
    }
}

void ttzip_slice_enable(bool enable) {
    atomic_store(&g_slice_enabled, enable);
}

bool ttzip_slice_is_enabled(void) {
    return atomic_load(&g_slice_enabled);
}

void ttzip_slice_reset(void) {
    int num = atomic_load(&g_num_slices);
    for (int i = 0; i < num; i++) {
        atomic_store(&g_slices[i].total_nsec, 0);
        atomic_store(&g_slices[i].call_count, 0);
    }
    atomic_store(&g_num_slices, 0);
}

static int find_or_create_slice(const char* name) {
    int num = atomic_load(&g_num_slices);
    for (int i = 0; i < num; i++) {
        if (strcmp(g_slices[i].name, name) == 0) {
            return i;
        }
    }
    
    int idx = atomic_fetch_add(&g_num_slices, 1);
    if (idx < MAX_SLICES) {
        snprintf(g_slices[idx].name, sizeof(g_slices[idx].name), "%s", name);
        atomic_store(&g_slices[idx].total_nsec, 0);
        atomic_store(&g_slices[idx].call_count, 0);
        return idx;
    }
    return -1;
}

static _Thread_local uint64_t t_start_times[MAX_SLICES];
static _Thread_local int t_slice_indices[MAX_SLICES];
static _Thread_local int t_stack_depth = 0;

void ttzip_slice_start(const char* slice_name) {
    if (!atomic_load(&g_slice_enabled)) return;
    init_timebase();
    
    int idx = find_or_create_slice(slice_name);
    if (idx >= 0 && t_stack_depth < MAX_SLICES) {
        t_slice_indices[t_stack_depth] = idx;
        t_start_times[t_stack_depth] = mach_absolute_time();
        t_stack_depth++;
    }
}

void ttzip_slice_end(const char* slice_name) {
    if (!atomic_load(&g_slice_enabled) || t_stack_depth <= 0) return;
    uint64_t end_time = mach_absolute_time();
    
    t_stack_depth--;
    int idx = t_slice_indices[t_stack_depth];
    uint64_t start_time = t_start_times[t_stack_depth];
    
    uint64_t elapsed_ticks = end_time - start_time;
    uint64_t elapsed_nsec = elapsed_ticks * g_timebase_info.numer / g_timebase_info.denom;
    
    if (idx >= 0 && idx < MAX_SLICES) {
        atomic_fetch_add(&g_slices[idx].total_nsec, elapsed_nsec);
        atomic_fetch_add(&g_slices[idx].call_count, 1);
    }
}

void ttzip_slice_print_report(const char* pipeline_name) {
    if (!atomic_load(&g_slice_enabled)) return;
    if (getenv("TTZIP_PROFILING") == NULL) return;
    
    int num = atomic_load(&g_num_slices);
    if (num == 0) return;
    
    uint64_t grand_total_nsec = 0;
    for (int i = 0; i < num; i++) {
        grand_total_nsec += atomic_load(&g_slices[i].total_nsec);
    }
    
    ttzip_log_c(1, "\n[TTZip AOP Pipeline Slice Report] :: %s\n", pipeline_name ? pipeline_name : "General");
    ttzip_log_c(1, "========================================================================\n");
    ttzip_log_c(1, " %-35s | %-10s | %-10s | %-8s\n", "Pipeline Stage (Slice)", "Time (ms)", "Calls", "Ratio");
    ttzip_log_c(1, "------------------------------------------------------------------------\n");
    
    for (int i = 0; i < num; i++) {
        uint64_t nsec = atomic_load(&g_slices[i].total_nsec);
        uint32_t calls = atomic_load(&g_slices[i].call_count);
        double ms = (double)nsec / 1000000.0;
        double ratio = grand_total_nsec > 0 ? ((double)nsec / (double)grand_total_nsec) * 100.0 : 0.0;
        
        ttzip_log_c(1, " %-35s | %8.3f ms | %10u | %6.1f%%\n",
                g_slices[i].name, ms, calls, ratio);
    }
    ttzip_log_c(1, "========================================================================\n");
    ttzip_log_c(1, " Total Tracked Slice Time: %.3f ms\n\n", (double)grand_total_nsec / 1000000.0);
}

uint64_t ttzip_slice_now_ns(void) {
    init_timebase();
    uint64_t ticks = mach_absolute_time();
    return ticks * g_timebase_info.numer / g_timebase_info.denom;
}

const char* ttzip_slice_get_top_stage_name(void) {
    int num = atomic_load(&g_num_slices);
    if (num == 0) return "N/A";
    
    int top_idx = 0;
    uint64_t max_nsec = 0;
    for (int i = 0; i < num; i++) {
        uint64_t nsec = atomic_load(&g_slices[i].total_nsec);
        if (nsec > max_nsec) {
            max_nsec = nsec;
            top_idx = i;
        }
    }
    return g_slices[top_idx].name;
}

double ttzip_slice_get_top_stage_ratio(void) {
    int num = atomic_load(&g_num_slices);
    if (num == 0) return 0.0;
    
    uint64_t grand_total = 0;
    uint64_t max_nsec = 0;
    for (int i = 0; i < num; i++) {
        uint64_t nsec = atomic_load(&g_slices[i].total_nsec);
        grand_total += nsec;
        if (nsec > max_nsec) {
            max_nsec = nsec;
        }
    }
    return grand_total > 0 ? ((double)max_nsec / (double)grand_total) * 100.0 : 0.0;
}

double ttzip_slice_get_stage_ms(const char* name) {
    if (!name) return 0.0;
    int num = atomic_load(&g_num_slices);
    for (int i = 0; i < num; i++) {
        if (strcmp(g_slices[i].name, name) == 0) {
            return (double)atomic_load(&g_slices[i].total_nsec) / 1000000.0;
        }
    }
    return 0.0;
}
