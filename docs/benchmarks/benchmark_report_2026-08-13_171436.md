# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 09:14:36 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1091.1 MB/s | 338.7 MB/s | **0.3x** | 816.8 MB/s | 2783.9 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1032.2 MB/s | 389.3 MB/s | **0.4x** | 496.7 MB/s | 3832.9 MB/s | **7.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 307.5 MB/s | 395.9 MB/s | **1.3x** | 536.5 MB/s | 3941.4 MB/s | **7.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 303.8 MB/s | 394.8 MB/s | **1.3x** | 438.6 MB/s | 3851.8 MB/s | **8.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1387.6 MB/s | 448.0 MB/s | **0.3x** | 1884.2 MB/s | 3274.4 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1171.3 MB/s | 503.5 MB/s | **0.4x** | 1012.5 MB/s | 3165.3 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 321.3 MB/s | 509.1 MB/s | **1.6x** | 1234.1 MB/s | 4015.4 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 320.8 MB/s | 529.1 MB/s | **1.6x** | 772.5 MB/s | 3927.2 MB/s | **5.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 220.6 MB/s | 2425.0 MB/s | **11.0x** | 4554.4 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (97.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 219.4 MB/s | 2519.8 MB/s | **11.5x** | 3361.1 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (97.5%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 133.0 MB/s | 2439.1 MB/s | **18.3x** | 1688.8 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (97.1%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 132.5 MB/s | 2478.6 MB/s | **18.7x** | 1431.9 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.2%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5491.2 MB/s | 2222.1 MB/s | **0.4x** | 5548.9 MB/s | 7918.4 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5294.0 MB/s | 3297.1 MB/s | **0.6x** | 5100.4 MB/s | 10161.6 MB/s | **2.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 678.0 MB/s | 3278.3 MB/s | **4.8x** | 3513.6 MB/s | 9707.4 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 675.0 MB/s | 3283.2 MB/s | **4.9x** | 3695.9 MB/s | 9952.2 MB/s | **2.7x** | - |
