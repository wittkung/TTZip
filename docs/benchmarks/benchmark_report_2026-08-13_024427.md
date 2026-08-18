# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 18:44:27 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1053.7 MB/s | 270.8 MB/s | **0.3x** | 799.6 MB/s | 3500.4 MB/s | **4.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 995.7 MB/s | 401.8 MB/s | **0.4x** | 620.5 MB/s | 3669.1 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 296.7 MB/s | 416.4 MB/s | **1.4x** | 712.2 MB/s | 3283.7 MB/s | **4.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.8 MB/s | 404.5 MB/s | **1.4x** | 537.4 MB/s | 3449.1 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1316.2 MB/s | 531.9 MB/s | **0.4x** | 2049.5 MB/s | 3556.9 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1156.8 MB/s | 524.3 MB/s | **0.5x** | 1062.5 MB/s | 3163.2 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 308.5 MB/s | 528.7 MB/s | **1.7x** | 1275.3 MB/s | 3515.3 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 299.2 MB/s | 527.4 MB/s | **1.8x** | 813.0 MB/s | 3465.1 MB/s | **4.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 217.1 MB/s | 2354.2 MB/s | **10.8x** | 4046.1 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (94.5%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 218.4 MB/s | 2377.8 MB/s | **10.9x** | 3248.4 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.9%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 127.9 MB/s | 2366.2 MB/s | **18.5x** | 1735.0 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.7%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 128.6 MB/s | 2422.2 MB/s | **18.8x** | 1519.6 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4844.6 MB/s | 3267.7 MB/s | **0.7x** | 4953.3 MB/s | 6610.6 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4921.3 MB/s | 3363.5 MB/s | **0.7x** | 4720.5 MB/s | 8974.6 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 667.0 MB/s | 3299.6 MB/s | **4.9x** | 3680.0 MB/s | 8751.1 MB/s | **2.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 667.6 MB/s | 3251.1 MB/s | **4.9x** | 3432.0 MB/s | 9411.1 MB/s | **2.7x** | - |
