// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

/**
 * @file ttzip_threadpool.h
 * @brief High-performance, zero-external-dependency, cross-platform C11 thread pool.
 * @details Supports POSIX (pthreads) and Windows (Win32 ThreadPool / native threads) backends.
 */

#ifndef TTZIP_THREADPOOL_H
#define TTZIP_THREADPOOL_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "ttzip_platform.h"

#if defined(TTZIP_OS_WINDOWS)
  #include <windows.h>
#else
  #include <pthread.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * 1. Thread Pool Core Types and Function Signatures
 * ============================================================================ */

typedef struct ttzip_threadpool ttzip_threadpool_t;

/**
 * @brief Task function signature for worker threads.
 * @param user_data Pointer to user context/arguments.
 */
typedef void (*ttzip_task_fn)(void* user_data);

/**
 * @brief Parallel for iteration function signature.
 * @param index 0-based iteration index.
 * @param user_data Pointer to user context.
 */
typedef void (*ttzip_parallel_for_fn)(size_t index, void* user_data);

/**
 * @brief Creates a new cross-platform thread pool.
 * @param num_threads Number of worker threads (0 = auto-detect hardware concurrency).
 * @param queue_capacity Maximum capacity of pending task queue (0 = default 1024).
 * @return Pointer to thread pool instance or NULL on allocation failure.
 */
TTZIP_API ttzip_threadpool_t* ttzip_threadpool_create(uint32_t num_threads, size_t queue_capacity);

/**
 * @brief Submits an asynchronous task to the thread pool.
 * @param pool Thread pool handle.
 * @param fn Function to execute.
 * @param user_data Argument passed to fn.
 * @return 0 on success, non-zero if queue is full or invalid handle.
 */
TTZIP_API int ttzip_threadpool_submit(ttzip_threadpool_t* pool, ttzip_task_fn fn, void* user_data);

/**
 * @brief Executes a parallel for-loop across iterations [0, count - 1] and blocks until all finish.
 * @details Replaces Apple GCD dispatch_apply() with zero platform lock-in.
 * @param pool Thread pool handle (if NULL, uses global shared pool).
 * @param count Total number of iterations.
 * @param fn Iteration body callback.
 * @param user_data Argument passed to fn.
 */
TTZIP_API void ttzip_parallel_for(ttzip_threadpool_t* pool, size_t count, ttzip_parallel_for_fn fn, void* user_data);

/**
 * @brief Blocks the calling thread until all currently queued and executing tasks have finished.
 * @param pool Thread pool handle.
 */
TTZIP_API void ttzip_threadpool_wait_all(ttzip_threadpool_t* pool);

/**
 * @brief Gets the number of active worker threads in the pool.
 * @param pool Thread pool handle.
 */
TTZIP_API uint32_t ttzip_threadpool_get_thread_count(const ttzip_threadpool_t* pool);

/**
 * @brief Gracefully shuts down the thread pool and frees all resources.
 * @param pool Thread pool handle.
 */
TTZIP_API void ttzip_threadpool_destroy(ttzip_threadpool_t* pool);

typedef enum {
    TTZIP_QOS_PERFORMANCE = 0, // Latency-critical decompression & UI-blocking jobs (P-cores)
    TTZIP_QOS_EFFICIENCY  = 1, // Energy-efficient background batch compression (E-cores)
    TTZIP_QOS_ALL         = 2  // Full-throughput parallel processing (P + E cores)
} ttzip_qos_tier_t;

/**
 * @brief Retrieves the global process-wide shared thread pool.
 */
TTZIP_API ttzip_threadpool_t* ttzip_threadpool_shared(void);

/**
 * @brief Retrieves the dedicated Performance-core shared thread pool.
 */
TTZIP_API ttzip_threadpool_t* ttzip_threadpool_shared_p(void);

/**
 * @brief Retrieves the dedicated Efficiency-core shared thread pool.
 */
TTZIP_API ttzip_threadpool_t* ttzip_threadpool_shared_e(void);

/**
 * @brief Executes a parallel for-loop across iterations [0, count - 1] with targeted QoS routing.
 * @param pool Thread pool handle (if NULL, routes automatically to P or E pool based on tier).
 * @param count Total number of iterations.
 * @param fn Iteration body callback.
 * @param user_data Argument passed to fn.
 * @param tier Target QoS tier.
 */
TTZIP_API void ttzip_parallel_for_qos(ttzip_threadpool_t* pool, size_t count, ttzip_parallel_for_fn fn, void* user_data, ttzip_qos_tier_t tier);

/* ============================================================================
 * 2. Once-initialization Primitive (cross-platform dispatch_once replacement)
 * ============================================================================ */

#if defined(TTZIP_OS_WINDOWS)
typedef INIT_ONCE ttzip_once_t;
#define TTZIP_ONCE_INIT INIT_ONCE_STATIC_INIT
#else
typedef pthread_once_t ttzip_once_t;
#define TTZIP_ONCE_INIT PTHREAD_ONCE_INIT
#endif

/**
 * @brief Thread-safe one-time initialization routine.
 * @param token Pointer to token initialized with TTZIP_ONCE_INIT.
 * @param init_fn Callback executed exactly once.
 */
TTZIP_API void ttzip_once(ttzip_once_t* token, void (*init_fn)(void));

/* ============================================================================
 * 3. Counting Semaphore (cross-platform dispatch_semaphore replacement)
 * ============================================================================ */

typedef struct ttzip_semaphore ttzip_semaphore_t;

/**
 * @brief Creates a counting semaphore.
 * @param initial_count Initial permit count.
 */
TTZIP_API ttzip_semaphore_t* ttzip_semaphore_create(int32_t initial_count);

/**
 * @brief Decrements (locks) the semaphore, blocking if count <= 0.
 */
TTZIP_API void ttzip_semaphore_wait(ttzip_semaphore_t* sem);

/**
 * @brief Increments (unlocks) the semaphore and unblocks waiting threads.
 */
TTZIP_API void ttzip_semaphore_signal(ttzip_semaphore_t* sem);

/**
 * @brief Destroys and frees the semaphore.
 */
TTZIP_API void ttzip_semaphore_destroy(ttzip_semaphore_t* sem);

#ifdef __cplusplus
}
#endif

#endif /* TTZIP_THREADPOOL_H */
