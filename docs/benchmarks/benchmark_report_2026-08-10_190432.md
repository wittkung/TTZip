# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 11:04:32 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 435.6 MB/s | 5123.4 MB/s | **11.8x** | 509.8 MB/s | 1403.6 MB/s | **2.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 430.7 MB/s | 1817.1 MB/s | **4.2x** | 276.8 MB/s | 1643.6 MB/s | **5.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 356.7 MB/s | 5412.8 MB/s | **15.2x** | 506.6 MB/s | 1577.4 MB/s | **3.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 335.0 MB/s | 1974.8 MB/s | **5.9x** | 269.6 MB/s | 1602.9 MB/s | **5.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 575.7 MB/s | 1346.7 MB/s | **2.3x** | 733.6 MB/s | 4177.7 MB/s | **5.7x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 562.5 MB/s | 1398.9 MB/s | **2.5x** | 779.5 MB/s | 4253.6 MB/s | **5.5x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 77.3 MB/s | 1131.6 MB/s | **14.6x** | 736.0 MB/s | 6071.8 MB/s | **8.3x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 75.1 MB/s | 941.7 MB/s | **12.5x** | 819.8 MB/s | 3117.5 MB/s | **3.8x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.7 MB/s | 181.3 MB/s | **2.1x** | 3313.8 MB/s | 8172.0 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.4 MB/s | 179.3 MB/s | **2.3x** | 1648.5 MB/s | 2181.0 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.3 MB/s | 147.3 MB/s | **2.1x** | 3160.7 MB/s | 8777.7 MB/s | **2.8x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 66.8 MB/s | 141.2 MB/s | **2.1x** | 1684.5 MB/s | 2147.1 MB/s | **1.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 956.7 MB/s | 1463.2 MB/s | **1.5x** | 1531.9 MB/s | 5934.2 MB/s | **3.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 991.0 MB/s | 1478.3 MB/s | **1.5x** | 1960.6 MB/s | 8939.1 MB/s | **4.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1137.9 MB/s | **12.1x** | 1486.7 MB/s | 10341.1 MB/s | **7.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.1 MB/s | 1157.1 MB/s | **11.7x** | 2090.4 MB/s | 9834.1 MB/s | **4.7x** |
