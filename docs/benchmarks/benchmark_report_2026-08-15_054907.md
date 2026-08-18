# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:49:07 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 544.9 MB/s | 1729.7 MB/s | **3.2x** | 483.1 MB/s | 1094.0 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 688.3 MB/s | 2035.4 MB/s | **3.0x** | 435.0 MB/s | 1209.0 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 260.9 MB/s | 491.5 MB/s | **1.9x** | 443.6 MB/s | 1075.6 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 260.9 MB/s | 496.4 MB/s | **1.9x** | 375.4 MB/s | 930.7 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 397.4 MB/s | 797.1 MB/s | **2.0x** | 415.4 MB/s | 1620.4 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 386.7 MB/s | 697.2 MB/s | **1.8x** | 251.9 MB/s | 1591.2 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 364.1 MB/s | 843.2 MB/s | **2.3x** | 453.5 MB/s | 2105.7 MB/s | **4.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 353.6 MB/s | 714.6 MB/s | **2.0x** | 262.8 MB/s | 1733.9 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 236.6 MB/s | 798.4 MB/s | **3.4x** | 208.5 MB/s | 692.5 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 245.8 MB/s | 808.8 MB/s | **3.3x** | 226.9 MB/s | 857.7 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 971.3 MB/s | 2672.2 MB/s | **2.8x** | 1256.4 MB/s | 5128.7 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 853.5 MB/s | 2777.7 MB/s | **3.3x** | 783.8 MB/s | 5113.5 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.4 MB/s | 524.6 MB/s | **1.8x** | 921.4 MB/s | 3624.9 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.8 MB/s | 548.6 MB/s | **1.9x** | 619.0 MB/s | 3710.7 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 644.6 MB/s | 1678.8 MB/s | **2.6x** | 855.1 MB/s | 5452.7 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 617.7 MB/s | 1557.0 MB/s | **2.5x** | 851.2 MB/s | 4432.5 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.7 MB/s | 1197.6 MB/s | **16.0x** | 817.6 MB/s | 6065.5 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.5 MB/s | 1131.4 MB/s | **15.4x** | 835.6 MB/s | 4587.1 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1189.2 MB/s | 7132.4 MB/s | **6.0x** | 1343.1 MB/s | 3812.9 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1056.0 MB/s | 5561.3 MB/s | **5.3x** | 1254.8 MB/s | 4202.8 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 744.8 MB/s | 4486.1 MB/s | **6.0x** | 681.4 MB/s | 3906.5 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 713.1 MB/s | 4181.0 MB/s | **5.9x** | 747.5 MB/s | 3848.2 MB/s | **5.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 165.2 MB/s | 5164.1 MB/s | **31.3x** | 3912.9 MB/s | 5247.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 165.7 MB/s | 1246.7 MB/s | **7.5x** | 3139.8 MB/s | 3268.8 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 131.9 MB/s | 5006.8 MB/s | **38.0x** | 1522.0 MB/s | 6116.5 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.0 MB/s | 1319.9 MB/s | **9.5x** | 1449.6 MB/s | 7692.7 MB/s | **5.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.9 MB/s | 182.6 MB/s | **2.1x** | 3729.4 MB/s | 10617.6 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.9 MB/s | 172.4 MB/s | **2.1x** | 1732.3 MB/s | 2203.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.9 MB/s | 145.1 MB/s | **2.0x** | 3331.3 MB/s | 10026.9 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.5 MB/s | 140.3 MB/s | **2.0x** | 1794.3 MB/s | 2248.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4594.3 MB/s | 3610.4 MB/s | **0.8x** | 6647.4 MB/s | 3311.5 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5904.0 MB/s | 5014.7 MB/s | **0.8x** | 6879.7 MB/s | 3726.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 996.8 MB/s | 1782.6 MB/s | **1.8x** | 1276.6 MB/s | 4941.4 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 999.2 MB/s | 1772.9 MB/s | **1.8x** | 1298.9 MB/s | 4633.2 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5293.6 MB/s | 5478.5 MB/s | **1.0x** | 5412.3 MB/s | 9291.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5154.9 MB/s | 5287.6 MB/s | **1.0x** | 5439.3 MB/s | 9226.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 659.5 MB/s | 4916.4 MB/s | **7.5x** | 3526.7 MB/s | 9519.9 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 677.9 MB/s | 4718.3 MB/s | **7.0x** | 3423.9 MB/s | 9395.8 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1018.4 MB/s | 1847.8 MB/s | **1.8x** | 1592.1 MB/s | 10224.5 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.7 MB/s | 1844.3 MB/s | **1.8x** | 1823.5 MB/s | 10535.2 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.3 MB/s | 1255.4 MB/s | **13.2x** | 1755.2 MB/s | 11903.5 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.0 MB/s | 1255.9 MB/s | **13.1x** | 2019.7 MB/s | 11968.0 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14866.9 MB/s | 19860.0 MB/s | **1.3x** | 5763.0 MB/s | 4870.9 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10219.5 MB/s | 22019.8 MB/s | **2.2x** | 5831.9 MB/s | 4920.9 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2169.1 MB/s | 10512.1 MB/s | **4.8x** | 1443.0 MB/s | 3136.0 MB/s | **2.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1854.0 MB/s | 9243.7 MB/s | **5.0x** | 1985.9 MB/s | 3112.8 MB/s | **1.6x** | - |
