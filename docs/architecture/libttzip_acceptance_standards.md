# libttzip: 世界级纯 C 核心与全平台实施验收标准体系 (Acceptance Standards)

> **Document Version**: 1.0.0 (Release-Gate Specification)  
> **Status**: Official Engineering Invariant Standards  
> **Scope**: `libttzip` Pure C11 Core + Dual-ISA Vector Kernels + macOS / Windows Native Shells  
> **Last Updated**: 2026-08-20  

---

## 目录索引
1. [维度一：代码纯洁性与跨平台构建验收 (Build & Purity Standards)](#1-维度一代码纯洁性与跨平台构建验收)
2. [维度二：硬件向量微内核与吞吐量底线 (Vectorization & Performance Floors)](#2-维度二硬件向量微内核与吞吐量底线)
3. [维度三：格式标准与系统预言机 100% 兼容性 (Oracle & Bitstream Invariants)](#3-维度三格式标准与系统预言机-100-兼容性)
4. [维度四：跨平台文件系统与极端边界验收 (File System & Memory Boundaries)](#4-维度四跨平台文件系统与极端边界验收)
5. [维度五：内存安全、并发竞态与许可证合规 (Safety, Sanitizers & Licensing)](#5-维度五内存安全并发竞态与许可证合规)
6. [维度六：用户体验、延迟与 GUI 交互验收 (UX, Latency & Responsiveness)](#6-维度六用户体验延迟与-gui-交互验收)

---

## 1. 维度一：代码纯洁性与跨平台构建验收

### 1.1 纯 C 核心依赖隔离标准 (Zero-Leakage Mandate)
- [ ] **GCD 依赖绝对清零**：`libttzip` C 源码中 `grep -rn "dispatch_"` 结果严格为 **0 处**；禁止出现 Apple Blocks 语法 `^{}`。
- [ ] **Swift 依赖绝对清零**：`libttzip` 编译生成产物（`libttzip.a`、`ttzip.dll`）不得链接任何 Swift 运行时库或 Foundation。
- [ ] **标准 C11 遵从**：代码必须在启用 `-std=c11` (GCC/Clang) 和 `/std:c11` (MSVC) 下 100% 编译通过，无任何特定编译器专有扩展未做平台抽象。

### 1.2 跨编译器零告警矩阵 (Zero-Warning Matrix)
所有平台在最高告警级别下必须编译通过（Warnings As Errors）：

| 编译器 | 构建命令 / 平台 | 目标产物 | 验收断言 |
| :--- | :--- | :--- | :--- |
| **Apple Clang** | `cmake -B build -DCMAKE_C_FLAGS="-Wall -Wextra -Werror -Wvla -fvisibility=hidden"` (macOS ARM64/x86_64) | `libttzip.a` + `ttzip-cli` | Exit Code 0, 0 Warnings |
| **MSVC 2022** | `cmake -B build -A x64` `/W4 /WX /utf-8 /guard:cf` (Windows 11 x64) | `ttzip.dll` + `ttzip.lib` + `ttzip-cli.exe` | Exit Code 0, 0 Warnings |
| **MSVC ARM64**| `cmake -B build -A ARM64` `/W4 /WX /utf-8` (Windows on ARM) | `ttzip.dll` + `ttzip-cli.exe` | Exit Code 0, 0 Warnings |
| **GCC 13+** | `cmake -B build -DCMAKE_C_FLAGS="-Wall -Wextra -Werror"` (Ubuntu Linux x64) | `libttzip.so` + `ttzip-cli` | Exit Code 0, 0 Warnings |

---

## 2. 维度二：硬件向量微内核与吞吐量底线

### 2.1 硬件校验与密码学微内核物理吞吐底线

在基准测试机（Apple M3/M4 / AMD Ryzen 9 7950X / Intel Core i9-14900K）上，单核硬件向量路径必须达到以下绝对吞吐底线：

```
ARM64 (Apple Silicon / Snapdragon X Elite):
  • CRC64 (PMULL 4-way vector fold):         >= 45.0 GB/s  (实测目标: 48.16 GB/s)
  • CRC32 (ARMv8 ACLE + 12-way fold):        >= 60.0 GB/s  (实测目标: 65.00 GB/s)
  • Adler-32 (NEON DotProduct, N_max=5552):  >= 25.0 GB/s  (实测目标: 28.50 GB/s)
  • AES-256 (8-way interleaved vaeseq):      >=  4.5 GB/s

x86_64 (Intel / AMD PC):
  • CRC64 (PCLMULQDQ 4-way vector fold):     >= 40.0 GB/s
  • CRC32 (SSE4.2 _mm_crc32_u64 + 12-way):   >= 50.0 GB/s
  • Adler-32 (AVX2 _mm256_maddubs_epi16):    >= 30.0 GB/s
  • AES-256 (AES-NI 8-way _mm_aesenc_si128): >=  5.0 GB/s
```

### 2.2 SOTA 单核与多核压缩吞吐底线

| 算法 | 单核压缩底线 ($f$) | 单核解压底线 | 16 核多核压缩底线 | 相对标量/标准工具加速比 |
| :--- | :--- | :--- | :--- | :--- |
| **Deflate (`libdeflate`)** | $\ge 300\text{ MB/s}$ (L1~L3) | $\ge 1.8\text{ GB/s}$ | $\ge 4,200\text{ MB/s}$ | 较 `pigz`/zlib **+300% (3.0x)** |
| **LZMA2 (`fast-lzma2`)** | $\ge 35\text{ MB/s}$ (L6) | $\ge 120\text{ MB/s}$ | $\ge 450\text{ MB/s}$ | 较标准 `7zz` **+250% (3.5x)** |
| **Zstandard (`libzstd`)** | $\ge 450\text{ MB/s}$ (L1~L3) | $\ge 3.0\text{ GB/s}$ | $\ge 6,000\text{ MB/s}$ | 线性扩展率 $\ge 92\%$ |
| **LZ4 (`liblz4`)** | $\ge 800\text{ MB/s}$ (L1) | $\ge 4.5\text{ GB/s}$ | $\ge 12,000\text{ MB/s}$ | 内存总线打满 |
| **BZIP2 (`libbzip2+divsufsort`)**| $\ge 30\text{ MB/s}$ (L9) | $\ge 35\text{ MB/s}$ | $\ge 400\text{ MB/s}$ | 较标准 `bzip2` **+200% (2.0x)** |

### 2.3 多核扩展率判定准则
$$\text{Parallel Efficiency } \eta = \frac{\text{Throughput}(N \text{ cores})}{N \times \text{Throughput}(1 \text{ core})} \ge 85\% \quad (\text{在 } N=8 \sim 32 \text{ 核下})$$

---

## 3. 维度三：格式标准与系统预言机 100% 兼容性

生成的每一个归档文件必须通过操作系统原生工具与官方权威预言机（Oracles）的双向无损校验：

### 3.1 跨平台系统预言机测试矩阵

| 容器格式 | 校验预言机工具 (External Oracles) | 执行命令 | 验收合格断言 |
| :--- | :--- | :--- | :--- |
| **ZIP / Zip64** | macOS `/usr/bin/unzip`<br>Windows Explorer (资源管理器)<br>Linux `/usr/bin/unzip` | `unzip -t archive.zip`<br>GUI 双击解压<br>`unzip -v archive.zip` | 0 CRC error, 0 warnings, 文件数与大小 100% 吻合 |
| **TAR / PAX** | BSD tar (macOS)<br>GNU tar (Linux)<br>bsdtar (Windows) | `tar -tvf archive.tar`<br>`tar -xzf archive.tar.gz`<br>`tar --zstd -xf archive.tar.zst` | 纳秒 mtime、POSIX 权限与 Extended Attributes (`xattr`) 100% 还原 |
| **7Z / Solid** | 官方 `7zz` CLI (Igor Pavlov)<br>Windows 7-Zip GUI | `7zz t archive.7z`<br>`7zz x archive.7z -o/tmp/` | 100% 测试通过，AES-256 密码解密正确 |
| **DMG (UDIF)** | macOS `/usr/bin/hdiutil` | `hdiutil verify image.dmg`<br>`hdiutil attach image.dmg` | 成功挂载为 APFS/HFS+ 卷，扇区校验和一致 |
| **WIM** | Microsoft `dism.exe`<br>`wimlib-imagex` | `dism /Get-WimInfo /WimFile:image.wim`<br>`wimlib-imagex verify image.wim` | 单实例 SHA-1 校验全部匹配 |

### 3.2 多核位流合规断言
- **Deflate 流**：多核分块压缩生成的 Deflate 流，中间块严格标记 `BFINAL=0`，末尾块严格标记 `BFINAL=1`，严禁在流中间产生孤立的 `BFINAL=1` 块。
- **GZIP 多成员流**：生成的 GZIP 流必须符合 RFC 1952，每个独立 Member 具备完整 10 字节 Header、有效 CRC32 与 ISIZE 尾部。

---

## 4. 维度四：跨平台文件系统与极端边界验收

### 4.1 Windows 32,768 字符超长路径断言
- [ ] **深层路径测试**：自动化测试用例构造目录嵌套层级达 50 层、绝对路径长度达 **1,024 ~ 4,096 字符** 的测试集。
- [ ] **断言**：在 Windows 上通过 `\\?\` 前缀与 `FindFirstFileW` / `CreateFileW` 100% 成功遍历与打包，**零 `ERROR_PATH_NOT_FOUND` 或 `ERROR_FILENAME_EXCED_RANGE`**。

### 4.2 内存映射与大文件流式包络 (Memory Invariant)
- [ ] **50GB+ 大文件压力测试**：在仅具备 8GB 物理内存的设备上，对 50GB 混合文件执行极速压缩。
- [ ] **常驻内存硬上限断言**：通过 `getrusage` / `GetProcessMemoryInfo` 采样，整机常驻物理内存（RSS）**严格保持在 $\le 128\text{MB}$**，杜绝整文件加载（OOM 防御）。

### 4.3 文件系统特殊属性跨平台映射
- [ ] **Symlink 软链接**：POSIX 平台正确存储并还原 `lstat` 符号链接；Windows 平台根据权限正确处理 Reparse Point 或降级为安全文件，**杜绝 Zip Slip 路径穿越**。
- [ ] **UTF-8 与 Unicode 跨平台一致性**：文件名包含多语言（中日韩、阿拉伯语、Emoji 符号 `🚀`、特殊变音符 NFD/NFC）时，打包与解压后文件名哈希完全一致。

---

## 5. 维度五：内存安全、并发竞态与许可证合规

### 5.1 内存安全与 Sanitizers 零容忍门禁
在 CI/CD 自动化流水线中，全套测试用例必须在以下编译检查下通过：
1. **AddressSanitizer (ASan)**：`cmake -DENABLE_ASAN=ON`，运行全格式打包解压，**0 堆缓冲区越界 (Heap Buffer Overflow)、0 栈溢出 (Stack Overflow)、0 Use-After-Free**。
2. **ThreadSanitizer (TSan)**：`cmake -DENABLE_TSAN=ON`，在 32 线程并发压力测试下，**0 数据竞态 (Data Race)、0 死锁 (Deadlock)**。
3. **UndefinedBehaviorSanitizer (UBSan)**：**0 未定义行为（符号整数溢出、空指针解引用、非对齐内存访问）**。
4. **Valgrind / Leaks 检测**：执行完整归档生命周期，**0 内存泄漏 (Direct/Indirect Memory Leaks)**。

### 5.2 敏感密码内存物理擦除安全 (DSE Immunity)
- [ ] **密码擦除汇编断言**：针对 `ttzip_secure_zero()` 生成的目标反汇编代码进行静态扫描，确认包含明确的内存写操作或内存屏障，**未被编译器的死代码消除（Dead-Store Elimination）优化误删**。

### 5.3 许可证 100% 纯洁性门禁 (Zero Copyleft GPL-3)
- [ ] 代码库中严禁包含任何 GPL-3 许可证源码（如 `lbzip2`、`p7zip-full` GPL 代码）。
- [ ] 所有第三方组件许可证必须属于：`MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `Apache-2.0`, `CC0 / Public Domain`。

---

## 6. 维度六：用户体验、延迟与 GUI 交互验收

### 6.1 启动与首帧交互延迟 (Instant Responsiveness)
- [ ] **CLI 冷启动耗时**：`ttzip-cli --version` 与单文件瞬时打包冷启动耗时 **$< 1.0\text{ ms}$**。
- [ ] **GUI 打开归档耗时**：打开包含 100,000 个文件的 ZIP/7Z 归档，解析 Central Directory / Header Stream 生成树形目录并展示首屏耗时 **$< 50\text{ ms}$**。

### 6.2 流式进度与 60 FPS 流畅度
- [ ] **进度回调开销**：C 核心向 GUI 层发送进度通知频率自适应节流（每秒 30~60 次），进度回调引起的 CPU 开销占比 **$< 0.5\%$**。
- [ ] **取消响应延迟**：用户在 GUI 点击“取消”按钮后，线程池在 **$< 50\text{ ms}$** 内安全停止所有分块任务并释放临时锁，恢复主线程交互。

---

## 7. 验收签字与门禁流程 (Release Gate Process)

每个版本发布前必须生成完整的自动化验收报告：

```bash
# 1. 编译并运行跨平台纯 C 单元测试与 Sanitizers 扫描
cmake -B build-asan -DENABLE_ASAN=ON -DENABLE_UBSAN=ON && cmake --build build-asan && ctest --test-dir build-asan --output-on-failure

# 2. 运行系统预言机互操作全格式测试
swift test --filter AllFormatsAndAdvancedParametersMatrixTests

# 3. 运行硬件向量吞吐量基准断言
./build/bin/ttzip-bench --checksum-all --verify-floors

# 4. 验证生成的归档通过系统预言机
/usr/bin/unzip -t output_test.zip
tar -tvf output_test.tar.zst
7zz t output_test.7z
```

**只有上述 6 大维度 100% 绿灯全通过，方可签发生产版本。**
