# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 11:08:19 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 733.0 MB/s | 140.7 MB/s | **0.2x** | 417.4 MB/s | 66.5 MB/s | **0.2x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 739.8 MB/s | 272.5 MB/s | **0.4x** | 441.5 MB/s | 390.0 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 279.1 MB/s | 282.7 MB/s | **1.0x** | 574.7 MB/s | 418.8 MB/s | **0.7x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.2 MB/s | 286.0 MB/s | **1.0x** | 481.1 MB/s | 442.6 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 401.2 MB/s | 5023.8 MB/s | **12.5x** | 617.6 MB/s | 2136.5 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 375.2 MB/s | 2150.2 MB/s | **5.7x** | 298.0 MB/s | 1889.1 MB/s | **6.3x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 329.0 MB/s | 5390.0 MB/s | **16.4x** | 569.3 MB/s | 2282.5 MB/s | **4.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 314.5 MB/s | 2121.4 MB/s | **6.7x** | 298.9 MB/s | 1817.3 MB/s | **6.1x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 294.3 MB/s | 223.2 MB/s | **0.8x** | 272.2 MB/s | 335.6 MB/s | **1.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 286.1 MB/s | 206.8 MB/s | **0.7x** | 274.3 MB/s | 333.9 MB/s | **1.2x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1002.6 MB/s | 285.0 MB/s | **0.3x** | 1213.6 MB/s | 864.9 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 816.9 MB/s | 284.6 MB/s | **0.3x** | 720.6 MB/s | 571.9 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.2 MB/s | 283.0 MB/s | **1.0x** | 888.5 MB/s | 869.7 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.9 MB/s | 278.9 MB/s | **1.0x** | 595.7 MB/s | 570.0 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 640.8 MB/s | 1602.9 MB/s | **2.5x** | 920.4 MB/s | 4691.0 MB/s | **5.1x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 619.5 MB/s | 1467.5 MB/s | **2.4x** | 951.4 MB/s | 4419.3 MB/s | **4.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 81.9 MB/s | 1171.0 MB/s | **14.3x** | 862.1 MB/s | 6545.4 MB/s | **7.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 81.0 MB/s | 1107.0 MB/s | **13.7x** | 906.3 MB/s | 4879.6 MB/s | **5.4x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1386.2 MB/s | 1005.3 MB/s | **0.7x** | 1439.6 MB/s | 1252.7 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1071.1 MB/s | 866.4 MB/s | **0.8x** | 1326.5 MB/s | 1241.8 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 693.4 MB/s | 470.6 MB/s | **0.7x** | 848.1 MB/s | 2172.4 MB/s | **2.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 666.5 MB/s | 470.5 MB/s | **0.7x** | 813.5 MB/s | 2174.2 MB/s | **2.7x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 228.9 MB/s | 185.1 MB/s | **0.8x** | 4060.1 MB/s | 1579.1 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 219.9 MB/s | 132.3 MB/s | **0.6x** | 3177.6 MB/s | 1349.0 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.7 MB/s | 170.7 MB/s | **1.2x** | 1625.9 MB/s | 1558.1 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 133.0 MB/s | 185.4 MB/s | **1.4x** | 1411.4 MB/s | 1457.4 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.8 MB/s | 185.3 MB/s | **2.1x** | 3532.1 MB/s | 8491.5 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.9 MB/s | 183.9 MB/s | **2.2x** | 1743.3 MB/s | 2192.1 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.4 MB/s | 152.5 MB/s | **2.2x** | 3535.6 MB/s | 9123.9 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 65.6 MB/s | 139.4 MB/s | **2.1x** | 1717.4 MB/s | 2154.8 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4691.2 MB/s | 1247.7 MB/s | **0.3x** | 5294.8 MB/s | 1595.6 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5300.7 MB/s | 1302.0 MB/s | **0.2x** | 5995.5 MB/s | 2601.9 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 747.8 MB/s | 73.7 MB/s | **0.1x** | 924.6 MB/s | 3628.5 MB/s | **3.9x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 673.7 MB/s | 74.8 MB/s | **0.1x** | 1180.2 MB/s | 3434.3 MB/s | **2.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4965.1 MB/s | 629.6 MB/s | **0.1x** | 4897.9 MB/s | 3286.6 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5148.8 MB/s | 629.8 MB/s | **0.1x** | 4721.2 MB/s | 3056.6 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 624.6 MB/s | 619.5 MB/s | **1.0x** | 3377.2 MB/s | 3223.1 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 610.7 MB/s | 609.5 MB/s | **1.0x** | 3242.0 MB/s | 2656.6 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 895.6 MB/s | 1370.0 MB/s | **1.5x** | 1436.8 MB/s | 5613.3 MB/s | **3.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 903.1 MB/s | 1370.6 MB/s | **1.5x** | 1770.1 MB/s | 6098.3 MB/s | **3.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.1 MB/s | 1034.3 MB/s | **11.2x** | 1591.2 MB/s | 10018.0 MB/s | **6.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.4 MB/s | 1116.8 MB/s | **12.0x** | 2008.5 MB/s | 7267.9 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11305.5 MB/s | 1529.5 MB/s | **0.1x** | 4630.6 MB/s | 3017.1 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9330.5 MB/s | 1184.0 MB/s | **0.1x** | 5018.0 MB/s | 3065.7 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1632.4 MB/s | 572.8 MB/s | **0.4x** | 691.9 MB/s | 3044.5 MB/s | **4.4x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1783.9 MB/s | 548.3 MB/s | **0.3x** | 1732.6 MB/s | 2958.7 MB/s | **1.7x** |
