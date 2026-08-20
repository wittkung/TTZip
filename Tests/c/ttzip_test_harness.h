/**
 * @file ttzip_test_harness.h
 * @brief Zero-dependency, zero-heap-allocation C11 unit testing framework for TTZip.
 * @version 1.0.0
 * 
 * SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
 * Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>. All rights reserved.
 */

#ifndef TTZIP_TEST_HARNESS_H
#define TTZIP_TEST_HARNESS_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <inttypes.h>
#include <stdarg.h>

#if defined(_WIN32)
  #define WIN32_LEAN_AND_MEAN
  #include <windows.h>
  #include <io.h>
  #define ttzip_isatty(fd) _isatty(fd)
#elif defined(__APPLE__)
  #include <unistd.h>
  #include <mach/mach_time.h>
  #define ttzip_isatty(fd) isatty(fd)
#elif defined(__linux__) || defined(__unix__) || defined(__posix__)
  #include <unistd.h>
  #include <time.h>
  #define ttzip_isatty(fd) isatty(fd)
#else
  #include <time.h>
  #define ttzip_isatty(fd) 0
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * 1. Data Structures & Test Context
 * ============================================================================ */

typedef struct {
    const char* name;
    bool passed;
    bool skipped;
    uint64_t duration_nanos;
    size_t assert_count;
    char fail_expr[256];
    char fail_msg[512];
    const char* fail_file;
    int fail_line;
} ttzip_test_case_t;

typedef struct {
    const char* suite_name;
    size_t total_tests;
    size_t passed_tests;
    size_t failed_tests;
    size_t skipped_tests;
    size_t total_assertions;
    uint64_t total_duration_nanos;
    bool color_enabled;
    ttzip_test_case_t current_case;
} ttzip_test_ctx_t;

static inline ttzip_test_ctx_t* ttzip_test_get_global_ctx(void) {
    static ttzip_test_ctx_t ctx;
    return &ctx;
}

/* ============================================================================
 * 2. Hardware Monotonic Timestamp Engine
 * ============================================================================ */

static inline uint64_t ttzip_test_monotonic_nanos(void) {
#if defined(__APPLE__)
    static mach_timebase_info_data_t tb;
    if (tb.denom == 0) {
        mach_timebase_info(&tb);
    }
    return (mach_absolute_time() * (uint64_t)tb.numer) / (uint64_t)tb.denom;
#elif defined(_WIN32)
    static LARGE_INTEGER freq;
    if (freq.QuadPart == 0) {
        QueryPerformanceFrequency(&freq);
    }
    LARGE_INTEGER counter;
    QueryPerformanceCounter(&counter);
    return (uint64_t)((counter.QuadPart * 1000000000ULL) / freq.QuadPart);
#elif defined(CLOCK_MONOTONIC)
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ((uint64_t)ts.tv_sec * 1000000000ULL) + (uint64_t)ts.tv_nsec;
#else
    return ((uint64_t)clock() * 1000000000ULL) / CLOCKS_PER_SEC;
#endif
}

/* ============================================================================
 * 3. Color & Formatting Utilities
 * ============================================================================ */

static inline bool ttzip_test_detect_color(void) {
    if (getenv("NO_COLOR") != NULL || getenv("NODE_DISABLE_COLORS") != NULL) {
        return false;
    }
    const char* term = getenv("TERM");
    if (term && strcmp(term, "dumb") == 0) {
        return false;
    }
    return (bool)ttzip_isatty(1);
}

static inline void ttzip_test_format_duration(uint64_t nanos, char* out, size_t out_sz) {
    if (nanos < 1000ULL) {
        snprintf(out, out_sz, "%" PRIu64 " ns", nanos);
    } else if (nanos < 1000000ULL) {
        snprintf(out, out_sz, "%.2f µs", (double)nanos / 1000.0);
    } else if (nanos < 1000000000ULL) {
        snprintf(out, out_sz, "%.2f ms", (double)nanos / 1000000.0);
    } else {
        snprintf(out, out_sz, "%.2f s", (double)nanos / 1000000000.0);
    }
}

/* ============================================================================
 * 4. Failure Recording & Assert Handlers
 * ============================================================================ */

static inline void ttzip_test_record_failure(
    ttzip_test_ctx_t* ctx,
    const char* file,
    int line,
    const char* expr,
    const char* fmt,
    ...)
{
    ctx->current_case.passed = false;
    ctx->current_case.fail_file = file;
    ctx->current_case.fail_line = line;
    snprintf(ctx->current_case.fail_expr, sizeof(ctx->current_case.fail_expr), "%s", expr);

    va_list args;
    va_start(args, fmt);
    vsnprintf(ctx->current_case.fail_msg, sizeof(ctx->current_case.fail_msg), fmt, args);
    va_end(args);
}

/* ============================================================================
 * 5. Primary Macro API
 * ============================================================================ */

#define TEST_CASE(name) static void ttzip_test_fn_##name(ttzip_test_ctx_t* _ctx)

#define ASSERT_TRUE(condition) \
    do { \
        _ctx->current_case.assert_count++; \
        if (!(condition)) { \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, #condition, \
                "Expected expression to evaluate to TRUE, was FALSE"); \
            return; \
        } \
    } while (0)

#define ASSERT_FALSE(condition) \
    do { \
        _ctx->current_case.assert_count++; \
        if (condition) { \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, "!(" #condition ")", \
                "Expected expression to evaluate to FALSE, was TRUE"); \
            return; \
        } \
    } while (0)

#define ASSERT_EQ(actual, expected) \
    do { \
        _ctx->current_case.assert_count++; \
        intmax_t _act_val = (intmax_t)(actual); \
        intmax_t _exp_val = (intmax_t)(expected); \
        if (!((actual) == (expected))) { \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, #actual " == " #expected, \
                "Expected %" PRIdMAX " (0x%" PRIxMAX "), got %" PRIdMAX " (0x%" PRIxMAX ")", \
                _exp_val, (uintmax_t)_exp_val, _act_val, (uintmax_t)_act_val); \
            return; \
        } \
    } while (0)

#define ASSERT_NEQ(actual, expected) \
    do { \
        _ctx->current_case.assert_count++; \
        intmax_t _act_val = (intmax_t)(actual); \
        intmax_t _exp_val = (intmax_t)(expected); \
        if ((actual) == (expected)) { \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, #actual " != " #expected, \
                "Expected values to differ, but both were %" PRIdMAX " (0x%" PRIxMAX ") == %" PRIdMAX " (0x%" PRIxMAX ")", \
                _act_val, (uintmax_t)_act_val, _exp_val, (uintmax_t)_exp_val); \
            return; \
        } \
    } while (0)

#define ASSERT_NULL(pointer) \
    do { \
        _ctx->current_case.assert_count++; \
        const void* _ptr = (const void*)(pointer); \
        if (_ptr != NULL) { \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, #pointer " == NULL", \
                "Expected pointer to be NULL, got %p", _ptr); \
            return; \
        } \
    } while (0)

#define ASSERT_NOT_NULL(pointer) \
    do { \
        _ctx->current_case.assert_count++; \
        const void* _ptr = (const void*)(pointer); \
        if (_ptr == NULL) { \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, #pointer " != NULL", \
                "Expected non-NULL pointer, got NULL"); \
            return; \
        } \
    } while (0)

#define ASSERT_STR_EQ(actual, expected) \
    do { \
        _ctx->current_case.assert_count++; \
        const char* _s_act = (const char*)(actual); \
        const char* _s_exp = (const char*)(expected); \
        if (_s_act == NULL && _s_exp == NULL) break; \
        if (_s_act == NULL || _s_exp == NULL || strcmp(_s_act, _s_exp) != 0) { \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, #actual " == " #expected, \
                "Expected \"%s\", got \"%s\"", \
                _s_exp ? _s_exp : "<NULL>", _s_act ? _s_act : "<NULL>"); \
            return; \
        } \
    } while (0)

#define ASSERT_MEM_EQ(actual, expected, size) \
    do { \
        _ctx->current_case.assert_count++; \
        const uint8_t* _m_act = (const uint8_t*)(actual); \
        const uint8_t* _m_exp = (const uint8_t*)(expected); \
        size_t _sz = (size_t)(size); \
        if (_sz > 0 && (_m_act == NULL || _m_exp == NULL || memcmp(_m_act, _m_exp, _sz) != 0)) { \
            size_t _diff_off = 0; \
            if (_m_act && _m_exp) { \
                for (size_t _i = 0; _i < _sz; ++_i) { \
                    if (_m_act[_i] != _m_exp[_i]) { _diff_off = _i; break; } \
                } \
            } \
            ttzip_test_record_failure(_ctx, __FILE__, __LINE__, "memcmp(" #actual ", " #expected ", " #size ") == 0", \
                "Memory mismatch at offset %zu (size %zu). Expected 0x%02X, got 0x%02X", \
                _diff_off, _sz, \
                (_m_exp ? _m_exp[_diff_off] : 0), \
                (_m_act ? _m_act[_diff_off] : 0)); \
            return; \
        } \
    } while (0)

#define TEST_SKIP(reason) \
    do { \
        _ctx->current_case.skipped = true; \
        _ctx->current_case.passed = false; \
        snprintf(_ctx->current_case.fail_msg, sizeof(_ctx->current_case.fail_msg), "%s", reason); \
        return; \
    } while (0)

/* ============================================================================
 * 6. Test Suite Lifecycle & Execution Runner
 * ============================================================================ */

static inline void ttzip_test_init_suite(const char* suite_name) {
    ttzip_test_ctx_t* ctx = ttzip_test_get_global_ctx();
    memset(ctx, 0, sizeof(*ctx));
    ctx->suite_name = suite_name;
    ctx->color_enabled = ttzip_test_detect_color();
}

static inline void ttzip_test_run_case(void (*fn)(ttzip_test_ctx_t*), const char* name) {
    ttzip_test_ctx_t* ctx = ttzip_test_get_global_ctx();
    ctx->total_tests++;
    
    memset(&ctx->current_case, 0, sizeof(ctx->current_case));
    ctx->current_case.name = name;
    ctx->current_case.passed = true;

    uint64_t t0 = ttzip_test_monotonic_nanos();
    fn(ctx);
    uint64_t t1 = ttzip_test_monotonic_nanos();
    ctx->current_case.duration_nanos = t1 - t0;
    ctx->total_duration_nanos += ctx->current_case.duration_nanos;
    ctx->total_assertions += ctx->current_case.assert_count;

    char dur_buf[32];
    ttzip_test_format_duration(ctx->current_case.duration_nanos, dur_buf, sizeof(dur_buf));

    const char* col_green = ctx->color_enabled ? "\033[1;32m" : "";
    const char* col_red   = ctx->color_enabled ? "\033[1;31m" : "";
    const char* col_yellow= ctx->color_enabled ? "\033[1;33m" : "";
    const char* col_cyan  = ctx->color_enabled ? "\033[1;36m" : "";
    const char* col_rst   = ctx->color_enabled ? "\033[0m" : "";

    if (ctx->current_case.skipped) {
        ctx->skipped_tests++;
        printf("  %3zu. [%s SKIP %s] [%s%-14s%s] %-40s (%s) - %s\n",
               ctx->total_tests, col_yellow, col_rst,
               col_cyan, ctx->suite_name ? ctx->suite_name : "Suite", col_rst,
               name, dur_buf, ctx->current_case.fail_msg);
    } else if (ctx->current_case.passed) {
        ctx->passed_tests++;
        printf("  %3zu. [%s PASS %s] [%s%-14s%s] %-40s (%s)\n",
               ctx->total_tests, col_green, col_rst,
               col_cyan, ctx->suite_name ? ctx->suite_name : "Suite", col_rst,
               name, dur_buf);
    } else {
        ctx->failed_tests++;
        printf("  %3zu. [%s FAIL %s] [%s%-14s%s] %-40s (%s)\n",
               ctx->total_tests, col_red, col_rst,
               col_cyan, ctx->suite_name ? ctx->suite_name : "Suite", col_rst,
               name, dur_buf);
        printf("       %s--> %s:%d%s\n", col_red, ctx->current_case.fail_file, ctx->current_case.fail_line, col_rst);
        printf("       %sExpression: %s%s\n", col_red, ctx->current_case.fail_expr, col_rst);
        printf("       %sDetails:    %s%s\n", col_red, ctx->current_case.fail_msg, col_rst);
    }
}

static inline int ttzip_test_finish_suite(void) {
    ttzip_test_ctx_t* ctx = ttzip_test_get_global_ctx();
    char total_dur_buf[32];
    ttzip_test_format_duration(ctx->total_duration_nanos, total_dur_buf, sizeof(total_dur_buf));

    const char* col_green = ctx->color_enabled ? "\033[1;32m" : "";
    const char* col_red   = ctx->color_enabled ? "\033[1;31m" : "";
    const char* col_rst   = ctx->color_enabled ? "\033[0m" : "";

    double pass_rate = ctx->total_tests > 0 ? ((double)ctx->passed_tests / (double)ctx->total_tests) * 100.0 : 0.0;

    printf("\n--------------------------------------------------------------------------------\n");
    printf(" Suite Summary: %s\n", ctx->suite_name ? ctx->suite_name : "Default");
    printf("   Total: %zu | Passed: %s%zu%s | Failed: %s%zu%s | Skipped: %zu | Rate: %.1f%%\n",
           ctx->total_tests,
           col_green, ctx->passed_tests, col_rst,
           (ctx->failed_tests > 0 ? col_red : col_green), ctx->failed_tests, col_rst,
           ctx->skipped_tests, pass_rate);
    printf("   Assertions: %zu | Total Duration: %s\n", ctx->total_assertions, total_dur_buf);
    printf("--------------------------------------------------------------------------------\n\n");

    return (ctx->failed_tests == 0) ? 0 : 1;
}

#define RUN_TEST(name) ttzip_test_run_case(ttzip_test_fn_##name, #name)

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_TEST_HARNESS_H */
