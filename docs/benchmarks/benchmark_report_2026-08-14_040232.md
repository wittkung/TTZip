# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 20:02:32 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 475.2 MB/s | 773.4 MB/s | **1.6x** | 563.7 MB/s | 1674.8 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 457.1 MB/s | 748.4 MB/s | **1.6x** | 292.7 MB/s | 1699.6 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 379.9 MB/s | 1030.3 MB/s | **2.7x** | 575.1 MB/s | 2008.5 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 356.7 MB/s | 801.0 MB/s | **2.2x** | 292.9 MB/s | 1717.7 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 649.2 MB/s | 1032.4 MB/s | **1.6x** | 960.8 MB/s | 4702.6 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 622.9 MB/s | 1050.4 MB/s | **1.7x** | 925.1 MB/s | 4662.5 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.6 MB/s | 854.3 MB/s | **11.5x** | 945.8 MB/s | 6779.9 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.1 MB/s | 832.0 MB/s | **11.5x** | 958.2 MB/s | 4610.5 MB/s | **4.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.2 MB/s | 1796.2 MB/s | **20.4x** | 3332.0 MB/s | 8637.4 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.5 MB/s | 849.9 MB/s | **10.7x** | 1789.2 MB/s | 2298.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.7 MB/s | 1847.8 MB/s | **24.7x** | 3386.9 MB/s | 9824.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.8 MB/s | 1021.4 MB/s | **14.6x** | 1583.5 MB/s | 2215.5 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 999.2 MB/s | 547.9 MB/s | **0.5x** | 1686.9 MB/s | 6554.6 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1006.9 MB/s | 549.3 MB/s | **0.5x** | 2047.9 MB/s | 9530.9 MB/s | **4.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 478.4 MB/s | **5.1x** | 1606.7 MB/s | 11763.3 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.2 MB/s | 485.7 MB/s | **5.3x** | 2057.0 MB/s | 11413.8 MB/s | **5.5x** | - |
