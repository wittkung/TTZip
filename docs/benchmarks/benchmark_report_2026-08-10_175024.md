# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:50:24 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 888.0 MB/s | 276.2 MB/s | **0.3x** | 671.3 MB/s | 581.0 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 817.8 MB/s | 286.1 MB/s | **0.3x** | 519.6 MB/s | 461.4 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.1 MB/s | 282.6 MB/s | **1.0x** | 622.2 MB/s | 602.4 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.0 MB/s | 287.8 MB/s | **1.0x** | 479.1 MB/s | 475.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 403.7 MB/s | 5597.9 MB/s | **13.9x** | 580.3 MB/s | 2008.1 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 376.2 MB/s | 2080.3 MB/s | **5.5x** | 285.8 MB/s | 1957.2 MB/s | **6.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 315.1 MB/s | 5416.8 MB/s | **17.2x** | 577.4 MB/s | 1795.6 MB/s | **3.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 310.2 MB/s | 2014.5 MB/s | **6.5x** | 291.7 MB/s | 1383.5 MB/s | **4.7x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 255.9 MB/s | 221.7 MB/s | **0.9x** | 119.2 MB/s | 309.5 MB/s | **2.6x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 175.2 MB/s | 167.3 MB/s | **1.0x** | 127.1 MB/s | 196.5 MB/s | **1.5x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 726.0 MB/s | 243.2 MB/s | **0.3x** | 940.7 MB/s | 701.8 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 675.5 MB/s | 249.6 MB/s | **0.4x** | 591.8 MB/s | 506.7 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 278.9 MB/s | 250.5 MB/s | **0.9x** | 856.3 MB/s | 801.5 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 278.5 MB/s | 278.9 MB/s | **1.0x** | 577.2 MB/s | 564.9 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 614.9 MB/s | 1616.9 MB/s | **2.6x** | 851.3 MB/s | 5253.5 MB/s | **6.2x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 600.5 MB/s | 1465.9 MB/s | **2.4x** | 889.2 MB/s | 4325.9 MB/s | **4.9x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.7 MB/s | 1153.2 MB/s | **14.5x** | 847.5 MB/s | 6353.1 MB/s | **7.5x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.1 MB/s | 1080.7 MB/s | **13.7x** | 840.0 MB/s | 4515.8 MB/s | **5.4x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1152.7 MB/s | 865.9 MB/s | **0.8x** | 1241.9 MB/s | 1155.6 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1036.8 MB/s | 838.4 MB/s | **0.8x** | 1285.8 MB/s | 1153.7 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 645.9 MB/s | 453.3 MB/s | **0.7x** | 782.9 MB/s | 1794.6 MB/s | **2.3x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 603.5 MB/s | 428.0 MB/s | **0.7x** | 600.9 MB/s | 1847.9 MB/s | **3.1x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 187.0 MB/s | 168.4 MB/s | **0.9x** | 3783.6 MB/s | 1562.9 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 192.2 MB/s | 161.2 MB/s | **0.8x** | 3024.2 MB/s | 1448.9 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 130.3 MB/s | 165.2 MB/s | **1.3x** | 1576.9 MB/s | 1535.0 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 129.7 MB/s | 174.4 MB/s | **1.3x** | 1441.7 MB/s | 1344.1 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.1 MB/s | 186.4 MB/s | **2.1x** | 3388.9 MB/s | 8257.7 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.9 MB/s | 182.4 MB/s | **2.3x** | 1684.2 MB/s | 2125.5 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.8 MB/s | 152.3 MB/s | **2.1x** | 3447.3 MB/s | 3907.7 MB/s | **1.1x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.7 MB/s | 146.0 MB/s | **2.2x** | 1658.9 MB/s | 2115.1 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4757.3 MB/s | 1197.4 MB/s | **0.3x** | 5970.7 MB/s | 1427.0 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5020.4 MB/s | 1276.8 MB/s | **0.3x** | 5227.8 MB/s | 3526.2 MB/s | **0.7x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 743.8 MB/s | 72.6 MB/s | **0.1x** | 1215.3 MB/s | 2865.2 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 787.9 MB/s | 72.4 MB/s | **0.1x** | 1408.3 MB/s | 3135.1 MB/s | **2.2x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4850.3 MB/s | 622.9 MB/s | **0.1x** | 4838.2 MB/s | 3186.8 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4817.5 MB/s | 629.6 MB/s | **0.1x** | 4626.5 MB/s | 3395.5 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 628.1 MB/s | 612.7 MB/s | **1.0x** | 3445.4 MB/s | 3062.2 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 650.4 MB/s | 621.9 MB/s | **1.0x** | 3325.2 MB/s | 3299.2 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1005.8 MB/s | 1574.8 MB/s | **1.6x** | 1663.2 MB/s | 5625.1 MB/s | **3.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1003.0 MB/s | 1618.0 MB/s | **1.6x** | 2027.1 MB/s | 6699.0 MB/s | **3.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.2 MB/s | 1117.8 MB/s | **12.1x** | 1645.3 MB/s | 10971.2 MB/s | **6.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.9 MB/s | 1113.7 MB/s | **12.2x** | 1966.7 MB/s | 11049.2 MB/s | **5.6x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11789.7 MB/s | 1623.1 MB/s | **0.1x** | 4762.8 MB/s | 4106.6 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8577.2 MB/s | 1000.1 MB/s | **0.1x** | 5118.5 MB/s | 3067.7 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1808.5 MB/s | 333.7 MB/s | **0.2x** | 971.6 MB/s | 2611.0 MB/s | **2.7x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1528.4 MB/s | 444.9 MB/s | **0.3x** | 984.8 MB/s | 2776.7 MB/s | **2.8x** |
