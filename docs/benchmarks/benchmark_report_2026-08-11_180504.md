# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-11 10:05:04 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 897.4 MB/s | 283.6 MB/s | **0.3x** | 702.7 MB/s | 532.1 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 871.6 MB/s | 285.1 MB/s | **0.3x** | 535.4 MB/s | 424.6 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.0 MB/s | 272.2 MB/s | **0.9x** | 575.1 MB/s | 558.2 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.1 MB/s | 292.6 MB/s | **1.0x** | 462.7 MB/s | 451.7 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 427.7 MB/s | 6871.5 MB/s | **16.1x** | 594.3 MB/s | 1681.6 MB/s | **2.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 400.0 MB/s | 2185.7 MB/s | **5.5x** | 301.4 MB/s | 1808.5 MB/s | **6.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 347.1 MB/s | 5907.5 MB/s | **17.0x** | 566.0 MB/s | 1938.8 MB/s | **3.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 328.3 MB/s | 2399.5 MB/s | **7.3x** | 302.9 MB/s | 1686.3 MB/s | **5.6x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 222.4 MB/s | 495.5 MB/s | **2.2x** | 261.6 MB/s | 922.6 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 249.1 MB/s | 557.7 MB/s | **2.2x** | 272.8 MB/s | 923.6 MB/s | **3.4x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1095.7 MB/s | 292.6 MB/s | **0.3x** | 1387.0 MB/s | 923.4 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 986.1 MB/s | 287.0 MB/s | **0.3x** | 849.0 MB/s | 643.4 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.9 MB/s | 288.4 MB/s | **1.0x** | 1019.4 MB/s | 960.9 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.6 MB/s | 286.3 MB/s | **1.0x** | 679.1 MB/s | 651.3 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 718.5 MB/s | 1736.1 MB/s | **2.4x** | 1004.0 MB/s | 5461.0 MB/s | **5.4x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 691.4 MB/s | 1561.2 MB/s | **2.3x** | 1104.6 MB/s | 4778.3 MB/s | **4.3x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.3 MB/s | 1266.2 MB/s | **15.8x** | 959.4 MB/s | 5685.6 MB/s | **5.9x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 81.1 MB/s | 1183.1 MB/s | **14.6x** | 1040.9 MB/s | 4997.3 MB/s | **4.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1345.8 MB/s | 1895.0 MB/s | **1.4x** | 1711.5 MB/s | 6056.7 MB/s | **3.5x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1254.8 MB/s | 1538.7 MB/s | **1.2x** | 1570.6 MB/s | 5985.9 MB/s | **3.8x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 640.3 MB/s | 615.8 MB/s | **1.0x** | 592.6 MB/s | 5297.2 MB/s | **8.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 486.1 MB/s | 473.0 MB/s | **1.0x** | 462.3 MB/s | 2501.8 MB/s | **5.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 238.4 MB/s | 178.7 MB/s | **0.7x** | 4083.6 MB/s | 1671.4 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 230.1 MB/s | 178.0 MB/s | **0.8x** | 3215.8 MB/s | 1428.3 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 145.5 MB/s | 186.1 MB/s | **1.3x** | 1649.8 MB/s | 1695.5 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.0 MB/s | 180.8 MB/s | **1.3x** | 1522.7 MB/s | 1465.0 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.8 MB/s | 201.4 MB/s | **2.3x** | 3617.7 MB/s | 5891.9 MB/s | **1.6x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.0 MB/s | 186.2 MB/s | **2.2x** | 1785.6 MB/s | 2228.8 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.7 MB/s | 156.3 MB/s | **2.1x** | 3599.0 MB/s | 6814.6 MB/s | **1.9x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.7 MB/s | 151.6 MB/s | **2.1x** | 1784.6 MB/s | 2243.2 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5378.1 MB/s | 1327.6 MB/s | **0.2x** | 6854.3 MB/s | 5204.6 MB/s | **0.8x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5676.3 MB/s | 1514.0 MB/s | **0.3x** | 6730.6 MB/s | 8203.4 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 981.9 MB/s | 79.9 MB/s | **0.1x** | 1641.4 MB/s | 4888.5 MB/s | **3.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 986.3 MB/s | 79.5 MB/s | **0.1x** | 1581.0 MB/s | 4842.1 MB/s | **3.1x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4928.0 MB/s | 644.5 MB/s | **0.1x** | 5267.5 MB/s | 3281.4 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4868.1 MB/s | 649.6 MB/s | **0.1x** | 4993.2 MB/s | 3494.7 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 660.1 MB/s | 648.1 MB/s | **1.0x** | 3644.2 MB/s | 3397.2 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 657.7 MB/s | 638.5 MB/s | **1.0x** | 3376.5 MB/s | 3455.8 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.7 MB/s | 1640.8 MB/s | **1.6x** | 1717.4 MB/s | 5734.9 MB/s | **3.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1012.3 MB/s | 1639.1 MB/s | **1.6x** | 2035.7 MB/s | 7113.3 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.7 MB/s | 1150.5 MB/s | **12.0x** | 1768.3 MB/s | 10272.7 MB/s | **5.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.2 MB/s | 1127.0 MB/s | **11.7x** | 2036.4 MB/s | 10338.6 MB/s | **5.1x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12119.5 MB/s | 1673.8 MB/s | **0.1x** | 4719.9 MB/s | 5814.4 MB/s | **1.2x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8812.4 MB/s | 1236.1 MB/s | **0.1x** | 5757.2 MB/s | 8048.3 MB/s | **1.4x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2144.6 MB/s | 581.4 MB/s | **0.3x** | 1887.5 MB/s | 2892.7 MB/s | **1.5x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1851.4 MB/s | 600.0 MB/s | **0.3x** | 1763.5 MB/s | 2787.0 MB/s | **1.6x** |
