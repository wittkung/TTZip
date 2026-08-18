# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 20:32:16 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 394.5 MB/s | 1166.6 MB/s | **3.0x** | 580.3 MB/s | 1584.3 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 384.4 MB/s | 872.6 MB/s | **2.3x** | 295.2 MB/s | 1804.7 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 336.3 MB/s | 1230.3 MB/s | **3.7x** | 588.4 MB/s | 1991.5 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 320.4 MB/s | 887.8 MB/s | **2.8x** | 298.3 MB/s | 1728.4 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 646.3 MB/s | 1677.2 MB/s | **2.6x** | 940.8 MB/s | 4399.3 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 629.0 MB/s | 1569.3 MB/s | **2.5x** | 982.6 MB/s | 4312.6 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.9 MB/s | 1237.4 MB/s | **16.3x** | 907.3 MB/s | 6248.5 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.5 MB/s | 1108.1 MB/s | **14.5x** | 989.2 MB/s | 4477.7 MB/s | **4.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.8 MB/s | 184.7 MB/s | **2.1x** | 3420.5 MB/s | 9590.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.8 MB/s | 173.8 MB/s | **2.1x** | 1731.8 MB/s | 2195.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.3 MB/s | 145.3 MB/s | **2.0x** | 3586.7 MB/s | 10034.5 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.8 MB/s | 139.7 MB/s | **2.0x** | 1782.2 MB/s | 2242.0 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1005.1 MB/s | 1811.3 MB/s | **1.8x** | 1718.8 MB/s | 7169.1 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 964.1 MB/s | 1806.5 MB/s | **1.9x** | 1872.5 MB/s | 10085.4 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.4 MB/s | 1222.2 MB/s | **13.1x** | 1582.4 MB/s | 11898.0 MB/s | **7.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.6 MB/s | 1143.2 MB/s | **12.2x** | 2047.6 MB/s | 11129.6 MB/s | **5.4x** | - |
