# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-11 08:17:33 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 459.9 MB/s | 6265.2 MB/s | **13.6x** | 658.6 MB/s | 1838.3 MB/s | **2.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 410.2 MB/s | 2167.5 MB/s | **5.3x** | 309.6 MB/s | 1709.3 MB/s | **5.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 367.2 MB/s | 7808.2 MB/s | **21.3x** | 622.7 MB/s | 1823.9 MB/s | **2.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 343.0 MB/s | 2333.9 MB/s | **6.8x** | 310.7 MB/s | 1818.6 MB/s | **5.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 785.3 MB/s | 1537.3 MB/s | **2.0x** | 1161.3 MB/s | 4950.0 MB/s | **4.3x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 768.1 MB/s | 1474.4 MB/s | **1.9x** | 1307.4 MB/s | 4459.9 MB/s | **3.4x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.1 MB/s | 1162.9 MB/s | **14.7x** | 1157.0 MB/s | 6327.9 MB/s | **5.5x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.8 MB/s | 1100.2 MB/s | **14.0x** | 1267.4 MB/s | 4788.6 MB/s | **3.8x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.6 MB/s | 197.7 MB/s | **2.2x** | 3967.5 MB/s | 8848.0 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.5 MB/s | 191.6 MB/s | **2.3x** | 1892.7 MB/s | 2253.2 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.7 MB/s | 158.4 MB/s | **2.1x** | 3968.0 MB/s | 5723.4 MB/s | **1.4x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.6 MB/s | 151.0 MB/s | **2.1x** | 1911.7 MB/s | 2231.2 MB/s | **1.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1029.5 MB/s | 1651.2 MB/s | **1.6x** | 1756.5 MB/s | 5535.0 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1034.5 MB/s | 1646.5 MB/s | **1.6x** | 2038.5 MB/s | 8956.9 MB/s | **4.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.8 MB/s | 1163.0 MB/s | **11.9x** | 1755.7 MB/s | 10146.4 MB/s | **5.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.2 MB/s | 1166.8 MB/s | **11.9x** | 2078.6 MB/s | 10404.2 MB/s | **5.0x** |
