# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:01:36 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 883.3 MB/s | 1396.8 MB/s | **1.6x** | 734.3 MB/s | 1383.2 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 850.2 MB/s | 1458.6 MB/s | **1.7x** | 530.5 MB/s | 1441.7 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.2 MB/s | 573.2 MB/s | **2.0x** | 594.5 MB/s | 1331.8 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 283.1 MB/s | 619.5 MB/s | **2.2x** | 489.9 MB/s | 1317.9 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 440.9 MB/s | 1279.8 MB/s | **2.9x** | 590.6 MB/s | 2161.8 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 410.7 MB/s | 924.2 MB/s | **2.3x** | 299.4 MB/s | 2022.9 MB/s | **6.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 355.0 MB/s | 1262.0 MB/s | **3.6x** | 572.3 MB/s | 2224.7 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 347.1 MB/s | 931.9 MB/s | **2.7x** | 304.8 MB/s | 1947.9 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 281.4 MB/s | 1057.9 MB/s | **3.8x** | 292.5 MB/s | 1073.1 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 287.7 MB/s | 1122.2 MB/s | **3.9x** | 287.5 MB/s | 1093.7 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1060.7 MB/s | 1602.8 MB/s | **1.5x** | 1353.4 MB/s | 4648.3 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 952.3 MB/s | 1706.8 MB/s | **1.8x** | 847.0 MB/s | 4566.0 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.9 MB/s | 570.4 MB/s | **2.0x** | 963.5 MB/s | 3744.1 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.7 MB/s | 573.1 MB/s | **2.0x** | 675.7 MB/s | 3661.0 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 677.7 MB/s | 1793.3 MB/s | **2.6x** | 988.9 MB/s | 6126.8 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 649.4 MB/s | 1658.6 MB/s | **2.6x** | 1040.1 MB/s | 4759.6 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.3 MB/s | 1261.1 MB/s | **16.1x** | 982.9 MB/s | 6615.9 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.6 MB/s | 1190.3 MB/s | **15.0x** | 1048.3 MB/s | 4904.1 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1583.8 MB/s | 8375.3 MB/s | **5.3x** | 1585.5 MB/s | 5190.7 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1247.4 MB/s | 6107.1 MB/s | **4.9x** | 1543.9 MB/s | 5103.0 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 314.6 MB/s | 4848.4 MB/s | **15.4x** | 867.1 MB/s | 5598.8 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 802.6 MB/s | 5295.0 MB/s | **6.6x** | 923.1 MB/s | 5592.5 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 221.3 MB/s | 5508.0 MB/s | **24.9x** | 4135.5 MB/s | 7169.4 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 218.6 MB/s | 1320.2 MB/s | **6.0x** | 3404.2 MB/s | 8557.7 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.5 MB/s | 6008.7 MB/s | **41.9x** | 1724.2 MB/s | 7622.5 MB/s | **4.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.1 MB/s | 1382.2 MB/s | **9.9x** | 1510.7 MB/s | 8771.9 MB/s | **5.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.1 MB/s | 186.1 MB/s | **2.2x** | 3896.7 MB/s | 11332.7 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.3 MB/s | 180.2 MB/s | **2.2x** | 1840.9 MB/s | 2377.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.2 MB/s | 149.2 MB/s | **2.0x** | 3854.0 MB/s | 10413.4 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.7 MB/s | 142.7 MB/s | **2.0x** | 1856.9 MB/s | 2428.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5776.4 MB/s | 5236.9 MB/s | **0.9x** | 6175.0 MB/s | 3796.4 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5752.0 MB/s | 5144.3 MB/s | **0.9x** | 7167.6 MB/s | 4517.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 928.8 MB/s | 1823.0 MB/s | **2.0x** | 1447.9 MB/s | 5807.5 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1007.1 MB/s | 1859.3 MB/s | **1.8x** | 1668.3 MB/s | 5904.1 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5385.7 MB/s | 5229.5 MB/s | **1.0x** | 5505.0 MB/s | 9524.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5468.9 MB/s | 5332.5 MB/s | **1.0x** | 5600.3 MB/s | 9824.0 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 682.1 MB/s | 4856.5 MB/s | **7.1x** | 3833.6 MB/s | 9635.9 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 680.2 MB/s | 4837.4 MB/s | **7.1x** | 3435.9 MB/s | 9786.7 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1032.0 MB/s | 1872.5 MB/s | **1.8x** | 1800.6 MB/s | 10688.8 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1028.6 MB/s | 1872.6 MB/s | **1.8x** | 1971.1 MB/s | 10672.6 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.3 MB/s | 1269.1 MB/s | **13.2x** | 1755.5 MB/s | 11605.7 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.7 MB/s | 1268.9 MB/s | **13.0x** | 2013.0 MB/s | 11508.6 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12888.1 MB/s | 19282.1 MB/s | **1.5x** | 5575.5 MB/s | 4751.4 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9124.0 MB/s | 22272.1 MB/s | **2.4x** | 5636.4 MB/s | 5044.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2185.2 MB/s | 10902.5 MB/s | **5.0x** | 1870.0 MB/s | 3192.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2014.0 MB/s | 10602.1 MB/s | **5.3x** | 1845.8 MB/s | 3174.5 MB/s | **1.7x** | - |
