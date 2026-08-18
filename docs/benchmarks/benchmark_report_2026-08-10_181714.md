# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 10:17:14 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 562.8 MB/s | 192.2 MB/s | **0.3x** | 447.5 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 761.2 MB/s | 208.4 MB/s | **0.3x** | 506.0 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 273.9 MB/s | 264.7 MB/s | **1.0x** | 583.4 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.6 MB/s | 279.7 MB/s | **1.0x** | 426.1 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 308.6 MB/s | 3945.3 MB/s | **12.8x** | 483.1 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 367.6 MB/s | 1201.5 MB/s | **3.3x** | 291.5 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 319.6 MB/s | 5556.5 MB/s | **17.4x** | 596.4 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 323.1 MB/s | 2081.5 MB/s | **6.4x** | 297.9 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 267.4 MB/s | 213.7 MB/s | **0.8x** | 248.9 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 268.0 MB/s | 209.9 MB/s | **0.8x** | 267.0 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 913.1 MB/s | 277.7 MB/s | **0.3x** | 1167.0 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 784.7 MB/s | 273.3 MB/s | **0.3x** | 698.9 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.5 MB/s | 275.8 MB/s | **1.0x** | 860.7 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.4 MB/s | 277.7 MB/s | **1.0x** | 573.4 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 631.9 MB/s | 1550.7 MB/s | **2.5x** | 889.0 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 618.0 MB/s | 1446.9 MB/s | **2.3x** | 947.2 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.7 MB/s | 1178.9 MB/s | **14.6x** | 842.7 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 81.6 MB/s | 1090.5 MB/s | **13.4x** | 885.8 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1341.9 MB/s | 1016.1 MB/s | **0.8x** | 1268.8 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1031.9 MB/s | 814.9 MB/s | **0.8x** | 1248.5 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 628.7 MB/s | 469.2 MB/s | **0.7x** | 809.4 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 668.6 MB/s | 472.3 MB/s | **0.7x** | 832.7 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 213.7 MB/s | 184.9 MB/s | **0.9x** | 3988.4 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 228.4 MB/s | 186.4 MB/s | **0.8x** | 3173.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 145.9 MB/s | 188.5 MB/s | **1.3x** | 1620.5 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 146.2 MB/s | 189.3 MB/s | **1.3x** | 1490.6 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.5 MB/s | 197.8 MB/s | **2.2x** | 3598.2 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.3 MB/s | 186.5 MB/s | **2.2x** | 1759.5 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.7 MB/s | 156.0 MB/s | **2.1x** | 3583.3 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.9 MB/s | 148.6 MB/s | **2.1x** | 1764.9 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5399.3 MB/s | 1390.5 MB/s | **0.3x** | 6718.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5646.0 MB/s | 1405.3 MB/s | **0.2x** | 6844.5 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1012.5 MB/s | 78.9 MB/s | **0.1x** | 1609.2 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 993.4 MB/s | 78.2 MB/s | **0.1x** | 1639.4 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5385.8 MB/s | 661.4 MB/s | **0.1x** | 5534.6 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5350.4 MB/s | 658.4 MB/s | **0.1x** | 5216.6 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 673.6 MB/s | 665.3 MB/s | **1.0x** | 3653.2 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 670.1 MB/s | 656.1 MB/s | **1.0x** | 3498.1 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1026.6 MB/s | 1634.9 MB/s | **1.6x** | 1731.4 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1024.8 MB/s | 1629.2 MB/s | **1.6x** | 2038.1 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.0 MB/s | 1162.4 MB/s | **12.2x** | 1746.0 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.7 MB/s | 1157.8 MB/s | **12.1x** | 2060.6 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14970.2 MB/s | 1704.1 MB/s | **0.1x** | 6021.9 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10203.8 MB/s | 1273.4 MB/s | **0.1x** | 6413.3 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2029.8 MB/s | 607.2 MB/s | **0.3x** | 1914.6 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2006.3 MB/s | 608.0 MB/s | **0.3x** | 1982.0 MB/s | 0.0 MB/s | **0.0x** |
