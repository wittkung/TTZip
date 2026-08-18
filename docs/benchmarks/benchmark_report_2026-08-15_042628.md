# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:26:28 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 886.5 MB/s | 902.7 MB/s | **1.0x** | 662.4 MB/s | 1456.0 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 850.2 MB/s | 883.9 MB/s | **1.0x** | 531.1 MB/s | 1546.8 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.7 MB/s | 414.6 MB/s | **1.5x** | 569.7 MB/s | 1388.0 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 281.6 MB/s | 435.1 MB/s | **1.5x** | 477.5 MB/s | 1379.9 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 415.1 MB/s | 1192.9 MB/s | **2.9x** | 557.4 MB/s | 2109.4 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 389.5 MB/s | 876.3 MB/s | **2.2x** | 297.9 MB/s | 1967.6 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 349.2 MB/s | 1261.9 MB/s | **3.6x** | 593.2 MB/s | 2193.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 321.0 MB/s | 851.3 MB/s | **2.7x** | 290.2 MB/s | 1845.5 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 286.3 MB/s | 1066.3 MB/s | **3.7x** | 280.2 MB/s | 1097.6 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 278.4 MB/s | 1033.3 MB/s | **3.7x** | 210.9 MB/s | 992.3 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1034.8 MB/s | 2796.8 MB/s | **2.7x** | 1320.7 MB/s | 4334.3 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 926.7 MB/s | 2454.0 MB/s | **2.6x** | 821.8 MB/s | 4222.8 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.7 MB/s | 568.9 MB/s | **1.9x** | 948.0 MB/s | 3354.4 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.3 MB/s | 557.9 MB/s | **1.9x** | 649.5 MB/s | 3272.7 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 654.9 MB/s | 1725.8 MB/s | **2.6x** | 983.9 MB/s | 6383.1 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 625.4 MB/s | 1594.2 MB/s | **2.5x** | 1005.1 MB/s | 4888.7 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.5 MB/s | 1245.3 MB/s | **16.3x** | 944.4 MB/s | 7123.1 MB/s | **7.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.4 MB/s | 1164.0 MB/s | **15.4x** | 1005.8 MB/s | 5221.4 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1657.8 MB/s | 9097.7 MB/s | **5.5x** | 1631.9 MB/s | 4774.5 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1272.7 MB/s | 5885.7 MB/s | **4.6x** | 1591.0 MB/s | 5223.1 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 804.0 MB/s | 5118.9 MB/s | **6.4x** | 904.9 MB/s | 5481.4 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 772.4 MB/s | 5419.5 MB/s | **7.0x** | 909.2 MB/s | 5601.8 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 212.2 MB/s | 5530.0 MB/s | **26.1x** | 4102.0 MB/s | 4628.4 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 180.3 MB/s | 1279.2 MB/s | **7.1x** | 3076.1 MB/s | 4999.2 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.7 MB/s | 5242.7 MB/s | **38.4x** | 1541.4 MB/s | 4381.6 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 132.2 MB/s | 1316.5 MB/s | **10.0x** | 1413.1 MB/s | 5007.4 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.2 MB/s | 171.1 MB/s | **2.0x** | 3710.8 MB/s | 10428.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.9 MB/s | 169.1 MB/s | **2.1x** | 1738.5 MB/s | 2293.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.8 MB/s | 140.5 MB/s | **2.2x** | 3276.1 MB/s | 10486.0 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 62.4 MB/s | 128.9 MB/s | **2.1x** | 1592.1 MB/s | 2196.8 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5017.0 MB/s | 4997.3 MB/s | **1.0x** | 6473.1 MB/s | 3412.6 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 2198.7 MB/s | 5106.6 MB/s | **2.3x** | 6322.7 MB/s | 4047.0 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 788.5 MB/s | 1563.3 MB/s | **2.0x** | 1387.3 MB/s | 5369.7 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 824.9 MB/s | 1712.5 MB/s | **2.1x** | 1434.6 MB/s | 4897.7 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5374.8 MB/s | 4827.2 MB/s | **0.9x** | 5145.6 MB/s | 4745.5 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5157.6 MB/s | 4402.6 MB/s | **0.9x** | 4869.3 MB/s | 4631.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 665.7 MB/s | 4484.4 MB/s | **6.7x** | 3229.3 MB/s | 4830.6 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 663.2 MB/s | 4351.6 MB/s | **6.6x** | 3430.0 MB/s | 5034.4 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1017.2 MB/s | 1820.3 MB/s | **1.8x** | 1718.6 MB/s | 10675.8 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1008.1 MB/s | 1776.2 MB/s | **1.8x** | 1997.6 MB/s | 9899.9 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.1 MB/s | 1260.2 MB/s | **14.0x** | 1658.4 MB/s | 12141.4 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.4 MB/s | 1243.3 MB/s | **13.6x** | 2013.0 MB/s | 10807.3 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13812.2 MB/s | 18915.8 MB/s | **1.4x** | 5931.9 MB/s | 5028.4 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10932.1 MB/s | 22613.9 MB/s | **2.1x** | 6359.4 MB/s | 5311.9 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2140.4 MB/s | 10112.5 MB/s | **4.7x** | 1855.2 MB/s | 3036.3 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1992.9 MB/s | 10870.3 MB/s | **5.5x** | 1728.7 MB/s | 3177.3 MB/s | **1.8x** | - |
