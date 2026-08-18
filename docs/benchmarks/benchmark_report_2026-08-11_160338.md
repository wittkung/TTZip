# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-11 08:03:38 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1004.2 MB/s | 291.2 MB/s | **0.3x** | 789.8 MB/s | 605.1 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 945.2 MB/s | 290.2 MB/s | **0.3x** | 596.7 MB/s | 466.5 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.8 MB/s | 291.2 MB/s | **1.0x** | 652.3 MB/s | 572.2 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.8 MB/s | 289.9 MB/s | **1.0x** | 508.5 MB/s | 464.1 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 442.4 MB/s | 6154.1 MB/s | **13.9x** | 606.9 MB/s | 2068.5 MB/s | **3.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 381.9 MB/s | 2287.7 MB/s | **6.0x** | 295.6 MB/s | 1901.4 MB/s | **6.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 335.7 MB/s | 6410.1 MB/s | **19.1x** | 588.0 MB/s | 1589.2 MB/s | **2.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 335.6 MB/s | 2317.1 MB/s | **6.9x** | 307.2 MB/s | 1837.5 MB/s | **6.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 291.7 MB/s | 228.1 MB/s | **0.8x** | 258.3 MB/s | 366.1 MB/s | **1.4x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 301.3 MB/s | 228.9 MB/s | **0.8x** | 266.6 MB/s | 351.1 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1051.7 MB/s | 285.0 MB/s | **0.3x** | 1291.2 MB/s | 901.7 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 868.9 MB/s | 288.5 MB/s | **0.3x** | 743.9 MB/s | 573.8 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.8 MB/s | 287.6 MB/s | **1.0x** | 935.1 MB/s | 889.3 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 281.5 MB/s | 283.2 MB/s | **1.0x** | 603.2 MB/s | 557.1 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 677.1 MB/s | 1681.3 MB/s | **2.5x** | 917.8 MB/s | 5574.3 MB/s | **6.1x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 662.6 MB/s | 1543.8 MB/s | **2.3x** | 986.8 MB/s | 3577.6 MB/s | **3.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 86.7 MB/s | 1236.1 MB/s | **14.3x** | 901.8 MB/s | 6691.3 MB/s | **7.4x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 85.6 MB/s | 1094.2 MB/s | **12.8x** | 943.7 MB/s | 4320.0 MB/s | **4.6x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1399.5 MB/s | 940.3 MB/s | **0.7x** | 1288.8 MB/s | 1286.3 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1083.9 MB/s | 864.8 MB/s | **0.8x** | 1340.0 MB/s | 1277.8 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 720.2 MB/s | 477.7 MB/s | **0.7x** | 797.7 MB/s | 2085.7 MB/s | **2.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 727.8 MB/s | 480.2 MB/s | **0.7x** | 836.1 MB/s | 1970.3 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 232.3 MB/s | 173.3 MB/s | **0.7x** | 3931.3 MB/s | 1519.8 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 227.5 MB/s | 180.7 MB/s | **0.8x** | 3118.5 MB/s | 1384.7 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.4 MB/s | 185.7 MB/s | **1.3x** | 1612.9 MB/s | 1587.9 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.4 MB/s | 177.4 MB/s | **1.2x** | 1496.3 MB/s | 1467.8 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.2 MB/s | 200.9 MB/s | **2.3x** | 3540.6 MB/s | 8878.7 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.5 MB/s | 183.0 MB/s | **2.2x** | 1764.1 MB/s | 2212.9 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.1 MB/s | 149.5 MB/s | **2.0x** | 3642.3 MB/s | 8558.5 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.3 MB/s | 147.7 MB/s | **2.1x** | 1727.3 MB/s | 2268.6 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5188.4 MB/s | 1435.3 MB/s | **0.3x** | 6483.6 MB/s | 1557.3 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5482.3 MB/s | 1366.7 MB/s | **0.2x** | 5898.5 MB/s | 4076.9 MB/s | **0.7x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 681.5 MB/s | 78.4 MB/s | **0.1x** | 1602.7 MB/s | 3574.3 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 977.7 MB/s | 76.6 MB/s | **0.1x** | 1265.2 MB/s | 3673.0 MB/s | **2.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4958.0 MB/s | 629.4 MB/s | **0.1x** | 5264.4 MB/s | 3487.3 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4928.3 MB/s | 643.5 MB/s | **0.1x** | 5030.6 MB/s | 3390.4 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 658.8 MB/s | 637.8 MB/s | **1.0x** | 3515.0 MB/s | 3444.4 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 662.0 MB/s | 639.3 MB/s | **1.0x** | 3463.2 MB/s | 3354.2 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1008.2 MB/s | 1620.4 MB/s | **1.6x** | 1707.4 MB/s | 5546.8 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1009.1 MB/s | 1629.0 MB/s | **1.6x** | 1970.4 MB/s | 6839.6 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.0 MB/s | 1144.1 MB/s | **11.9x** | 1729.0 MB/s | 9887.2 MB/s | **5.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.4 MB/s | 1147.0 MB/s | **12.0x** | 1880.0 MB/s | 10304.4 MB/s | **5.5x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8635.0 MB/s | 1592.5 MB/s | **0.2x** | 4468.8 MB/s | 4807.3 MB/s | **1.1x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 7073.3 MB/s | 703.5 MB/s | **0.1x** | 5207.0 MB/s | 3001.4 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1887.7 MB/s | 525.9 MB/s | **0.3x** | 1774.5 MB/s | 2902.0 MB/s | **1.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1436.9 MB/s | 589.6 MB/s | **0.4x** | 945.2 MB/s | 2984.4 MB/s | **3.2x** |
