# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 06:04:32 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS Version 26.6 (Build 25G72)
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | libdeflate-gzip CLI | 0.07 MB (0.6%) | 0.00 MB (0.0%) | 259.3 MB/s | 3596.0 MB/s | **13.9x** | 279.4 MB/s | 1680.7 MB/s | **6.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | libdeflate-gzip CLI | 0.07 MB (0.6%) | 0.00 MB (0.0%) | 259.5 MB/s | 3784.2 MB/s | **14.6x** | 287.7 MB/s | 1832.1 MB/s | **6.4x** |
| 海量小文件 (10MB/100文件) | 7Z | 9 | 无 | libdeflate-gzip CLI | 0.07 MB (0.6%) | 0.00 MB (0.0%) | 242.6 MB/s | 1449.3 MB/s | **6.0x** | 297.5 MB/s | 1650.4 MB/s | **5.5x** |
| 海量小文件 (10MB/100文件) | 7Z | 9 | AES-256 | libdeflate-gzip CLI | 0.07 MB (0.6%) | 0.00 MB (0.0%) | 243.8 MB/s | 1555.2 MB/s | **6.4x** | 291.4 MB/s | 1702.0 MB/s | **5.8x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | libdeflate-gzip CLI | 0.03 MB (0.4%) | 0.00 MB (0.0%) | 580.6 MB/s | 6891.7 MB/s | **11.9x** | 844.8 MB/s | 6506.5 MB/s | **7.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | libdeflate-gzip CLI | 0.03 MB (0.4%) | 0.00 MB (0.0%) | 575.5 MB/s | 6836.9 MB/s | **11.9x** | 865.2 MB/s | 6798.3 MB/s | **7.9x** |
| 拟真日志文本 (10MB) | 7Z | 9 | 无 | libdeflate-gzip CLI | 0.03 MB (0.3%) | 0.00 MB (0.0%) | 293.8 MB/s | 2086.9 MB/s | **7.1x** | 870.9 MB/s | 6427.1 MB/s | **7.4x** |
| 拟真日志文本 (10MB) | 7Z | 9 | AES-256 | libdeflate-gzip CLI | 0.03 MB (0.3%) | 0.00 MB (0.0%) | 552.1 MB/s | 2107.9 MB/s | **3.8x** | 910.1 MB/s | 6398.8 MB/s | **7.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | libdeflate-gzip CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 196.9 MB/s | 1696.8 MB/s | **8.6x** | 1553.3 MB/s | 5479.8 MB/s | **3.5x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | libdeflate-gzip CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 198.7 MB/s | 1720.4 MB/s | **8.7x** | 1572.2 MB/s | 5636.6 MB/s | **3.6x** |
| 高熵物理Payload (100MB) | 7Z | 9 | 无 | libdeflate-gzip CLI | 100.01 MB (100.0%) | 1.01 MB (1.0%) | 150.0 MB/s | 6446.6 MB/s | **43.0x** | 1570.5 MB/s | 8541.5 MB/s | **5.4x** |
| 高熵物理Payload (100MB) | 7Z | 9 | AES-256 | libdeflate-gzip CLI | 100.01 MB (100.0%) | 1.01 MB (1.0%) | 151.7 MB/s | 6432.9 MB/s | **42.4x** | 1542.7 MB/s | 8114.1 MB/s | **5.3x** |
| 100MB 大文件数据块 (100MB) | 7Z | 1 | 无 | libdeflate-gzip CLI | 0.12 MB (0.1%) | 0.00 MB (0.0%) | 1165.2 MB/s | 10049.9 MB/s | **8.6x** | 1702.5 MB/s | 7796.2 MB/s | **4.6x** |
| 100MB 大文件数据块 (100MB) | 7Z | 1 | AES-256 | libdeflate-gzip CLI | 0.12 MB (0.1%) | 0.00 MB (0.0%) | 1167.5 MB/s | 10101.1 MB/s | **8.7x** | 1702.5 MB/s | 8101.8 MB/s | **4.8x** |
| 100MB 大文件数据块 (100MB) | 7Z | 9 | 无 | libdeflate-gzip CLI | 0.10 MB (0.1%) | 0.00 MB (0.0%) | 844.9 MB/s | 5605.0 MB/s | **6.6x** | 1706.8 MB/s | 9309.6 MB/s | **5.5x** |
| 100MB 大文件数据块 (100MB) | 7Z | 9 | AES-256 | libdeflate-gzip CLI | 0.10 MB (0.1%) | 0.00 MB (0.0%) | 894.7 MB/s | 5600.6 MB/s | **6.3x** | 1690.6 MB/s | 8998.0 MB/s | **5.3x** |
