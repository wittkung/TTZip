# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:51:11 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 920.3 MB/s | 575.4 MB/s | **0.6x** | 776.5 MB/s | 638.6 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 886.5 MB/s | 528.4 MB/s | **0.6x** | 548.8 MB/s | 574.2 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.7 MB/s | 249.2 MB/s | **0.8x** | 623.2 MB/s | 604.9 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.5 MB/s | 244.5 MB/s | **0.8x** | 482.4 MB/s | 482.7 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 500.0 MB/s | 1271.5 MB/s | **2.5x** | 580.9 MB/s | 2057.5 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 468.0 MB/s | 886.0 MB/s | **1.9x** | 302.8 MB/s | 1911.7 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 401.1 MB/s | 1279.2 MB/s | **3.2x** | 603.5 MB/s | 2268.8 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 371.2 MB/s | 938.1 MB/s | **2.5x** | 302.8 MB/s | 1982.2 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 285.1 MB/s | 1103.4 MB/s | **3.9x** | 291.8 MB/s | 1035.3 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 293.9 MB/s | 1105.7 MB/s | **3.8x** | 296.5 MB/s | 1039.9 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1086.0 MB/s | 1078.7 MB/s | **1.0x** | 1423.5 MB/s | 1379.8 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 959.3 MB/s | 943.7 MB/s | **1.0x** | 876.4 MB/s | 827.4 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 301.5 MB/s | 299.5 MB/s | **1.0x** | 1006.8 MB/s | 983.8 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 301.1 MB/s | 294.3 MB/s | **1.0x** | 693.0 MB/s | 673.7 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 679.3 MB/s | 1761.1 MB/s | **2.6x** | 1013.6 MB/s | 5069.1 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 657.2 MB/s | 1650.7 MB/s | **2.5x** | 1114.2 MB/s | 4973.7 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.5 MB/s | 1264.7 MB/s | **16.5x** | 984.1 MB/s | 7691.2 MB/s | **7.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.9 MB/s | 1188.6 MB/s | **15.1x** | 1038.2 MB/s | 5422.3 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1702.4 MB/s | 4539.9 MB/s | **2.7x** | 1706.7 MB/s | 4680.1 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1318.6 MB/s | 4142.9 MB/s | **3.1x** | 1616.1 MB/s | 4973.3 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 769.0 MB/s | 4739.5 MB/s | **6.2x** | 953.7 MB/s | 5800.1 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 797.1 MB/s | 4618.9 MB/s | **5.8x** | 931.5 MB/s | 6039.2 MB/s | **6.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 238.2 MB/s | 232.3 MB/s | **1.0x** | 4372.6 MB/s | 4294.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 233.1 MB/s | 227.7 MB/s | **1.0x** | 3197.2 MB/s | 3210.8 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 140.8 MB/s | 148.1 MB/s | **1.1x** | 1610.9 MB/s | 1677.3 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 146.3 MB/s | 142.0 MB/s | **1.0x** | 1422.4 MB/s | 1513.5 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.6 MB/s | 181.1 MB/s | **2.0x** | 3673.1 MB/s | 9849.5 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.5 MB/s | 173.7 MB/s | **2.1x** | 1855.0 MB/s | 2366.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.7 MB/s | 147.3 MB/s | **1.9x** | 3651.4 MB/s | 10271.8 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.4 MB/s | 139.3 MB/s | **2.0x** | 1783.7 MB/s | 1840.3 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5146.7 MB/s | 8531.6 MB/s | **1.7x** | 6919.1 MB/s | 5756.4 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5377.9 MB/s | 8028.4 MB/s | **1.5x** | 7126.6 MB/s | 5883.9 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1029.9 MB/s | 1715.2 MB/s | **1.7x** | 1570.5 MB/s | 4232.8 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1000.9 MB/s | 1770.0 MB/s | **1.8x** | 1534.0 MB/s | 4754.4 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5556.1 MB/s | 5657.3 MB/s | **1.0x** | 5337.1 MB/s | 5414.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5296.4 MB/s | 5261.6 MB/s | **1.0x** | 4931.2 MB/s | 4795.4 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 682.1 MB/s | 670.9 MB/s | **1.0x** | 3768.6 MB/s | 3543.2 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 683.1 MB/s | 681.4 MB/s | **1.0x** | 3532.6 MB/s | 3476.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1038.7 MB/s | 1800.2 MB/s | **1.7x** | 1754.0 MB/s | 6864.7 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1037.2 MB/s | 1874.6 MB/s | **1.8x** | 2012.7 MB/s | 7209.3 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.7 MB/s | 1265.8 MB/s | **13.2x** | 1762.8 MB/s | 10587.9 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.6 MB/s | 1263.7 MB/s | **13.1x** | 2092.8 MB/s | 11681.8 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12229.1 MB/s | 12625.2 MB/s | **1.0x** | 6163.6 MB/s | 6528.7 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10620.0 MB/s | 14819.5 MB/s | **1.4x** | 6503.6 MB/s | 7045.0 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2166.1 MB/s | 9096.2 MB/s | **4.2x** | 1866.7 MB/s | 3227.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2014.4 MB/s | 9891.4 MB/s | **4.9x** | 1974.7 MB/s | 3297.6 MB/s | **1.7x** | - |
