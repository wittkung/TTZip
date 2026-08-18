# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:55:41 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 377.9 MB/s | 5536.2 MB/s | **14.6x** | 526.7 MB/s | 1929.3 MB/s | **3.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 381.2 MB/s | 1777.2 MB/s | **4.7x** | 282.7 MB/s | 1732.4 MB/s | **6.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 336.4 MB/s | 5323.0 MB/s | **15.8x** | 546.1 MB/s | 1972.5 MB/s | **3.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 318.7 MB/s | 1967.0 MB/s | **6.2x** | 285.7 MB/s | 1724.0 MB/s | **6.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 595.8 MB/s | 1570.4 MB/s | **2.6x** | 817.2 MB/s | 6462.6 MB/s | **7.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 585.6 MB/s | 1452.4 MB/s | **2.5x** | 857.2 MB/s | 4431.4 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 78.6 MB/s | 1063.7 MB/s | **13.5x** | 816.0 MB/s | 6797.9 MB/s | **8.3x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.7 MB/s | 1070.7 MB/s | **13.4x** | 852.2 MB/s | 4791.1 MB/s | **5.6x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.7 MB/s | 182.7 MB/s | **2.1x** | 3474.9 MB/s | 8182.4 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.7 MB/s | 151.4 MB/s | **1.9x** | 1665.8 MB/s | 2025.1 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.9 MB/s | 138.4 MB/s | **2.0x** | 3358.0 MB/s | 8404.2 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.5 MB/s | 143.9 MB/s | **2.2x** | 1671.7 MB/s | 1709.8 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1002.4 MB/s | 902.0 MB/s | **0.9x** | 1570.2 MB/s | 5036.7 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 968.4 MB/s | 1581.1 MB/s | **1.6x** | 1862.7 MB/s | 8995.9 MB/s | **4.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.7 MB/s | 1088.2 MB/s | **11.9x** | 1626.9 MB/s | 10093.2 MB/s | **6.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.8 MB/s | 1129.0 MB/s | **12.4x** | 1910.7 MB/s | 10798.9 MB/s | **5.7x** |
