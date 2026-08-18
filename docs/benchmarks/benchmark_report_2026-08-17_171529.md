# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-17 09:15:29 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6.1（版号25G76）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 385.1 MB/s | 6854.4 MB/s | **17.8x** | 624.3 MB/s | 2282.9 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 537.7 MB/s | 2278.1 MB/s | **4.2x** | 315.4 MB/s | 2083.9 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 446.3 MB/s | 6058.8 MB/s | **13.6x** | 601.7 MB/s | 2515.2 MB/s | **4.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 405.9 MB/s | 2104.5 MB/s | **5.2x** | 309.4 MB/s | 2091.4 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 628.2 MB/s | 1853.1 MB/s | **2.9x** | 905.2 MB/s | 8144.1 MB/s | **9.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 595.7 MB/s | 1719.1 MB/s | **2.9x** | 912.1 MB/s | 5428.1 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 84.4 MB/s | 1024.4 MB/s | **12.1x** | 921.7 MB/s | 8281.5 MB/s | **9.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 84.8 MB/s | 967.9 MB/s | **11.4x** | 978.0 MB/s | 5838.7 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.1 MB/s | 178.6 MB/s | **2.0x** | 4199.2 MB/s | 8828.3 MB/s | **2.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.8 MB/s | 182.2 MB/s | **2.1x** | 1676.1 MB/s | 2413.8 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.1 MB/s | 146.3 MB/s | **2.0x** | 3636.4 MB/s | 11765.1 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.4 MB/s | 128.6 MB/s | **1.8x** | 1788.2 MB/s | 2451.0 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1075.4 MB/s | 1894.4 MB/s | **1.8x** | 1816.2 MB/s | 8365.8 MB/s | **4.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1088.4 MB/s | 1925.2 MB/s | **1.8x** | 2186.6 MB/s | 11297.3 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.2 MB/s | 1079.0 MB/s | **11.0x** | 1739.8 MB/s | 13100.9 MB/s | **7.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.6 MB/s | 1068.4 MB/s | **10.8x** | 2197.1 MB/s | 12950.7 MB/s | **5.9x** | - |
