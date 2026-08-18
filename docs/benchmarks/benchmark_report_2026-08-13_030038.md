# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 19:00:38 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1106.9 MB/s | 276.7 MB/s | **0.3x** | 560.7 MB/s | 3515.7 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1009.2 MB/s | 362.3 MB/s | **0.4x** | 582.0 MB/s | 3742.6 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 299.2 MB/s | 377.9 MB/s | **1.3x** | 675.2 MB/s | 3644.1 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.8 MB/s | 288.2 MB/s | **1.0x** | 511.7 MB/s | 3685.3 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1357.6 MB/s | 501.8 MB/s | **0.4x** | 2096.0 MB/s | 3431.9 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1086.6 MB/s | 434.5 MB/s | **0.4x** | 855.8 MB/s | 2896.8 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 313.7 MB/s | 482.2 MB/s | **1.5x** | 1331.1 MB/s | 3576.9 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 308.5 MB/s | 491.0 MB/s | **1.6x** | 824.9 MB/s | 3466.5 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 239.6 MB/s | 2434.9 MB/s | **10.2x** | 4577.7 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (94.3%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 238.0 MB/s | 2445.8 MB/s | **10.3x** | 3267.0 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.3%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.9 MB/s | 2479.9 MB/s | **18.1x** | 1823.9 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.2%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 138.1 MB/s | 2529.6 MB/s | **18.3x** | 1636.7 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.1%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5145.4 MB/s | 3400.0 MB/s | **0.7x** | 5661.0 MB/s | 7374.2 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5156.9 MB/s | 3336.7 MB/s | **0.6x** | 5333.6 MB/s | 10005.6 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 681.1 MB/s | 3374.8 MB/s | **5.0x** | 3800.4 MB/s | 10568.6 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 681.7 MB/s | 3406.2 MB/s | **5.0x** | 3556.8 MB/s | 10233.3 MB/s | **2.9x** | - |
