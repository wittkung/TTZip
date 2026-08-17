// ttzip_fl2_bridge.c
// TTZip Fast-LZMA2 Multi-Threaded Engine Bridge & Hybrid Dispatcher

#include "include/ttzip_fl2_lzma2.h"
#include "include/ttzip_lzma2_fast_encoder.h"
#include "include/ttzip_platform.h"
#include "fast-lzma2/fast-lzma2.h"
#include "include/CTTZipCommon.h"

#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <pthread.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

static int get_local_p_core_count(void) {
    int count = 0;
    size_t size = sizeof(count);
#if defined(__APPLE__)
    if (sysctlbyname("hw.perflevel0.physicalcpu", &count, &size, NULL, 0) == 0 && count > 0) {
        return count;
    }
    if (sysctlbyname("hw.physicalcpu", &count, &size, NULL, 0) == 0 && count > 0) {
        return count;
    }
#endif
    return 8;
}

bool ttzip_fl2_is_supported(void) {
    return true;
}

// 线程局部缓存单线程 FL2_CCtx 上下文，避免在并发循环中频繁 malloc/free 与销毁结构体
static TTZIP_THREAD_LOCAL FL2_CCtx* s_tls_fl2_cctx = NULL;

int ttzip_fl2_compress_block(
    const uint8_t* src,
    size_t src_len,
    uint8_t* dst,
    size_t dst_capacity,
    size_t* out_compressed_len,
    int level,
    bool is_zero_block,
    uint32_t* out_dict_size,
    int thread_count
) {
    if (!src || !dst || !out_compressed_len) return -1;
    if (src_len == 0) {
        *out_compressed_len = 0;
        if (out_dict_size) *out_dict_size = 4096;
        return 0;
    }

    // 1. 稀疏零块极速旁路 (NEON 向量加速)
    if (is_zero_block) {
        return ttzip_lzma2_compress_block_tuned(
            src, src_len, dst, dst_capacity,
            out_compressed_len, 1, true, out_dict_size
        );
    }

    // 2. Level 1 混合自研 NEON Fast-Path (保护 3,200+ MB/s 极限吞吐门禁)
    if (level <= 1) {
        return ttzip_lzma2_compress_block_tuned(
            src, src_len, dst, dst_capacity,
            out_compressed_len, 1, false, out_dict_size
        );
    }

    // 3. Level 2 ~ 6 极速 HC4 Fast-Path (保护 530+ MB/s 高吞吐)
    if (level <= 6 && thread_count <= 1) {
        return ttzip_lzma2_compress_block_tuned(
            src, src_len, dst, dst_capacity,
            out_compressed_len, level, false, out_dict_size
        );
    }

    // 4. Level 6 ~ Level 9 高/极限压缩等级 Fast-LZMA2 多核 Radix 引擎
    uint32_t dict_size = 16 * 1024 * 1024;
    if (level <= 5) {
        dict_size = 8 * 1024 * 1024;
    } else if (level <= 7) {
        dict_size = 16 * 1024 * 1024;
    } else {
        dict_size = 32 * 1024 * 1024;
    }

    if (dict_size > (uint32_t)src_len && src_len > 0) {
        uint32_t ds = 65536;
        while (ds < (uint32_t)src_len && ds < dict_size) {
            ds <<= 1;
        }
        dict_size = ds;
    }

    if (out_dict_size) {
        *out_dict_size = dict_size;
    }

    FL2_CCtx* cctx = NULL;
    bool needs_free = false;

    if (thread_count > 1) {
        cctx = FL2_createCCtxMt((unsigned)thread_count);
        needs_free = true;
    } else {
        if (!s_tls_fl2_cctx) {
            s_tls_fl2_cctx = FL2_createCCtx();
        }
        cctx = s_tls_fl2_cctx;
    }

    if (!cctx) {
        return ttzip_lzma2_compress_block_tuned(
            src, src_len, dst, dst_capacity,
            out_compressed_len, level, false, out_dict_size
        );
    }

    FL2_CCtx_setParameter(cctx, FL2_p_compressionLevel, (unsigned)level);
    FL2_CCtx_setParameter(cctx, FL2_p_dictionarySize, dict_size);
    FL2_CCtx_setParameter(cctx, FL2_p_omitProperties, 1); // 7Z 原生 raw LZMA2 chunk 格式
#ifndef NO_XXHASH
    FL2_CCtx_setParameter(cctx, FL2_p_doXXHash, 0);       // 禁止尾随 xxhash 破坏 7Z pack 流
#endif

    size_t compressed_res = FL2_compressCCtx(
        cctx,
        dst,
        dst_capacity,
        src,
        src_len,
        level
    );

    if (needs_free) {
        FL2_freeCCtx(cctx);
    }

    if (FL2_isError(compressed_res)) {
        return ttzip_lzma2_compress_block_tuned(
            src, src_len, dst, dst_capacity,
            out_compressed_len, level, false, out_dict_size
        );
    }

    *out_compressed_len = compressed_res;
    return 0;
}

struct ttzip_fl2_stream_ctx_s {
    uint32_t magic;
    FL2_CStream* stream;
    int level;
    uint32_t dict_size;
};

ttzip_fl2_stream_ctx_t* ttzip_fl2_stream_create(int level, uint32_t dict_size, int thread_count) {
    int p_cores = thread_count > 0 ? thread_count : get_local_p_core_count();
    if (p_cores < 1) p_cores = 1;
    if (p_cores > 32) p_cores = 32;

    FL2_CStream* fcs = FL2_createCStreamMt((unsigned)p_cores, 0);
    if (!fcs) return NULL;

    ttzip_fl2_stream_ctx_t* ctx = (ttzip_fl2_stream_ctx_t*)calloc(1, sizeof(ttzip_fl2_stream_ctx_t));
    if (!ctx) {
        FL2_freeCStream(fcs);
        return NULL;
    }

    ctx->magic = TTZIP_FL2S_MAGIC;
    ctx->stream = fcs;
    ctx->level = level;
    ctx->dict_size = dict_size > 0 ? dict_size : (16 * 1024 * 1024);

    FL2_initCStream(fcs, level);
    FL2_CStream_setParameter(fcs, FL2_p_compressionLevel, (unsigned)level);
    FL2_CStream_setParameter(fcs, FL2_p_dictionarySize, ctx->dict_size);
    FL2_CStream_setParameter(fcs, FL2_p_omitProperties, 1);
#ifndef NO_XXHASH
    FL2_CStream_setParameter(fcs, FL2_p_doXXHash, 0);
#endif

    return ctx;
}

int ttzip_fl2_stream_process(
    ttzip_fl2_stream_ctx_t* ctx,
    const uint8_t* in_data,
    size_t in_size,
    size_t* in_consumed,
    uint8_t* out_buf,
    size_t out_capacity,
    size_t* out_produced,
    bool is_end
) {
    if (!ctx || ctx->magic != TTZIP_FL2S_MAGIC || !ctx->stream) return -1;
    if (!out_buf || !out_produced) return -2;

    FL2_inBuffer in_buf = { in_data, in_size, 0 };
    FL2_outBuffer out_buf_struct = { out_buf, out_capacity, 0 };

    if (in_size > 0) {
        size_t res = FL2_compressStream(ctx->stream, &out_buf_struct, &in_buf);
        if (FL2_isError(res)) return -3;
    }

    if (is_end) {
        size_t rem = FL2_endStream(ctx->stream, &out_buf_struct);
        if (FL2_isError(rem)) return -4;
    }

    if (in_consumed) *in_consumed = in_buf.pos;
    *out_produced = out_buf_struct.pos;
    return 0;
}

void ttzip_fl2_stream_free(ttzip_fl2_stream_ctx_t* ctx) {
    if (!ctx) return;
    if (ctx->magic == TTZIP_FL2S_MAGIC) {
        ctx->magic = 0; // Deterministic bounds cleanup
        if (ctx->stream) {
            FL2_freeCStream(ctx->stream);
            ctx->stream = NULL;
        }
    }
    free(ctx);
}
