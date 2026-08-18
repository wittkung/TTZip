# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 11:04:04 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 743.0 MB/s | 145.6 MB/s | **0.2x** | 377.8 MB/s | 67.7 MB/s | **0.2x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 709.7 MB/s | 260.9 MB/s | **0.4x** | 426.2 MB/s | 402.9 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.4 MB/s | 274.0 MB/s | **1.0x** | 528.7 MB/s | 538.3 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.6 MB/s | 278.8 MB/s | **0.9x** | 452.8 MB/s | 454.0 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 417.1 MB/s | 5402.8 MB/s | **13.0x** | 565.2 MB/s | 2252.6 MB/s | **4.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 404.8 MB/s | 2137.2 MB/s | **5.3x** | 295.7 MB/s | 1930.7 MB/s | **6.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 352.7 MB/s | 5503.5 MB/s | **15.6x** | 597.0 MB/s | 1853.3 MB/s | **3.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 330.0 MB/s | 2100.5 MB/s | **6.4x** | 294.8 MB/s | 1696.6 MB/s | **5.8x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 296.9 MB/s | 226.8 MB/s | **0.8x** | 265.0 MB/s | 217.2 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 286.4 MB/s | 217.5 MB/s | **0.8x** | 216.1 MB/s | 330.0 MB/s | **1.5x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 971.1 MB/s | 280.6 MB/s | **0.3x** | 1243.9 MB/s | 841.0 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 770.8 MB/s | 279.9 MB/s | **0.4x** | 681.4 MB/s | 538.2 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 273.7 MB/s | 279.1 MB/s | **1.0x** | 786.9 MB/s | 784.7 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 270.2 MB/s | 264.1 MB/s | **1.0x** | 560.1 MB/s | 484.0 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 639.1 MB/s | 1477.5 MB/s | **2.3x** | 892.2 MB/s | 4015.3 MB/s | **4.5x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 614.4 MB/s | 1492.9 MB/s | **2.4x** | 988.7 MB/s | 4404.3 MB/s | **4.5x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.3 MB/s | 1163.8 MB/s | **14.5x** | 844.7 MB/s | 6771.0 MB/s | **8.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.9 MB/s | 1094.2 MB/s | **13.5x** | 897.6 MB/s | 4742.4 MB/s | **5.3x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1362.7 MB/s | 956.9 MB/s | **0.7x** | 1360.2 MB/s | 1148.1 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1001.2 MB/s | 820.4 MB/s | **0.8x** | 1228.4 MB/s | 1194.7 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 608.5 MB/s | 449.1 MB/s | **0.7x** | 563.0 MB/s | 1992.3 MB/s | **3.5x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 644.5 MB/s | 462.5 MB/s | **0.7x** | 789.1 MB/s | 1814.5 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 208.5 MB/s | 175.1 MB/s | **0.8x** | 3916.1 MB/s | 1513.7 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 214.2 MB/s | 182.7 MB/s | **0.9x** | 3193.5 MB/s | 1453.4 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 132.3 MB/s | 159.7 MB/s | **1.2x** | 1546.7 MB/s | 1393.6 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 131.3 MB/s | 160.3 MB/s | **1.2x** | 1411.2 MB/s | 1355.4 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.7 MB/s | 176.2 MB/s | **2.2x** | 3071.7 MB/s | 8495.2 MB/s | **2.8x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.1 MB/s | 164.8 MB/s | **2.4x** | 1599.8 MB/s | 1990.5 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 138.2 MB/s | **2.0x** | 3357.6 MB/s | 8025.0 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.2 MB/s | 142.5 MB/s | **2.1x** | 1617.4 MB/s | 2133.5 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4698.0 MB/s | 1097.1 MB/s | **0.2x** | 5249.5 MB/s | 918.0 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4563.7 MB/s | 965.7 MB/s | **0.2x** | 5253.9 MB/s | 1985.8 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 675.7 MB/s | 68.8 MB/s | **0.1x** | 1042.3 MB/s | 3245.7 MB/s | **3.1x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 705.5 MB/s | 52.5 MB/s | **0.1x** | 1045.9 MB/s | 2986.8 MB/s | **2.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5033.8 MB/s | 624.5 MB/s | **0.1x** | 4762.3 MB/s | 3312.4 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4156.6 MB/s | 632.7 MB/s | **0.2x** | 3666.3 MB/s | 3119.9 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 638.8 MB/s | 606.2 MB/s | **0.9x** | 3471.6 MB/s | 3074.7 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 646.9 MB/s | 624.7 MB/s | **1.0x** | 3235.1 MB/s | 3311.4 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 956.1 MB/s | 1488.0 MB/s | **1.6x** | 1515.9 MB/s | 5781.9 MB/s | **3.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 986.9 MB/s | 1571.1 MB/s | **1.6x** | 1983.6 MB/s | 6015.4 MB/s | **3.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.8 MB/s | 1127.1 MB/s | **12.3x** | 1619.1 MB/s | 11084.7 MB/s | **6.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1073.0 MB/s | **11.4x** | 1969.8 MB/s | 6377.6 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14085.6 MB/s | 1779.8 MB/s | **0.1x** | 5102.4 MB/s | 5376.1 MB/s | **1.1x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8866.6 MB/s | 1246.0 MB/s | **0.1x** | 5183.6 MB/s | 5639.9 MB/s | **1.1x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1926.4 MB/s | 597.2 MB/s | **0.3x** | 1807.8 MB/s | 3249.8 MB/s | **1.8x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1907.0 MB/s | 602.9 MB/s | **0.3x** | 1553.7 MB/s | 3274.3 MB/s | **2.1x** |
