# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:08:06 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 888.4 MB/s | 2249.9 MB/s | **2.5x** | 697.0 MB/s | 1548.4 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 836.4 MB/s | 2281.9 MB/s | **2.7x** | 525.7 MB/s | 1556.2 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.1 MB/s | 570.8 MB/s | **2.0x** | 605.0 MB/s | 1254.0 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.7 MB/s | 607.8 MB/s | **2.1x** | 490.5 MB/s | 1316.3 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 432.9 MB/s | 1255.2 MB/s | **2.9x** | 575.8 MB/s | 2238.2 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 416.2 MB/s | 935.2 MB/s | **2.2x** | 300.6 MB/s | 1931.8 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 361.4 MB/s | 1269.6 MB/s | **3.5x** | 590.5 MB/s | 2174.3 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 345.6 MB/s | 942.0 MB/s | **2.7x** | 301.1 MB/s | 1694.8 MB/s | **5.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 291.8 MB/s | 1123.3 MB/s | **3.8x** | 289.6 MB/s | 1104.8 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 294.3 MB/s | 1060.5 MB/s | **3.6x** | 288.5 MB/s | 1053.1 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1049.6 MB/s | 3210.4 MB/s | **3.1x** | 1384.6 MB/s | 5341.3 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 940.9 MB/s | 3149.7 MB/s | **3.3x** | 831.4 MB/s | 5884.2 MB/s | **7.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.0 MB/s | 570.1 MB/s | **2.0x** | 993.7 MB/s | 3828.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.4 MB/s | 571.6 MB/s | **2.0x** | 666.7 MB/s | 3780.4 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 662.6 MB/s | 1804.6 MB/s | **2.7x** | 993.7 MB/s | 6027.8 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 657.1 MB/s | 1645.4 MB/s | **2.5x** | 1057.6 MB/s | 4958.6 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.0 MB/s | 1245.0 MB/s | **15.6x** | 962.8 MB/s | 6590.8 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.8 MB/s | 1179.5 MB/s | **15.0x** | 1049.0 MB/s | 5156.7 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1625.0 MB/s | 8778.9 MB/s | **5.4x** | 1649.7 MB/s | 5134.5 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1250.8 MB/s | 6180.7 MB/s | **4.9x** | 1570.9 MB/s | 5201.3 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 780.7 MB/s | 5110.9 MB/s | **6.5x** | 904.0 MB/s | 5913.9 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 788.4 MB/s | 5240.1 MB/s | **6.6x** | 939.2 MB/s | 6030.5 MB/s | **6.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 219.9 MB/s | 5600.0 MB/s | **25.5x** | 3972.7 MB/s | 7394.1 MB/s | **1.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 216.0 MB/s | 1359.2 MB/s | **6.3x** | 3375.5 MB/s | 8579.6 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.4 MB/s | 6076.2 MB/s | **42.4x** | 1720.1 MB/s | 7414.5 MB/s | **4.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.7 MB/s | 1407.2 MB/s | **9.8x** | 1563.7 MB/s | 8600.7 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.3 MB/s | 187.1 MB/s | **2.1x** | 3958.9 MB/s | 11227.1 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.2 MB/s | 177.4 MB/s | **2.1x** | 1823.1 MB/s | 2324.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.1 MB/s | 150.8 MB/s | **2.0x** | 3817.4 MB/s | 9669.7 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.7 MB/s | 144.0 MB/s | **2.0x** | 1813.7 MB/s | 2332.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4915.4 MB/s | 5146.9 MB/s | **1.0x** | 6604.4 MB/s | 3658.8 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5006.2 MB/s | 5050.7 MB/s | **1.0x** | 6937.4 MB/s | 3838.6 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 999.8 MB/s | 1773.3 MB/s | **1.8x** | 1645.7 MB/s | 5168.8 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 966.0 MB/s | 1794.1 MB/s | **1.9x** | 1248.5 MB/s | 5454.9 MB/s | **4.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5153.1 MB/s | 5071.0 MB/s | **1.0x** | 5631.0 MB/s | 9109.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5118.2 MB/s | 5123.8 MB/s | **1.0x** | 5119.4 MB/s | 9420.3 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.8 MB/s | 4735.1 MB/s | **7.0x** | 3567.4 MB/s | 9487.8 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 670.0 MB/s | 4746.1 MB/s | **7.1x** | 3487.3 MB/s | 9530.4 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 998.0 MB/s | 1848.7 MB/s | **1.9x** | 1667.5 MB/s | 10558.9 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1036.1 MB/s | 1836.4 MB/s | **1.8x** | 2037.7 MB/s | 10425.1 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.7 MB/s | 1263.1 MB/s | **13.5x** | 1749.1 MB/s | 12075.4 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.2 MB/s | 1258.3 MB/s | **13.2x** | 2062.0 MB/s | 11588.9 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12049.8 MB/s | 17789.4 MB/s | **1.5x** | 5547.1 MB/s | 4580.7 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9409.7 MB/s | 21987.4 MB/s | **2.3x** | 6241.9 MB/s | 5879.5 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2198.8 MB/s | 10710.4 MB/s | **4.9x** | 1875.2 MB/s | 3168.7 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2043.3 MB/s | 10620.7 MB/s | **5.2x** | 1942.8 MB/s | 3254.9 MB/s | **1.7x** | - |
