# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:31:29 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 896.0 MB/s | 2367.9 MB/s | **2.6x** | 761.1 MB/s | 1473.6 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 863.4 MB/s | 2709.0 MB/s | **3.1x** | 573.9 MB/s | 1554.5 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.4 MB/s | 571.5 MB/s | **2.0x** | 628.1 MB/s | 1348.5 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 288.7 MB/s | 634.2 MB/s | **2.2x** | 502.5 MB/s | 1351.8 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 503.8 MB/s | 1213.8 MB/s | **2.4x** | 611.9 MB/s | 2186.4 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 458.0 MB/s | 954.2 MB/s | **2.1x** | 302.5 MB/s | 1892.4 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 408.6 MB/s | 1238.3 MB/s | **3.0x** | 599.7 MB/s | 2219.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 384.6 MB/s | 948.3 MB/s | **2.5x** | 303.4 MB/s | 1992.8 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 284.8 MB/s | 1029.9 MB/s | **3.6x** | 289.7 MB/s | 1146.3 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 197.6 MB/s | 1076.9 MB/s | **5.4x** | 293.7 MB/s | 1081.7 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1103.7 MB/s | 2979.6 MB/s | **2.7x** | 1450.9 MB/s | 6517.4 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 951.2 MB/s | 3548.7 MB/s | **3.7x** | 847.6 MB/s | 5752.8 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.0 MB/s | 545.5 MB/s | **1.8x** | 1039.0 MB/s | 4090.6 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.1 MB/s | 558.5 MB/s | **1.9x** | 699.3 MB/s | 3934.8 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 681.3 MB/s | 1794.5 MB/s | **2.6x** | 1041.6 MB/s | 7118.1 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 654.2 MB/s | 1680.4 MB/s | **2.6x** | 1101.9 MB/s | 4959.7 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.2 MB/s | 1280.8 MB/s | **16.4x** | 971.2 MB/s | 7768.6 MB/s | **8.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.1 MB/s | 1197.1 MB/s | **14.9x** | 1047.2 MB/s | 5660.1 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1673.9 MB/s | 8919.8 MB/s | **5.3x** | 1682.7 MB/s | 5253.3 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1322.0 MB/s | 6143.0 MB/s | **4.6x** | 1660.1 MB/s | 4868.4 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 798.9 MB/s | 5543.3 MB/s | **6.9x** | 948.4 MB/s | 5986.0 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 796.3 MB/s | 5496.1 MB/s | **6.9x** | 966.1 MB/s | 5704.9 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 231.9 MB/s | 5368.8 MB/s | **23.1x** | 4155.0 MB/s | 6374.3 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 202.8 MB/s | 1285.4 MB/s | **6.3x** | 3095.0 MB/s | 7819.5 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 146.6 MB/s | 5853.8 MB/s | **39.9x** | 1736.0 MB/s | 6801.3 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 150.0 MB/s | 1392.9 MB/s | **9.3x** | 1564.0 MB/s | 8315.3 MB/s | **5.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.2 MB/s | 187.1 MB/s | **2.1x** | 4034.0 MB/s | 11248.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.7 MB/s | 182.1 MB/s | **2.2x** | 1925.9 MB/s | 2394.6 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.7 MB/s | 151.9 MB/s | **2.0x** | 4114.6 MB/s | 11094.5 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.1 MB/s | 145.4 MB/s | **2.0x** | 1872.0 MB/s | 2410.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5541.9 MB/s | 5487.2 MB/s | **1.0x** | 6101.6 MB/s | 3646.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5485.3 MB/s | 4618.4 MB/s | **0.8x** | 6209.9 MB/s | 3998.7 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1046.0 MB/s | 1839.9 MB/s | **1.8x** | 1704.0 MB/s | 5418.8 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1021.0 MB/s | 1868.2 MB/s | **1.8x** | 1585.2 MB/s | 5903.6 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5713.0 MB/s | 5237.2 MB/s | **0.9x** | 5628.2 MB/s | 9639.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5401.3 MB/s | 5518.6 MB/s | **1.0x** | 5255.9 MB/s | 9795.2 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 675.1 MB/s | 5122.4 MB/s | **7.6x** | 3620.0 MB/s | 9579.6 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 685.9 MB/s | 5124.1 MB/s | **7.5x** | 3437.2 MB/s | 10005.5 MB/s | **2.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1010.7 MB/s | 1848.4 MB/s | **1.8x** | 1703.6 MB/s | 10883.3 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1040.4 MB/s | 1878.9 MB/s | **1.8x** | 1870.1 MB/s | 10679.3 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.9 MB/s | 1256.9 MB/s | **12.8x** | 1698.1 MB/s | 11862.4 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.8 MB/s | 1273.8 MB/s | **12.9x** | 1941.1 MB/s | 11407.2 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14516.9 MB/s | 24864.7 MB/s | **1.7x** | 5646.2 MB/s | 4778.3 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10123.4 MB/s | 23571.7 MB/s | **2.3x** | 5711.4 MB/s | 5058.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2283.4 MB/s | 11238.4 MB/s | **4.9x** | 1917.7 MB/s | 3240.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2067.9 MB/s | 11486.7 MB/s | **5.6x** | 1906.1 MB/s | 3197.2 MB/s | **1.7x** | - |
