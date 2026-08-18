# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-11 08:14:40 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1126.9 MB/s | 305.8 MB/s | **0.3x** | 903.9 MB/s | 701.6 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1033.0 MB/s | 305.8 MB/s | **0.3x** | 600.6 MB/s | 527.1 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 306.2 MB/s | 307.2 MB/s | **1.0x** | 657.2 MB/s | 608.6 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 303.4 MB/s | 303.8 MB/s | **1.0x** | 495.7 MB/s | 478.8 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 421.3 MB/s | 6507.2 MB/s | **15.4x** | 599.6 MB/s | 1885.0 MB/s | **3.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 415.7 MB/s | 2180.2 MB/s | **5.2x** | 300.3 MB/s | 1815.7 MB/s | **6.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 343.9 MB/s | 6111.4 MB/s | **17.8x** | 617.2 MB/s | 1517.6 MB/s | **2.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 371.4 MB/s | 2078.7 MB/s | **5.6x** | 316.4 MB/s | 1731.4 MB/s | **5.5x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 274.8 MB/s | 138.0 MB/s | **0.5x** | 262.5 MB/s | 329.1 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 173.2 MB/s | 221.7 MB/s | **1.3x** | 186.8 MB/s | 346.4 MB/s | **1.9x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1255.0 MB/s | 319.8 MB/s | **0.3x** | 1852.9 MB/s | 1121.7 MB/s | **0.6x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1059.7 MB/s | 307.1 MB/s | **0.3x** | 890.8 MB/s | 673.9 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 317.0 MB/s | 314.3 MB/s | **1.0x** | 1202.7 MB/s | 1149.7 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 312.1 MB/s | 310.6 MB/s | **1.0x** | 693.1 MB/s | 681.0 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 773.3 MB/s | 1645.8 MB/s | **2.1x** | 1158.4 MB/s | 4122.0 MB/s | **3.6x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 731.5 MB/s | 1474.1 MB/s | **2.0x** | 1285.8 MB/s | 4081.5 MB/s | **3.2x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 83.3 MB/s | 1162.9 MB/s | **14.0x** | 1149.2 MB/s | 6019.2 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 82.2 MB/s | 1105.0 MB/s | **13.4x** | 1234.9 MB/s | 4332.7 MB/s | **3.5x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 2609.7 MB/s | 995.1 MB/s | **0.4x** | 2451.6 MB/s | 1250.3 MB/s | **0.5x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1567.6 MB/s | 804.4 MB/s | **0.5x** | 2122.0 MB/s | 1247.4 MB/s | **0.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 687.3 MB/s | 478.6 MB/s | **0.7x** | 857.9 MB/s | 2053.8 MB/s | **2.4x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 676.4 MB/s | 468.1 MB/s | **0.7x** | 818.2 MB/s | 1999.9 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 215.2 MB/s | 177.5 MB/s | **0.8x** | 4419.7 MB/s | 1549.6 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 211.5 MB/s | 177.1 MB/s | **0.8x** | 3425.4 MB/s | 1396.3 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 137.0 MB/s | 177.9 MB/s | **1.3x** | 1650.5 MB/s | 1646.2 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 136.9 MB/s | 180.5 MB/s | **1.3x** | 1523.8 MB/s | 1329.0 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.6 MB/s | 187.7 MB/s | **2.2x** | 3599.0 MB/s | 8313.7 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.3 MB/s | 177.1 MB/s | **2.3x** | 1757.2 MB/s | 2086.0 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.7 MB/s | 147.4 MB/s | **2.0x** | 3739.8 MB/s | 5687.9 MB/s | **1.5x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.9 MB/s | 141.9 MB/s | **2.0x** | 1789.3 MB/s | 2027.6 MB/s | **1.1x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5917.8 MB/s | 1431.3 MB/s | **0.2x** | 7840.0 MB/s | 1527.0 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 6138.2 MB/s | 1381.0 MB/s | **0.2x** | 8431.1 MB/s | 4123.7 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 954.9 MB/s | 77.4 MB/s | **0.1x** | 1623.7 MB/s | 2544.8 MB/s | **1.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 914.4 MB/s | 78.4 MB/s | **0.1x** | 1581.0 MB/s | 3743.8 MB/s | **2.4x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5044.8 MB/s | 630.5 MB/s | **0.1x** | 5431.3 MB/s | 3287.6 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5062.8 MB/s | 638.7 MB/s | **0.1x** | 5065.9 MB/s | 3329.8 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 661.7 MB/s | 644.5 MB/s | **1.0x** | 3738.8 MB/s | 3212.8 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 653.3 MB/s | 631.3 MB/s | **1.0x** | 3530.4 MB/s | 3420.7 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1013.5 MB/s | 1595.1 MB/s | **1.6x** | 1713.7 MB/s | 6062.8 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1003.8 MB/s | 1607.6 MB/s | **1.6x** | 1990.8 MB/s | 6445.5 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.6 MB/s | 1104.5 MB/s | **11.8x** | 1699.1 MB/s | 10152.5 MB/s | **6.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.1 MB/s | 1102.6 MB/s | **11.7x** | 2052.7 MB/s | 9923.1 MB/s | **4.8x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13768.1 MB/s | 1707.5 MB/s | **0.1x** | 5132.9 MB/s | 4955.9 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9493.5 MB/s | 1242.6 MB/s | **0.1x** | 6222.4 MB/s | 5744.4 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2124.3 MB/s | 600.0 MB/s | **0.3x** | 1705.6 MB/s | 3140.2 MB/s | **1.8x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1897.2 MB/s | 579.1 MB/s | **0.3x** | 1866.4 MB/s | 2818.9 MB/s | **1.5x** |
