# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 12:14:30 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 864.6 MB/s | 284.5 MB/s | **0.3x** | 737.7 MB/s | 481.3 MB/s | **0.7x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 830.7 MB/s | 286.5 MB/s | **0.3x** | 525.4 MB/s | 470.5 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.8 MB/s | 288.4 MB/s | **1.0x** | 603.6 MB/s | 416.6 MB/s | **0.7x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.8 MB/s | 289.5 MB/s | **1.0x** | 462.7 MB/s | 460.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 392.8 MB/s | 5542.3 MB/s | **14.1x** | 520.6 MB/s | 1586.9 MB/s | **3.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 385.3 MB/s | 2132.1 MB/s | **5.5x** | 283.6 MB/s | 1423.1 MB/s | **5.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 335.4 MB/s | 6579.2 MB/s | **19.6x** | 504.1 MB/s | 2130.9 MB/s | **4.2x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 331.0 MB/s | 1676.2 MB/s | **5.1x** | 286.9 MB/s | 1214.3 MB/s | **4.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 260.7 MB/s | 214.5 MB/s | **0.8x** | 200.7 MB/s | 256.8 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 246.1 MB/s | 192.0 MB/s | **0.8x** | 190.1 MB/s | 265.6 MB/s | **1.4x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 943.3 MB/s | 268.4 MB/s | **0.3x** | 1165.0 MB/s | 787.8 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 775.5 MB/s | 281.0 MB/s | **0.4x** | 691.7 MB/s | 550.6 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 272.0 MB/s | 282.5 MB/s | **1.0x** | 786.5 MB/s | 804.3 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 272.8 MB/s | 257.4 MB/s | **0.9x** | 554.5 MB/s | 481.1 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 611.7 MB/s | 1516.6 MB/s | **2.5x** | 851.0 MB/s | 4998.5 MB/s | **5.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 555.9 MB/s | 1387.0 MB/s | **2.5x** | 829.0 MB/s | 4278.3 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.3 MB/s | 1119.0 MB/s | **13.9x** | 820.5 MB/s | 6140.9 MB/s | **7.5x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.9 MB/s | 1089.3 MB/s | **13.5x** | 882.9 MB/s | 4583.2 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 980.0 MB/s | 716.3 MB/s | **0.7x** | 1013.9 MB/s | 738.7 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 821.2 MB/s | 654.1 MB/s | **0.8x** | 1065.5 MB/s | 792.9 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 621.6 MB/s | 397.7 MB/s | **0.6x** | 564.2 MB/s | 1819.8 MB/s | **3.2x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 556.4 MB/s | 403.3 MB/s | **0.7x** | 553.7 MB/s | 1530.6 MB/s | **2.8x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 214.5 MB/s | 178.6 MB/s | **0.8x** | 3996.2 MB/s | 1577.0 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 215.3 MB/s | 184.2 MB/s | **0.9x** | 3170.1 MB/s | 1463.6 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.6 MB/s | 184.5 MB/s | **1.3x** | 1619.0 MB/s | 1634.9 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 141.7 MB/s | 180.8 MB/s | **1.3x** | 1492.1 MB/s | 1478.6 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.2 MB/s | 193.9 MB/s | **2.2x** | 3531.9 MB/s | 6855.9 MB/s | **1.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.7 MB/s | 180.1 MB/s | **2.2x** | 1733.6 MB/s | 2173.0 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.1 MB/s | 156.9 MB/s | **2.1x** | 3526.9 MB/s | 9237.3 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.7 MB/s | 149.6 MB/s | **2.1x** | 1759.1 MB/s | 2224.2 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5152.8 MB/s | 1266.2 MB/s | **0.2x** | 5650.3 MB/s | 1429.3 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5636.4 MB/s | 1375.1 MB/s | **0.2x** | 6971.5 MB/s | 3941.9 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 879.9 MB/s | 75.0 MB/s | **0.1x** | 1514.2 MB/s | 3606.6 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 840.7 MB/s | 77.1 MB/s | **0.1x** | 1504.0 MB/s | 3882.1 MB/s | **2.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4984.1 MB/s | 640.2 MB/s | **0.1x** | 5086.5 MB/s | 3714.9 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5196.4 MB/s | 654.3 MB/s | **0.1x** | 5092.9 MB/s | 3603.4 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 657.5 MB/s | 658.1 MB/s | **1.0x** | 3626.6 MB/s | 3682.9 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 667.9 MB/s | 663.6 MB/s | **1.0x** | 3529.0 MB/s | 3551.8 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1020.7 MB/s | 1642.5 MB/s | **1.6x** | 1702.6 MB/s | 6653.3 MB/s | **3.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 974.3 MB/s | 1299.4 MB/s | **1.3x** | 2013.5 MB/s | 8914.6 MB/s | **4.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.4 MB/s | 1159.3 MB/s | **12.3x** | 1702.4 MB/s | 11351.2 MB/s | **6.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.3 MB/s | 1152.6 MB/s | **12.2x** | 2023.0 MB/s | 11542.4 MB/s | **5.7x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14376.4 MB/s | 1558.3 MB/s | **0.1x** | 5861.9 MB/s | 4953.1 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10056.2 MB/s | 1295.6 MB/s | **0.1x** | 6696.7 MB/s | 5913.0 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1724.4 MB/s | 589.6 MB/s | **0.3x** | 1437.8 MB/s | 2824.5 MB/s | **2.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1989.0 MB/s | 573.5 MB/s | **0.3x** | 960.9 MB/s | 2990.7 MB/s | **3.1x** |
