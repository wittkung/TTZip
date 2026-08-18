# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 10:24:20 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1023.3 MB/s | 293.4 MB/s | **0.3x** | 769.9 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 898.6 MB/s | 290.7 MB/s | **0.3x** | 533.8 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.2 MB/s | 290.6 MB/s | **1.0x** | 626.4 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.2 MB/s | 288.8 MB/s | **1.0x** | 503.6 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 447.6 MB/s | 4894.5 MB/s | **10.9x** | 620.4 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 419.8 MB/s | 2237.0 MB/s | **5.3x** | 307.8 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 351.1 MB/s | 5090.1 MB/s | **14.5x** | 610.7 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 329.6 MB/s | 2192.8 MB/s | **6.7x** | 306.0 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 296.9 MB/s | 222.1 MB/s | **0.7x** | 265.1 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 219.0 MB/s | 225.4 MB/s | **1.0x** | 284.1 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1068.4 MB/s | 170.6 MB/s | **0.2x** | 1341.4 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 880.8 MB/s | 288.1 MB/s | **0.3x** | 736.2 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 277.4 MB/s | 281.5 MB/s | **1.0x** | 856.7 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 276.1 MB/s | 274.1 MB/s | **1.0x** | 581.9 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 633.0 MB/s | 1626.9 MB/s | **2.6x** | 908.1 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 616.2 MB/s | 1475.0 MB/s | **2.4x** | 940.6 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.0 MB/s | 1153.3 MB/s | **14.4x** | 832.2 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.7 MB/s | 1078.2 MB/s | **13.4x** | 904.8 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 978.3 MB/s | 702.5 MB/s | **0.7x** | 1125.9 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 788.5 MB/s | 643.3 MB/s | **0.8x** | 1031.8 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 578.0 MB/s | 378.9 MB/s | **0.7x** | 603.8 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 586.7 MB/s | 375.1 MB/s | **0.6x** | 503.3 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 221.1 MB/s | 147.0 MB/s | **0.7x** | 4032.5 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 216.7 MB/s | 187.1 MB/s | **0.9x** | 3195.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 148.3 MB/s | 185.7 MB/s | **1.3x** | 1632.4 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 146.7 MB/s | 189.3 MB/s | **1.3x** | 1499.4 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.4 MB/s | 194.6 MB/s | **2.2x** | 3688.7 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.5 MB/s | 186.8 MB/s | **2.3x** | 1773.3 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.3 MB/s | 157.3 MB/s | **2.1x** | 3652.9 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.0 MB/s | 149.5 MB/s | **2.1x** | 1785.5 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5465.7 MB/s | 1387.7 MB/s | **0.3x** | 6738.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5471.5 MB/s | 1404.8 MB/s | **0.3x** | 7022.3 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1016.6 MB/s | 77.8 MB/s | **0.1x** | 1616.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 987.7 MB/s | 79.0 MB/s | **0.1x** | 1648.6 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5327.5 MB/s | 663.9 MB/s | **0.1x** | 5597.3 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5223.0 MB/s | 658.6 MB/s | **0.1x** | 5164.8 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 675.0 MB/s | 663.8 MB/s | **1.0x** | 3794.8 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 677.8 MB/s | 661.6 MB/s | **1.0x** | 3561.0 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1027.7 MB/s | 1648.4 MB/s | **1.6x** | 1724.4 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1026.1 MB/s | 1626.4 MB/s | **1.6x** | 2059.6 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.9 MB/s | 1158.3 MB/s | **12.1x** | 1759.4 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.2 MB/s | 1167.7 MB/s | **12.0x** | 2111.3 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15565.6 MB/s | 1832.3 MB/s | **0.1x** | 6168.5 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10567.9 MB/s | 1350.1 MB/s | **0.1x** | 7015.1 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2104.1 MB/s | 613.4 MB/s | **0.3x** | 1965.1 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2036.2 MB/s | 611.2 MB/s | **0.3x** | 1960.0 MB/s | 0.0 MB/s | **0.0x** |
