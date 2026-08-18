# TTZip 汇编优化基础设施 (Assembly Infrastructure System, AIS) 架构设计与工程规范

---

## 1. 系统概述与设计哲学

TTZip 汇编优化基础设施 (Assembly Infrastructure System, AIS) 是 TTZip 底层引擎 (`CTTZipBridge`) 中专门负责硬件级优化、手写汇编算子集成、CPU 动态派发与微架构性能剖析的技术子系统。

### 设计哲学与合规铁律
1. **极致吞吐 (Zero-Overhead Throughput)**：直接消除条件分支惩罚与 C 编译器的保守假设，榨干 Apple Silicon (ARM64) 与 x86_64 硬件流水线极限。
2. **结构化与工程化 (Structured Low-Level Architecture)**：严格遵循 8 大底层设计模式，摒弃零散内联汇编，使用模块化 `.S` 汇编文件与 C 桥接。
3. **内存绝对安全 (Bit-Exact & Page Boundary Safe)**：所有的手写汇编内核必须经过 100% Bit-Exact 差异化比对和 `mmap` 页边界打靶测试，绝不产生内存越界 (Segfault)。
4. **严格遵循冻结引擎约束 (Strict Engine Freeze Isolation)**：根据项目 `GEMINI.md` 规范，绝对禁止侵入已冻结的 Swift/C 文件（如 `CTTZipBridge_Crypto.c`, `CTTZipExtract.c`, `ZipParallelExtractor.swift` 等）。AIS 优化完全下沉至底端 C/ASM 层（`Sources/CTTZipBridge/asm/` 与 `dispatch/`），通过零开销函数接口和只读派发表（Dispatch Table）无痛挂载。

---

## 2. 源码文件目录拓扑 (Source Topology)

```
Sources/CTTZipBridge/
├── asm/                                    # 汇编底层源码目录
│   ├── common/
│   │   ├── arm64inc.S                      # ARM64 统一 ABI、符号 Mangling、DWARF CFI 栈帧宏
│   │   └── ttzip_asm_config.h              # C/ASM 预处理配置宏
│   ├── arm64/
│   │   ├── ttzip_crc32_arm64.S             # ARM64 PMULL 降阶/CRC32 向量化算子
│   │   ├── ttzip_adler32_arm64.S           # ARM64 NEON DotProduct Adler32 算子
│   │   ├── ttzip_lzma_match_arm64.S        # ARM64 16-byte 双路模式匹配算子 (含页安全 Canary)
│   │   ├── ttzip_range_coder_arm64.S       # ARM64 无分支 Range Coder 8-bit Tree 算子
│   │   ├── ttzip_aes_arm64.S               # ARM64 Crypto 4-way 交错 AES-CBC/CTR 算子
│   │   └── ttzip_mem_arm64.S               # ARM64 LZ 重叠复制 (Overlapping Copy) 算子
│   └── x86_64/
│       ├── ttzip_crc32_avx512.S            # x86_64 AVX-512 VPCLMULQDQ CRC32 算子
│       └── ttzip_aes_vaes.S                # x86_64 VAES 16-block 并行 AES 算子
├── dispatch/                               # 动态探测与派发表
│   ├── ttzip_cpu_features.h/.c             # CPU 硬件能力捕获 (sysctlbyname / cpuid)
│   └── ttzip_dispatch_table.h/.c           # 只读全局派发表与原子单例初始化
├── harness/                                # 测试与性能拓扑
│   ├── ttzip_asm_diff_test.h/.c            # 双路 Bit-exact 差异比对与 Fuzz 测试引擎
│   ├── ttzip_asm_page_guard.h/.c           # mmap 跨页安全边界打靶测试
│   └── ttzip_asm_benchmark.h/.c            # Cycles per Byte (CPB) 与 GB/s 高精度跑分拓扑
└── include/
    └── CTTZipBridge.h                      # 统一对外导出的 C 头文件
```

---

## 3. 代码库剖析与 6 大精确定位算子植入点

通过对 `Sources/CTTZipBridge/` 源码审计，精确定位出以下 6 大底层核心替换点：

| 算子类别 | 代码库当前实现位置 | 存在的技术瓶颈与安全隐患 | AIS 汇编内核与派发方案 |
| :--- | :--- | :--- | :--- |
| **1. CRC32 & Checksum** | `CTTZipCRC32Neon.c`<br>`CTTZipSIMD.c` | ARM64 使用单条指令，无法满载流水线；x86 环境退化为纯 C 移位循环，吞吐断崖。 | 在 `asm/arm64/ttzip_crc32_arm64.S` 实现 4-Way PMULL 无模降阶折叠，推至 25GB/s+；x86 实现 AVX-512 VPCLMULQDQ；挂载至 `g_ttzip_dispatch.crc32`。 |
| **2. LZMA Match Finder** | `ttzip_lzma_hc4_neon.c`<br>`CTTZipNEONMatchFinder.h` | 使用 `vld1q_u8` 进行 16-byte 加载，未处理页边界，若 Buffer 尾部位于页界限会导致 SIGSEGV。 | 在 `asm/arm64/ttzip_lzma_match_arm64.S` 实现基于 `ldp` 双路加载 + `clz` 的无越界汇编算子，带 mmap 页安全防护，挂载至 `g_ttzip_dispatch.match_len`。 |
| **3. Range Coder 比特流** | `ttzip_lzma_range_coder.h` | 纯 C 条件分支实现 (`ttzip_rc_encode_bit`)，每 bit 计算产生严重的 `if` 分支预测开销。 | 在 `asm/arm64/ttzip_range_coder_arm64.S` 实现无分支 (`csel`/`csinc`) 8-bit Tree 展开汇编算子，挂载至 `g_ttzip_dispatch.range_encode_bit`。 |
| **4. AES 硬件加解密** | `CTTZipBridge_Crypto.c`<br>(冻结文件) | 内部 `ttzip_aes256_ctr_neon_chunk` 采用 8 块 C Intrinsic；未处理指令 Latency 掩盖。 | 在 `asm/arm64/ttzip_aes_arm64.S` 实现 4-Way / 8-Way 交错汇编内核，在派发表暴露 `g_ttzip_dispatch.aes_cbc_decrypt`，不修改冻结 C 文件结构。 |
| **5. LZ 重叠复制** | `ttzip_lzma2_enc_native.c`<br>通用 C 循环 | LZ 算法遇到 Distance < Length (如重复单字符或 3 字节短串) 出现标量重复拷贝惩罚。 | 在 `asm/arm64/ttzip_mem_arm64.S` 实现基于 NEON `vdup` 向量广播的单周期重叠复制，挂载至 `g_ttzip_dispatch.overlap_copy`。 |
| **6. Varint / ASCII 转换** | `CTTZipSIMD.c` | `ttzip_varint_write_u64` 采用带循环的条件分支。 | 实现无分支向量 Varint / UTF-8 校验汇编算子。 |

---

## 4. C 语言与汇编底层 8 大设计模式

| 模式名称 | 英文名称 | 解决问题 | 实现方式与架构逻辑 |
| :--- | :--- | :--- | :--- |
| **1. 虚派发表模式** | Virtual Dispatch Table | 热点路径条件分支惩罚 (Branch Misprediction) | 全局只读 `g_ttzip_dispatch` 结构体，启动时绑定最高效算子，单条 `BLR` 跳转。 |
| **2. 栈帧模版方法模式** | Template Method & CFI Macro | 手写汇编遗漏 Callee-saved 寄存器或 DWARF 导致调试断栈 | 在 `arm64inc.S` 中定义 `function`/`endfunc`/`PROLOGUE_*` 模版宏，约束 AAPCS64 规范。 |
| **3. 软件流水线交错模式** | Interleaved Multi-Buffer Strategy | 硬件向量指令（如 AES）3~4 cycles 延迟导致的管线 Stall | 4-Way / 8-Way Block Interleaving，在单个循环体内展开 4 组无关数据，隐藏延迟。 |
| **4. Barrett 降阶折叠模式** | Barrett Polynomial Reduction | 校验算法 (CRC32/Adler32) 的强串行数据依赖 | 利用 `PMULL` / `VPCLMULQDQ` 无模乘法将 128 字节数据降阶为可并行折叠的向量点积。 |
| **5. 微内核熔合模式** | Combined Kernel Fusion | 解密+校验导致 L1 Data Cache 和内存带宽双倍消耗 | 将 AES 解密与 CRC32 计算熔合在同一个汇编寄存器循环中，内存访问减少至 **1 趟**。 |
| **6. 跨页 Canary 模式** | Page Fault Guard Canary | SIMD 加载越界读取 (Over-read) 紧贴页边界引发 SIGSEGV | Padding Buffer Canary 规范 + `mmap` `PROT_NONE` 打靶保护，边界平滑切回标量。 |
| **7. 向量模式展开复制模式**| Overlapping Copy Pattern | LZ 算法小 Distance (< Length) 重叠复制导致 C `memcpy` UB | 利用 NEON `vdup` 向量广播填充模式，将短 Distance 展开为 16/32 字节广播复制。 |
| **8. 动态熔断适配器模式** | Circuit Breaker & Fallback Adapter | 新手写汇编在特定微架构或虚拟机崩溃无降级方案 | 环境变量 (`TTZIP_DISABLE_ASM=1`) + Safe Sentinel 机制，瞬时降级切回 Pure C。 |

---

## 5. 跨平台 ABI 与 `arm64inc.S` 规范

### 符号 Mangling 处理
macOS (Mach-O) 下 C 符号带前缀下划线 `_`，Linux (ELF) 下不带前缀。在 `arm64inc.S` 中统一：

```asm
#if defined(__APPLE__)
#  define CSYM(name) _##name
#else
#  define CSYM(name) name
#endif

.macro function name, export=1
    .text
    .align 4
.if \export
    .global CSYM(\name)
.endif
CSYM(\name):
    .cfi_startproc
.endm

.macro endfunc
    .cfi_endproc
.endm
```

### AAPCS64 栈帧与 CFI 指令
每个汇编函数必须保护 Callee-saved 寄存器（`x19`-`x28`, `v8`-`v15` 低 64 位），保持 `sp` 16 字节对齐：

```asm
.macro PROLOGUE_SAVE_X19_X20_FP_LR
    stp     x29, x30, [sp, #-32]!
    .cfi_def_cfa_offset 32
    .cfi_offset x29, -32
    .cfi_offset x30, -24
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    .cfi_offset x19, -16
    .cfi_offset x20, -8
.endm

.macro EPILOGUE_RESTORE_X19_X20_FP_LR
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    .cfi_def_cfa_offset 0
    .cfi_restore x30
    .cfi_restore x29
    ret
.endm
```

---

## 6. CPU 硬件探测与只读派发表

### 全局只读派发表 (`dispatch/ttzip_dispatch_table.h`)

```c
#ifndef TTZIP_DISPATCH_TABLE_H
#define TTZIP_DISPATCH_TABLE_H

#include <stdint.h>
#include <stddef.h>

typedef uint32_t (*ttzip_crc32_fn)(uint32_t crc, const uint8_t *buf, size_t len);
typedef uint32_t (*ttzip_adler32_fn)(uint32_t adler, const uint8_t *buf, size_t len);
typedef size_t   (*ttzip_match_len_fn)(const uint8_t *p1, const uint8_t *p2, size_t limit);
typedef void     (*ttzip_range_encode_bit_fn)(void *rc, uint16_t *prob, int bit);
typedef void     (*ttzip_aes_cbc_dec_fn)(const uint8_t *in, uint8_t *out, size_t len, const void *key, uint8_t *iv);
typedef void     (*ttzip_overlap_copy_fn)(uint8_t *dst, size_t dist, size_t len);

typedef struct {
    ttzip_crc32_fn            crc32;
    ttzip_adler32_fn          adler32;
    ttzip_match_len_fn        match_len;
    ttzip_range_encode_bit_fn range_encode_bit;
    ttzip_aes_cbc_dec_fn      aes_cbc_decrypt;
    ttzip_overlap_copy_fn     overlap_copy;
} ttzip_dispatch_table_t;

extern ttzip_dispatch_table_t g_ttzip_dispatch;

void ttzip_dispatch_init(void);

#endif
```

---

## 7. 跨页安全防越界打靶测试 (`ttzip_asm_page_guard.c`)

通过 `mmap` 分配 2 个连续页，第二页设为 `PROT_NONE`。将测试缓冲区紧贴第二页边界，强制验证汇编算子是否有 SIMD Over-read 触发 `SIGSEGV`：

```c
void ttzip_asm_verify_page_safety(void) {
    long page_size = sysconf(_SC_PAGESIZE);
    uint8_t *pages = mmap(NULL, page_size * 2, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    assert(pages != MAP_FAILED);

    uint8_t *dead_zone = pages + page_size;
    mprotect(dead_zone, page_size, PROT_NONE);

    ttzip_dispatch_init();

    for (size_t len = 1; len <= 64; len++) {
        uint8_t *test_buf = dead_zone - len;
        memset(test_buf, 0x7E, len);
        uint32_t crc = g_ttzip_dispatch.crc32(0, test_buf, len);
        (void)crc;
    }
    munmap(pages, page_size * 2);
}
```

---

## 8. Cycle-Accurate 性能跑分拓扑

基于 ARM64 `cntvct_el0` 测量算子级别的 **Cycles per Byte (CPB)**、**GB/s 吞吐量** 与 **Speedup 倍率**：

$$\text{CPB} = \frac{\text{Elapsed Cycles}}{\text{Total Bytes Transferred}}$$

$$\text{Throughput (GB/s)} = \frac{\text{Total Bytes}}{\text{Elapsed Seconds} \times 10^9}$$

---

## 9. 代码审查铁律与反模式禁令 (Assembly Code Review Rules)

1. **严格尊重 GEMINI.md 冻结文件**：严禁侵入修改 `CTTZipBridge_Crypto.c`, `CTTZipExtract.c` 等冻结代码。
2. **严禁无 CFI 指令的汇编函数**：所有手写 `.S` 函数必须包裹在 `function` 与 `endfunc` 宏中。
3. **严禁破坏 Callee-saved 寄存器**：ARM64 下修改 `x19`-`x28` 或 `v8`-`v15` 低 64 位前必须压栈保存。
4. **严禁无 Fallback 的指令假设**：任何硬件扩展指令（如 `FEAT_AES`, `FEAT_PMULL`）调用前必须在派发表中保留纯 C 标量 Fallback。
5. **严禁忽略边界页保护**：所有 SIMD 向量比较必须通过 `ttzip_asm_page_guard` 防跨页测试。
