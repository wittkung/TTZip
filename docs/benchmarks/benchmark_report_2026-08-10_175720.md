# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:57:20 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 848.5 MB/s | 269.9 MB/s | **0.3x** | 681.0 MB/s | 529.5 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 779.6 MB/s | 276.8 MB/s | **0.4x** | 537.5 MB/s | 425.3 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 281.6 MB/s | 297.0 MB/s | **1.1x** | 589.4 MB/s | 601.1 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 276.5 MB/s | 266.1 MB/s | **1.0x** | 457.7 MB/s | 446.2 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 431.8 MB/s | 5272.6 MB/s | **12.2x** | 571.4 MB/s | 1754.3 MB/s | **3.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 391.0 MB/s | 1799.6 MB/s | **4.6x** | 295.0 MB/s | 1741.0 MB/s | **5.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 324.5 MB/s | 1400.2 MB/s | **4.3x** | 557.1 MB/s | 1591.3 MB/s | **2.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 314.3 MB/s | 1916.2 MB/s | **6.1x** | 293.3 MB/s | 1858.6 MB/s | **6.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 280.9 MB/s | 214.8 MB/s | **0.8x** | 250.0 MB/s | 318.6 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 271.2 MB/s | 207.5 MB/s | **0.8x** | 239.5 MB/s | 222.4 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 994.7 MB/s | 282.4 MB/s | **0.3x** | 1230.6 MB/s | 831.2 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 771.9 MB/s | 277.9 MB/s | **0.4x** | 686.9 MB/s | 541.6 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 276.4 MB/s | 278.2 MB/s | **1.0x** | 841.8 MB/s | 806.4 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 267.8 MB/s | 265.7 MB/s | **1.0x** | 532.2 MB/s | 541.7 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 566.1 MB/s | 1442.2 MB/s | **2.5x** | 813.5 MB/s | 3854.2 MB/s | **4.7x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 577.7 MB/s | 1420.4 MB/s | **2.5x** | 889.8 MB/s | 4322.8 MB/s | **4.9x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 78.8 MB/s | 1162.6 MB/s | **14.8x** | 839.8 MB/s | 6383.2 MB/s | **7.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 76.4 MB/s | 1056.8 MB/s | **13.8x** | 789.3 MB/s | 5069.6 MB/s | **6.4x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1034.6 MB/s | 502.2 MB/s | **0.5x** | 1082.1 MB/s | 760.0 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 798.7 MB/s | 532.0 MB/s | **0.7x** | 921.7 MB/s | 927.4 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 576.3 MB/s | 430.7 MB/s | **0.7x** | 651.8 MB/s | 1677.5 MB/s | **2.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 596.7 MB/s | 436.4 MB/s | **0.7x** | 650.5 MB/s | 1749.2 MB/s | **2.7x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 176.1 MB/s | 156.7 MB/s | **0.9x** | 3599.2 MB/s | 1484.5 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 166.2 MB/s | 166.6 MB/s | **1.0x** | 3004.5 MB/s | 1412.0 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 128.6 MB/s | 158.4 MB/s | **1.2x** | 1565.1 MB/s | 1478.4 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 130.1 MB/s | 160.1 MB/s | **1.2x** | 1430.2 MB/s | 1393.5 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.0 MB/s | 191.7 MB/s | **2.2x** | 3327.8 MB/s | 7586.2 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 77.7 MB/s | 177.3 MB/s | **2.3x** | 1694.0 MB/s | 2132.4 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.8 MB/s | 145.7 MB/s | **2.1x** | 3233.4 MB/s | 9133.5 MB/s | **2.8x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.4 MB/s | 135.5 MB/s | **2.0x** | 1604.1 MB/s | 2111.9 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4580.5 MB/s | 1033.1 MB/s | **0.2x** | 5595.1 MB/s | 1292.2 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4522.5 MB/s | 924.7 MB/s | **0.2x** | 5867.0 MB/s | 2969.8 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 724.4 MB/s | 68.7 MB/s | **0.1x** | 788.0 MB/s | 3097.1 MB/s | **3.9x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 622.3 MB/s | 60.3 MB/s | **0.1x** | 839.3 MB/s | 3344.9 MB/s | **4.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4864.5 MB/s | 598.0 MB/s | **0.1x** | 4709.3 MB/s | 2940.0 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4442.6 MB/s | 599.7 MB/s | **0.1x** | 3903.3 MB/s | 2855.4 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 611.8 MB/s | 256.5 MB/s | **0.4x** | 3158.0 MB/s | 2361.3 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 619.8 MB/s | 607.9 MB/s | **1.0x** | 3135.9 MB/s | 2710.9 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 991.0 MB/s | 1471.4 MB/s | **1.5x** | 1620.8 MB/s | 5625.6 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1007.4 MB/s | 1535.9 MB/s | **1.5x** | 1922.9 MB/s | 7794.5 MB/s | **4.1x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.6 MB/s | 1083.2 MB/s | **11.8x** | 1591.2 MB/s | 9770.5 MB/s | **6.1x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.5 MB/s | 1089.8 MB/s | **11.9x** | 1894.1 MB/s | 9811.7 MB/s | **5.2x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11915.7 MB/s | 1281.1 MB/s | **0.1x** | 5052.6 MB/s | 4172.1 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 5192.5 MB/s | 888.4 MB/s | **0.2x** | 5114.7 MB/s | 1719.8 MB/s | **0.3x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1727.5 MB/s | 494.2 MB/s | **0.3x** | 1068.0 MB/s | 2862.4 MB/s | **2.7x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1483.6 MB/s | 374.3 MB/s | **0.3x** | 1439.0 MB/s | 2944.1 MB/s | **2.0x** |
