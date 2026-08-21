/*
 * Copyright (c) 2016-present, Yann Collet, Facebook, Inc.
 * All rights reserved.
 * Modified for FL2 by Conor McCarthy
 * Unified with TTZip Threadpool by TTZip Core Architecture.
 *
 * This source code is licensed under both the BSD-style license (found in the
 * LICENSE file in the root directory of this source tree) and the GPLv2 (found
 * in the COPYING file in the root directory of this source tree).
 * You may select, at your option, one of the above-listed licenses.
 */

#include <stddef.h>  /* size_t */
#include <stdlib.h>  /* malloc, calloc */
#include "fl2_pool.h"
#include "fl2_internal.h"
#include "fl2_threading.h"

#ifndef FL2_SINGLETHREAD

struct FL2POOL_ctx_s {
    size_t numThreads;
    size_t numThreadsBusy;
    FL2_pthread_mutex_t queueMutex;
    FL2_pthread_cond_t busyCond;
    int shutdown;
};

typedef struct {
    FL2POOL_ctx* pool_ctx;
    FL2POOL_function function;
    void* opaque;
    ptrdiff_t n;
} FL2POOL_task_t;

FL2POOL_ctx* FL2POOL_create(size_t numThreads) {
    if (!numThreads) return NULL;
    FL2POOL_ctx* ctx = (FL2POOL_ctx*)calloc(1, sizeof(FL2POOL_ctx));
    if (!ctx) return NULL;
    ctx->numThreads = numThreads;
    ctx->numThreadsBusy = 0;
    ctx->shutdown = 0;
    FL2_pthread_mutex_init(&ctx->queueMutex, NULL);
    FL2_pthread_cond_init(&ctx->busyCond, NULL);
    return ctx;
}

void FL2POOL_free(FL2POOL_ctx* ctx) {
    if (!ctx) return;
    FL2POOL_waitAll(ctx, 0);
    FL2_pthread_mutex_lock(&ctx->queueMutex);
    ctx->shutdown = 1;
    FL2_pthread_mutex_unlock(&ctx->queueMutex);
    FL2_pthread_mutex_destroy(&ctx->queueMutex);
    FL2_pthread_cond_destroy(&ctx->busyCond);
    free(ctx);
}

size_t FL2POOL_sizeof(FL2POOL_ctx* ctx) {
    return ctx ? sizeof(*ctx) : 0;
}

void FL2POOL_addRange(void* ctxVoid, FL2POOL_function function, void* opaque, ptrdiff_t first, ptrdiff_t end) {
    (void)ctxVoid;
    if (first >= end) return;
    for (ptrdiff_t i = first; i < end; ++i) {
        function(opaque, i);
    }
}

void FL2POOL_add(void* ctxVoid, FL2POOL_function function, void* opaque, ptrdiff_t n) {
    FL2POOL_addRange(ctxVoid, function, opaque, n, n + 1);
}

int FL2POOL_waitAll(void* ctxVoid, unsigned timeout) {
    FL2POOL_ctx* const ctx = (FL2POOL_ctx*)ctxVoid;
    if (!ctx) return 0;
    
    FL2_pthread_mutex_lock(&ctx->queueMutex);
    if (timeout != 0) {
        if (ctx->numThreadsBusy > 0 && !ctx->shutdown) {
            FL2_pthread_cond_timedwait(&ctx->busyCond, &ctx->queueMutex, timeout);
        }
    } else {
        while (ctx->numThreadsBusy > 0 && !ctx->shutdown) {
            FL2_pthread_cond_wait(&ctx->busyCond, &ctx->queueMutex);
        }
    }
    int remaining = (int)ctx->numThreadsBusy;
    FL2_pthread_mutex_unlock(&ctx->queueMutex);
    return remaining;
}

size_t FL2POOL_threadsBusy(void* ctxVoid) {
    FL2POOL_ctx* const ctx = (FL2POOL_ctx*)ctxVoid;
    if (!ctx) return 0;
    FL2_pthread_mutex_lock(&ctx->queueMutex);
    size_t busy = ctx->numThreadsBusy;
    FL2_pthread_mutex_unlock(&ctx->queueMutex);
    return busy;
}

#endif  /* FL2_SINGLETHREAD */
