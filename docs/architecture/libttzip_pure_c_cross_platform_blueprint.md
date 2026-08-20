# libttzip: 世界级纯 C 核心与全平台 (macOS + Windows) 架构蓝图

> **Status**: Approved Architecture Blueprint  
> **Target**: Cross-Platform Pure C11 Core Engine (`libttzip`) + Thin Native UI Shells  
> **Authors**: TTZip Architecture & Systems Engineering Team  
> **Last Updated**: 2026-08-20  

---

## 1. 战略动机与现状物理审计

### 1.1 现状物理度量与诊断
经对当前代码库的精确物理审计，系统代码分布如下：

| 指标 | 物理数值 | 架构含义 |
| :--- | :--- | :--- |
| **Swift 层 (`TTZipCore`) 文件数** | **348 个 `.swift`** | 包含 95 个顶级条目、48 个子目录，承载了大量压缩编排与格式封装 |
| **Swift 层代码行数** | **~68,700 行** | 占总代码库代码量约 **65%** |
| **C 层 (`CTTZipBridge`) 文件数** | **254 个 `.c`/`.h`** | 涵盖 `fast-lzma2`, `lzfse`, `zopfli`, `snappy`, `native_deflate` |
| **C 层代码行数** | **~36,869 行** | 占总代码库代码量约 **35%** |
| **C 层硬绑定 GCD (`dispatch_*`)** | **13 个文件，40+ 处** | 使用 Apple Blocks 语法 `^{}`，在 Windows/Linux 上无法编译 |
| **C 层 `pthreads` 引用** | **120+ 处** | `pthread_mutex`, `pthread_cond`, `pthread_key` 缺少 Windows 原生抽象 |
| **C 层 `mmap` 文件** | **10+ 个** | 缺少 Windows `CreateFileMapping` / `MapViewOfFile` 映射 |
| **Swift 层 Apple 独占 API** | **`import AppKit`(4处), `import Security`(4处)** | 无 `#if canImport` 条件防护，跨平台编译断裂 |
| **CPU 特征检测状态** | **检测框架已就绪但空转** | `ttzip_platform_detect.c` 已能检测 x86 PCLMUL/AVX2，但无底层 SIMD 消费 |
| **已有跨平台骨架 (可复用)** | `ttzip_platform.h` + `ttzip_windows.h` | 具备 Win/Mac/Linux 三平台宏、对齐分配、TLS、Prefetch、高精度计时 |

### 1.2 架构转型的第一性原理
1. **跨平台可行性**：Swift 在 Windows 上的 Foundation 运行时功能残缺且不稳定。世界级跨平台软件（7-Zip、WinRAR、zstd、libarchive）无一例外将所有编排、容器封装、分块调度与算法下沉至 **Pure C/C++**。
2. **性能乘积公式**：
   $$\text{Total Throughput} = \text{Single-Core Throughput}(f) \times N_{\text{cores}} \times \eta_{\text{parallel}}$$
   单核微架构 SOTA 引擎（`libdeflate`, `fast-lzma2`, `zstd`, `lz4`, `c-blosc2`）加上跨平台自研无锁线程池与字典预热，在 Windows 与 macOS 上均能实现对传统工具的性能降维打击。

---

## 2. 目标架构模型：`libttzip` 统一纯 C 引擎

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                             libttzip: 纯 C11 核心归档与压缩引擎库                                │
│                     (静态库 libttzip.a / 动态库 ttzip.dll / 动态库 libttzip.so)                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Layer 3: Public C API (稳定、无外部依赖的版本化 C ABI: `include/ttzip_api.h`)                    │
│   • ttzip_archive_create(config, input_paths, output_path, progress_cb)                         │
│   • ttzip_archive_extract(archive_path, output_dir, extract_options, progress_cb)               │
│   • ttzip_archive_list(archive_path, entry_callback, user_data)                                  │
│   • ttzip_archive_test(archive_path, test_options, progress_cb)                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Layer 2: Container Framing & Demuxing Plane (全容器元数据封装与解复用层)                         │
│   ├── ZIP / Zip64 Engine (Local Header / Central Directory / WinZip AES-256)                    │
│   ├── 7Z Engine (Start Header / Coders DAG / Solid Stream / Encrypted Header)                    │
│   ├── TAR PAX Engine (POSIX.1-2001 512B Blocks / Extended Attributes / xattr)                    │
│   ├── GZIP / XZ / ZSTD / BZIP2 / LZ4 / Brotli Stream Framing                                     │
│   ├── Disk Images & Virtual Sectors (Apple UDIF DMG, Microsoft WIM, ISO 9660)                    │
│   └── File System Abstraction (`ttzip_fs.h`: POSIX vs Win32 FindFirstFileW / Long Path)         │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Layer 1: Universal Parallel Scheduler & Memory Engine (通用多核调度与内存引擎)                   │
│   ├── ttzip_threadpool: 自研 C11 无锁任务窃取线程池 (POSIX pthread / Win32 ThreadPool API)      │
│   ├── ttzip_dict_overlap: 环形只读视图 (Zero-Copy Sliding Ring Buffer View, 32KB~2MB)           │
│   ├── ttzip_bitstream_sequencer: 格式感知位流汇聚器 (RFC 1951 Deflate BFINAL 管理)               │
│   ├── ttzip_dual_track: 双轨自适应调度 (小文件 File-Level Pool vs 大文件 Chunk-Level Pool)      │
│   └── ttzip_memory_pool: 页对齐飞地内存池 (posix_memalign / _aligned_malloc, 严格 <= 64~128MB)   │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Layer 0: Portable SOTA Single-Core Codecs & Dual-ISA SIMD (单核极限微内核与双架构向量化)         │
│   ├── Deflate: libdeflate (SWAR + Flat Cache Hash + 12b Direct Huffman)                          │
│   ├── LZMA2: fast-lzma2 (Buffered Radix Match Finder 提速 3.5x)                                  │
│   ├── Zstandard: libzstd (tANS/FSE 有限状态熵 + 4流哈夫曼 + LDM)                                 │
│   ├── LZ4 / Snappy: liblz4 (SIMD Wildcopy) + google/snappy (Byte-Aligned Tag)                    │
│   ├── BZIP2: libbzip2 (BSD-like) + libdivsufsort (MIT 许可证高速后缀数组排序)                   │
│   ├── Brotli / LZFSE: google/brotli (120KB 静态字典) + lzfse (4状态交织 FSE)                     │
│   ├── Filters: Blosc2 Byte-Shuffle + Bit-Shuffle + Charlie Zender Bit-Grooming (浮点量化)        │
│   └── Dual-ISA SIMD Hardware Kernels (运行时 CPU 特征动态分发):                                  │
│       • CRC64: ARM64 PMULL (`vmull_p64` @ 48.16 GB/s) ⟷ x86_64 PCLMULQDQ (`_mm_clmulepi64`)     │
│       • CRC32: ARMv8 ACLE (`__crc32d` @ 65 GB/s) ⟷ x86_64 SSE4.2 (`_mm_crc32_u64`)             │
│       • Adler-32: ARM NEON (`vdotq_u32` @ 28 GB/s) ⟷ x86_64 AVX2 (`_mm256_maddubs_epi16`)      │
│       • AES-256: ARMv8 Crypto (`vaeseq_u8` 8路交织) ⟷ x86_64 AES-NI (`_mm_aesenc_si128` 8路)     │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
                                   │
                  ┌────────────────┴────────────────┐
                  ▼                                 ▼
       ┌─────────────────────┐           ┌─────────────────────┐
       │ macOS Native GUI    │           │ Windows Native GUI  │
       │ Swift 6 + SwiftUI   │           │ C++ / WinUI 3 或    │
       │ / AppKit 薄壳       │           │ C# (.NET 8) + WPF   │
       │ (~5,000 行纯 UI)    │           │ (~5,000 行纯 UI)    │
       └─────────────────────┘           └─────────────────────┘
```

---

## 3. 核心子系统详细技术设计

### 3.1 跨平台线程池 (`ttzip_threadpool.c`)
彻底废除对 Apple GCD（`dispatch_*`）的依赖，使用自研轻量级线程池：
* **POSIX (macOS / Linux)**：基于 `pthread_create`, `pthread_mutex_t`, `pthread_cond_t`。
* **Windows (Win32)**：基于 Windows 原生线程池 API (`CreateThreadpoolWork`, `SubmitThreadpoolWork`) 或 `_beginthreadex` + `CRITICAL_SECTION` + `CONDITION_VARIABLE`。
* **统一 C ABI**：
  ```c
  typedef struct ttzip_threadpool ttzip_threadpool_t;
  typedef void (*ttzip_task_fn)(void* arg);

  ttzip_threadpool_t* ttzip_threadpool_create(uint32_t num_threads);
  int                 ttzip_threadpool_submit(ttzip_threadpool_t* pool, ttzip_task_fn fn, void* arg);
  void                ttzip_threadpool_wait_all(ttzip_threadpool_t* pool);
  void                ttzip_threadpool_destroy(ttzip_threadpool_t* pool);
  ```

### 3.2 双 ISA 硬件向量微内核 (`ttzip_hardware_dispatch.c`)
在 `ttzip_platform_detect.c` 已有的 CPU 特征检测基础上，实现运行时多态分发：

```c
// ttzip_crc64.c
uint64_t ttzip_crc64(const uint8_t* buf, size_t len, uint64_t crc) {
#if defined(__aarch64__) || defined(_M_ARM64)
    if (ttzip_cpu_has_feature(TTZIP_CPU_FEAT_ARM_PMULL)) {
        return ttzip_crc64_arm64_pmull(buf, len, crc); // 48.16 GB/s
    }
#elif defined(__x86_64__) || defined(_M_X64)
    if (ttzip_cpu_has_feature(TTZIP_CPU_FEAT_X86_PCLMULQDQ)) {
        return ttzip_crc64_x86_pclmul(buf, len, crc);  // 40.0+ GB/s
    }
#endif
    return ttzip_crc64_scalar_slice8(buf, len, crc);    // 标量回退 (1.4 GB/s)
}
```

### 3.3 跨平台文件系统与长路径处理 (`ttzip_fs.c`)
* **路径与编码**：POSIX 平台原生处理 UTF-8；Windows 平台统一转换为 UTF-16 并自动追加 `\\?\` 前缀（突破 `MAX_PATH=260` 限制，支持最大 32,768 字符深度路径）。
* **内存映射 I/O**：
  * POSIX: `open()` + `mmap()` + `posix_madvise(MADV_SEQUENTIAL | MADV_WILLNEED)`。
  * Windows: `CreateFileW()` + `CreateFileMappingW()` + `MapViewOfFile()` + `PrefetchVirtualMemory()`。

### 3.4 许可证绝对合规体系 (License Compliance)
* **剔除 GPL 传染源**：全面放弃 `lbzip2`（GPL-3）。采用 `libbzip2` (BSD-like) 搭配 MIT 许可证的 `libdivsufsort` 后缀数组排序算法，实现同等性能且完全无传染风险。
* **纯合规技术栈**：
  * `libdeflate`: MIT
  * `fast-lzma2`: BSD-3-Clause
  * `libzstd`: BSD-3-Clause
  * `liblz4`: BSD-2-Clause
  * `google/brotli`: MIT
  * `google/snappy`: BSD-3-Clause
  * `lzfse`: BSD-3-Clause
  * `c-blosc2`: BSD-3-Clause
  * `xxHash`: BSD-2-Clause
  * `libarchive`: BSD-2-Clause

---

## 4. 四阶段实施路线图 (Execution Roadmap)

### Phase 1: 基础设施去 GCD 与双 ISA 补全 (Infrastructure & Portability)
1. 实现跨平台自研 C 线程池 `ttzip_threadpool.c`，在 C 层逐步替换 13 个文件中的 40+ 处 `dispatch_*`。
2. 补齐 x86_64 硬件向量加速内核：CRC64 PCLMULQDQ、CRC32 SSE4.2、Adler-32 AVX2、AES-NI 8路流水线。
3. 实现跨平台文件系统抽象 `ttzip_fs.c`（POSIX 与 Win32 长路径及 mmap 抽象）。

### Phase 2: 容器封装与归档编排下沉 (Container & Engine Sinking)
1. 将 ZIP/Zip64 完整创建与解析下沉至 `ttzip_zip.c`。
2. 将 7Z Solid/Coders DAG 创建与解析下沉至 `ttzip_7z.c`。
3. 将 TAR PAX 流式打包下沉至 `ttzip_tar.c`。
4. 导出稳定版本化 C ABI `include/ttzip_api.h`。

### Phase 3: Swift 瘦身与全链路联调 (macOS Thin-Shell Refactor)
1. 将 `TTZipCore` 中重复的 Swift 容器和调度代码精简，重构为直接绑定 `libttzip.a` 的薄壳。
2. 运行现有测试矩阵 (`AllFormatsAndAdvancedParametersMatrixTests`, `CRC64HardwareTests`) 验证 100% 回归通过。

### Phase 4: Windows 原生构建与 GUI 交付 (Windows Port & Native UI)
1. 完善 `CMakeLists.txt` 构建 `ttzip.dll` 与 `ttzip-cli.exe`。
2. 构建基于 WinUI 3 (C++) 或 WPF (.NET 8 C#) 的 Windows 原生现代化界面。
