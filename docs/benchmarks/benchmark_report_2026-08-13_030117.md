# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 19:01:17 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1084.3 MB/s | 353.5 MB/s | **0.3x** | 758.1 MB/s | 3510.5 MB/s | **4.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1018.6 MB/s | 399.8 MB/s | **0.4x** | 555.7 MB/s | 4121.1 MB/s | **7.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 300.4 MB/s | 405.6 MB/s | **1.4x** | 622.0 MB/s | 3538.7 MB/s | **5.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.8 MB/s | 411.4 MB/s | **1.4x** | 505.8 MB/s | 3916.7 MB/s | **7.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1348.1 MB/s | 513.8 MB/s | **0.4x** | 2057.9 MB/s | 3917.8 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1175.4 MB/s | 509.6 MB/s | **0.4x** | 926.1 MB/s | 3628.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.4 MB/s | 519.8 MB/s | **1.9x** | 1294.4 MB/s | 3531.1 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 300.0 MB/s | 400.7 MB/s | **1.3x** | 796.9 MB/s | 2818.4 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 235.6 MB/s | 2486.1 MB/s | **10.6x** | 4562.3 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (95.9%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 237.4 MB/s | 2514.3 MB/s | **10.6x** | 3634.4 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.1%) |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 138.2 MB/s | 2472.1 MB/s | **17.9x** | 1738.3 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.2%) |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.8 MB/s | 2498.6 MB/s | **18.1x** | 1617.0 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (96.1%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5111.9 MB/s | 3382.0 MB/s | **0.7x** | 5537.6 MB/s | 7432.0 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5020.7 MB/s | 3353.1 MB/s | **0.7x** | 5029.5 MB/s | 10251.0 MB/s | **2.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 678.2 MB/s | 3331.4 MB/s | **4.9x** | 3642.0 MB/s | 10301.2 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 9 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 682.1 MB/s | 3278.1 MB/s | **4.8x** | 3559.2 MB/s | 10683.6 MB/s | **3.0x** | - |
