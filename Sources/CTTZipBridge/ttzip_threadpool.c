// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine.

#include "include/ttzip_threadpool.h"
#include <stdlib.h>
#include <string.h>

#if defined(TTZIP_OS_WINDOWS)
  #include <windows.h>
  #include <process.h>
#else
  #include <pthread.h>
  #include <unistd.h>
#endif

typedef struct {
    ttzip_task_fn fn;
    void*         user_data;
} ttzip_task_t;

struct ttzip_threadpool {
    uint32_t      num_threads;
    size_t        queue_capacity;
    ttzip_task_t* task_queue;
    size_t        queue_head;
    size_t        queue_tail;
    size_t        queue_count;
    
    bool          stop;
    size_t        active_tasks; // Count of tasks queued + currently executing
    
#if defined(TTZIP_OS_WINDOWS)
    HANDLE*            threads;
    CRITICAL_SECTION   lock;
    CONDITION_VARIABLE queue_not_empty;
    CONDITION_VARIABLE queue_not_full;
    CONDITION_VARIABLE all_idle;
#else
    pthread_t*      threads;
    pthread_mutex_t lock;
    pthread_cond_t  queue_not_empty;
    pthread_cond_t  queue_not_full;
    pthread_cond_t  all_idle;
#endif
};

static uint32_t ttzip_detect_hardware_threads(void) {
#if defined(TTZIP_OS_WINDOWS)
    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    return sysinfo.dwNumberOfProcessors > 0 ? (uint32_t)sysinfo.dwNumberOfProcessors : 4;
#else
    long cores = sysconf(_SC_NPROCESSORS_ONLN);
    return cores > 0 ? (uint32_t)cores : 4;
#endif
}

#if defined(TTZIP_OS_WINDOWS)
static unsigned __stdcall ttzip_worker_routine(void* arg) {
#else
static void* ttzip_worker_routine(void* arg) {
#endif
    ttzip_threadpool_t* pool = (ttzip_threadpool_t*)arg;
    
    while (1) {
        ttzip_task_t task = {0};
        
#if defined(TTZIP_OS_WINDOWS)
        EnterCriticalSection(&pool->lock);
        while (pool->queue_count == 0 && !pool->stop) {
            SleepConditionVariableCS(&pool->queue_not_empty, &pool->lock, INFINITE);
        }
        if (pool->stop && pool->queue_count == 0) {
            LeaveCriticalSection(&pool->lock);
            break;
        }
        task = pool->task_queue[pool->queue_head];
        pool->queue_head = (pool->queue_head + 1) % pool->queue_capacity;
        pool->queue_count--;
        WakeConditionVariable(&pool->queue_not_full);
        LeaveCriticalSection(&pool->lock);
#else
        pthread_mutex_lock(&pool->lock);
        while (pool->queue_count == 0 && !pool->stop) {
            pthread_cond_wait(&pool->queue_not_empty, &pool->lock);
        }
        if (pool->stop && pool->queue_count == 0) {
            pthread_mutex_unlock(&pool->lock);
            break;
        }
        task = pool->task_queue[pool->queue_head];
        pool->queue_head = (pool->queue_head + 1) % pool->queue_capacity;
        pool->queue_count--;
        pthread_cond_signal(&pool->queue_not_full);
        pthread_mutex_unlock(&pool->lock);
#endif
        
        // Execute task outside lock
        if (task.fn) {
            task.fn(task.user_data);
        }
        
#if defined(TTZIP_OS_WINDOWS)
        EnterCriticalSection(&pool->lock);
        pool->active_tasks--;
        if (pool->active_tasks == 0) {
            WakeAllConditionVariable(&pool->all_idle);
        }
        LeaveCriticalSection(&pool->lock);
#else
        pthread_mutex_lock(&pool->lock);
        pool->active_tasks--;
        if (pool->active_tasks == 0) {
            pthread_cond_broadcast(&pool->all_idle);
        }
        pthread_mutex_unlock(&pool->lock);
#endif
    }
    
#if defined(TTZIP_OS_WINDOWS)
    return 0;
#else
    return NULL;
#endif
}

ttzip_threadpool_t* ttzip_threadpool_create(uint32_t num_threads, size_t queue_capacity) {
    if (num_threads == 0) {
        num_threads = ttzip_detect_hardware_threads();
    }
    if (queue_capacity < 64) {
        queue_capacity = 1024;
    }
    
    ttzip_threadpool_t* pool = (ttzip_threadpool_t*)calloc(1, sizeof(ttzip_threadpool_t));
    if (!pool) return NULL;
    
    pool->num_threads = num_threads;
    pool->queue_capacity = queue_capacity;
    pool->task_queue = (ttzip_task_t*)calloc(queue_capacity, sizeof(ttzip_task_t));
    if (!pool->task_queue) {
        free(pool);
        return NULL;
    }
    
#if defined(TTZIP_OS_WINDOWS)
    InitializeCriticalSection(&pool->lock);
    InitializeConditionVariable(&pool->queue_not_empty);
    InitializeConditionVariable(&pool->queue_not_full);
    InitializeConditionVariable(&pool->all_idle);
    
    pool->threads = (HANDLE*)calloc(num_threads, sizeof(HANDLE));
    for (uint32_t i = 0; i < num_threads; i++) {
        pool->threads[i] = (HANDLE)_beginthreadex(NULL, 0, ttzip_worker_routine, pool, 0, NULL);
    }
#else
    pthread_mutex_init(&pool->lock, NULL);
    pthread_cond_init(&pool->queue_not_empty, NULL);
    pthread_cond_init(&pool->queue_not_full, NULL);
    pthread_cond_init(&pool->all_idle, NULL);
    
    pool->threads = (pthread_t*)calloc(num_threads, sizeof(pthread_t));
    if (!pool->threads) {
        pthread_mutex_destroy(&pool->lock);
        pthread_cond_destroy(&pool->queue_not_empty);
        pthread_cond_destroy(&pool->queue_not_full);
        pthread_cond_destroy(&pool->all_idle);
        free(pool->task_queue);
        free(pool);
        return NULL;
    }
    for (uint32_t i = 0; i < num_threads; i++) {
        pthread_create(&pool->threads[i], NULL, ttzip_worker_routine, pool);
    }
#endif
    
    return pool;
}

int ttzip_threadpool_submit(ttzip_threadpool_t* pool, ttzip_task_fn fn, void* user_data) {
    if (!pool || !fn) return -1;
    
#if defined(TTZIP_OS_WINDOWS)
    EnterCriticalSection(&pool->lock);
    while (pool->queue_count == pool->queue_capacity && !pool->stop) {
        SleepConditionVariableCS(&pool->queue_not_full, &pool->lock, INFINITE);
    }
    if (pool->stop) {
        LeaveCriticalSection(&pool->lock);
        return -1;
    }
    pool->task_queue[pool->queue_tail].fn = fn;
    pool->task_queue[pool->queue_tail].user_data = user_data;
    pool->queue_tail = (pool->queue_tail + 1) % pool->queue_capacity;
    pool->queue_count++;
    pool->active_tasks++;
    WakeConditionVariable(&pool->queue_not_empty);
    LeaveCriticalSection(&pool->lock);
#else
    pthread_mutex_lock(&pool->lock);
    while (pool->queue_count == pool->queue_capacity && !pool->stop) {
        pthread_cond_wait(&pool->queue_not_full, &pool->lock);
    }
    if (pool->stop) {
        pthread_mutex_unlock(&pool->lock);
        return -1;
    }
    pool->task_queue[pool->queue_tail].fn = fn;
    pool->task_queue[pool->queue_tail].user_data = user_data;
    pool->queue_tail = (pool->queue_tail + 1) % pool->queue_capacity;
    pool->queue_count++;
    pool->active_tasks++;
    pthread_cond_signal(&pool->queue_not_empty);
    pthread_mutex_unlock(&pool->lock);
#endif
    return 0;
}

void ttzip_threadpool_wait_all(ttzip_threadpool_t* pool) {
    if (!pool) return;
    
#if defined(TTZIP_OS_WINDOWS)
    EnterCriticalSection(&pool->lock);
    while (pool->active_tasks > 0) {
        SleepConditionVariableCS(&pool->all_idle, &pool->lock, INFINITE);
    }
    LeaveCriticalSection(&pool->lock);
#else
    pthread_mutex_lock(&pool->lock);
    while (pool->active_tasks > 0) {
        pthread_cond_wait(&pool->all_idle, &pool->lock);
    }
    pthread_mutex_unlock(&pool->lock);
#endif
}

typedef struct {
    ttzip_parallel_for_fn fn;
    void*                 user_data;
    size_t                start_index;
    size_t                end_index;
} ttzip_parallel_for_chunk_t;

static void ttzip_parallel_for_chunk_worker(void* arg) {
    ttzip_parallel_for_chunk_t* chunk = (ttzip_parallel_for_chunk_t*)arg;
    for (size_t i = chunk->start_index; i < chunk->end_index; i++) {
        chunk->fn(i, chunk->user_data);
    }
    free(chunk);
}

void ttzip_parallel_for(ttzip_threadpool_t* pool, size_t count, ttzip_parallel_for_fn fn, void* user_data) {
    if (count == 0 || !fn) return;
    
    if (!pool) {
        pool = ttzip_threadpool_shared();
    }
    
    if (count == 1 || pool->num_threads <= 1) {
        for (size_t i = 0; i < count; i++) {
            fn(i, user_data);
        }
        return;
    }
    
    size_t num_chunks = pool->num_threads * 2;
    if (num_chunks > count) num_chunks = count;
    
    size_t items_per_chunk = (count + num_chunks - 1) / num_chunks;
    
    for (size_t c = 0; c < num_chunks; c++) {
        size_t start = c * items_per_chunk;
        if (start >= count) break;
        size_t end = start + items_per_chunk;
        if (end > count) end = count;
        
        ttzip_parallel_for_chunk_t* chunk = (ttzip_parallel_for_chunk_t*)malloc(sizeof(ttzip_parallel_for_chunk_t));
        if (!chunk) {
            for (size_t i = start; i < end; i++) {
                fn(i, user_data);
            }
            continue;
        }
        chunk->fn = fn;
        chunk->user_data = user_data;
        chunk->start_index = start;
        chunk->end_index = end;
        
        if (ttzip_threadpool_submit(pool, ttzip_parallel_for_chunk_worker, chunk) != 0) {
            for (size_t i = start; i < end; i++) {
                fn(i, user_data);
            }
            free(chunk);
        }
    }
    
    ttzip_threadpool_wait_all(pool);
}

uint32_t ttzip_threadpool_get_thread_count(const ttzip_threadpool_t* pool) {
    return pool ? pool->num_threads : 0;
}

void ttzip_threadpool_destroy(ttzip_threadpool_t* pool) {
    if (!pool) return;
    
#if defined(TTZIP_OS_WINDOWS)
    EnterCriticalSection(&pool->lock);
    pool->stop = true;
    WakeAllConditionVariable(&pool->queue_not_empty);
    WakeAllConditionVariable(&pool->queue_not_full);
    LeaveCriticalSection(&pool->lock);
    
    for (uint32_t i = 0; i < pool->num_threads; i++) {
        if (pool->threads[i]) {
            WaitForSingleObject(pool->threads[i], INFINITE);
            CloseHandle(pool->threads[i]);
        }
    }
    DeleteCriticalSection(&pool->lock);
#else
    pthread_mutex_lock(&pool->lock);
    pool->stop = true;
    pthread_cond_broadcast(&pool->queue_not_empty);
    pthread_cond_broadcast(&pool->queue_not_full);
    pthread_mutex_unlock(&pool->lock);
    
    for (uint32_t i = 0; i < pool->num_threads; i++) {
        pthread_join(pool->threads[i], NULL);
    }
    pthread_mutex_destroy(&pool->lock);
    pthread_cond_destroy(&pool->queue_not_empty);
    pthread_cond_destroy(&pool->queue_not_full);
    pthread_cond_destroy(&pool->all_idle);
#endif
    
    free(pool->threads);
    free(pool->task_queue);
    free(pool);
}

static ttzip_threadpool_t* g_shared_pool = NULL;
#if defined(TTZIP_OS_WINDOWS)
static INIT_ONCE g_shared_init_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK ttzip_init_shared_pool_cb(PINIT_ONCE InitOnce, PVOID Parameter, PVOID *lpContext) {
    (void)InitOnce; (void)Parameter; (void)lpContext;
    g_shared_pool = ttzip_threadpool_create(0, 4096);
    return TRUE;
}
#else
static pthread_once_t g_shared_once = PTHREAD_ONCE_INIT;
static void ttzip_init_shared_pool(void) {
    g_shared_pool = ttzip_threadpool_create(0, 4096);
}
#endif

ttzip_threadpool_t* ttzip_threadpool_shared(void) {
#if defined(TTZIP_OS_WINDOWS)
    InitOnceExecuteOnce(&g_shared_init_once, ttzip_init_shared_pool_cb, NULL, NULL);
#else
    pthread_once(&g_shared_once, ttzip_init_shared_pool);
#endif
    return g_shared_pool;
}

/* ============================================================================
 * 2. Once-initialization Implementation
 * ============================================================================ */

#if defined(TTZIP_OS_WINDOWS)
static BOOL CALLBACK ttzip_once_cb(PINIT_ONCE InitOnce, PVOID Parameter, PVOID *lpContext) {
    (void)InitOnce; (void)lpContext;
    void (*fn)(void) = (void (*)(void))Parameter;
    if (fn) fn();
    return TRUE;
}

void ttzip_once(ttzip_once_t* token, void (*init_fn)(void)) {
    if (token && init_fn) {
        InitOnceExecuteOnce(token, ttzip_once_cb, (PVOID)init_fn, NULL);
    }
}
#else
void ttzip_once(ttzip_once_t* token, void (*init_fn)(void)) {
    if (token && init_fn) {
        pthread_once(token, init_fn);
    }
}
#endif

/* ============================================================================
 * 3. Counting Semaphore Implementation
 * ============================================================================ */

#if defined(TTZIP_OS_WINDOWS)
struct ttzip_semaphore {
    HANDLE handle;
};

ttzip_semaphore_t* ttzip_semaphore_create(int32_t initial_count) {
    ttzip_semaphore_t* sem = (ttzip_semaphore_t*)malloc(sizeof(ttzip_semaphore_t));
    if (!sem) return NULL;
    sem->handle = CreateSemaphoreW(NULL, initial_count, 0x7FFFFFFF, NULL);
    if (!sem->handle) {
        free(sem);
        return NULL;
    }
    return sem;
}

void ttzip_semaphore_wait(ttzip_semaphore_t* sem) {
    if (sem && sem->handle) {
        WaitForSingleObject(sem->handle, INFINITE);
    }
}

void ttzip_semaphore_signal(ttzip_semaphore_t* sem) {
    if (sem && sem->handle) {
        ReleaseSemaphore(sem->handle, 1, NULL);
    }
}

void ttzip_semaphore_destroy(ttzip_semaphore_t* sem) {
    if (!sem) return;
    if (sem->handle) {
        CloseHandle(sem->handle);
    }
    free(sem);
}
#else
struct ttzip_semaphore {
    pthread_mutex_t lock;
    pthread_cond_t  cond;
    int32_t         count;
};

ttzip_semaphore_t* ttzip_semaphore_create(int32_t initial_count) {
    ttzip_semaphore_t* sem = (ttzip_semaphore_t*)malloc(sizeof(ttzip_semaphore_t));
    if (!sem) return NULL;
    pthread_mutex_init(&sem->lock, NULL);
    pthread_cond_init(&sem->cond, NULL);
    sem->count = initial_count;
    return sem;
}

void ttzip_semaphore_wait(ttzip_semaphore_t* sem) {
    if (!sem) return;
    pthread_mutex_lock(&sem->lock);
    while (sem->count <= 0) {
        pthread_cond_wait(&sem->cond, &sem->lock);
    }
    sem->count--;
    pthread_mutex_unlock(&sem->lock);
}

void ttzip_semaphore_signal(ttzip_semaphore_t* sem) {
    if (!sem) return;
    pthread_mutex_lock(&sem->lock);
    sem->count++;
    pthread_cond_signal(&sem->cond);
    pthread_mutex_unlock(&sem->lock);
}

void ttzip_semaphore_destroy(ttzip_semaphore_t* sem) {
    if (!sem) return;
    pthread_mutex_destroy(&sem->lock);
    pthread_cond_destroy(&sem->cond);
    free(sem);
}
#endif
