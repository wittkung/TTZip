# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 10:32:35 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 456.2 MB/s | 5224.7 MB/s | **11.5x** | 617.2 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 406.3 MB/s | 2064.7 MB/s | **5.1x** | 307.3 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 348.5 MB/s | 4668.2 MB/s | **13.4x** | 597.9 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 335.5 MB/s | 2191.1 MB/s | **6.5x** | 305.0 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 660.7 MB/s | 1608.1 MB/s | **2.4x** | 899.5 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 668.4 MB/s | 1471.1 MB/s | **2.2x** | 1060.0 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 83.6 MB/s | 1203.8 MB/s | **14.4x** | 911.6 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 83.1 MB/s | 1111.0 MB/s | **13.4x** | 943.3 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.6 MB/s | 199.9 MB/s | **2.2x** | 3670.4 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.0 MB/s | 188.4 MB/s | **2.2x** | 1796.6 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.8 MB/s | 158.3 MB/s | **2.1x** | 3600.0 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.6 MB/s | 148.0 MB/s | **2.1x** | 1786.7 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1033.7 MB/s | 1658.9 MB/s | **1.6x** | 1749.6 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1035.0 MB/s | 1647.9 MB/s | **1.6x** | 2074.5 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.0 MB/s | 1156.0 MB/s | **12.2x** | 1729.0 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.4 MB/s | 1118.6 MB/s | **11.9x** | 2003.2 MB/s | 0.0 MB/s | **0.0x** |
