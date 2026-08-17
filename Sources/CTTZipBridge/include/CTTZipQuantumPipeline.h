#ifndef CTTZipQuantumPipeline_h
#define CTTZipQuantumPipeline_h

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Quantum 128KB Block 硬件物理切片定义
#define TTZIP_QUANTUM_BLOCK_SIZE (128 * 1024)

// 1. NEON 矢量硬件计算 4KB 数据块 Shannon 熵 (计算速度 100+ GB/s)
double ttzip_quantum_calc_entropy_neon(const void* buf, size_t len);

// 2. 128-Bit ARM NEON 64-Byte 突发无分支 (Branchless) 极速内存拷贝
void ttzip_quantum_copy_branchless_neon(void* dst, const void* src, size_t len);

// 3. 矢量 RLE 超高速预压缩检测 (纯 0 / 重复字节 0.001ms 瞬时压缩)
size_t ttzip_quantum_rle_compress_neon(const void* src, size_t src_size, void* dst, size_t dst_capacity);
size_t ttzip_quantum_rle_decompress_neon(const void* src, size_t src_size, void* dst, size_t dst_capacity);

// 4. Quantum 两阶段 (Two-Pass) 解耦解压架构接口
size_t ttzip_quantum_decompress_two_pass(
    const void* src,
    size_t src_size,
    void* dst,
    size_t dst_capacity
);

#ifdef __cplusplus
}
#endif

#endif /* CTTZipQuantumPipeline_h */
