# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:30:28 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 916.9 MB/s | 2566.6 MB/s | **2.8x** | 675.7 MB/s | 1411.3 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 868.6 MB/s | 2552.5 MB/s | **2.9x** | 571.3 MB/s | 1486.1 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.9 MB/s | 546.7 MB/s | **1.9x** | 594.3 MB/s | 1384.3 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.3 MB/s | 580.9 MB/s | **2.0x** | 496.1 MB/s | 1349.6 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 478.1 MB/s | 1219.4 MB/s | **2.6x** | 606.6 MB/s | 2209.1 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 405.9 MB/s | 944.2 MB/s | **2.3x** | 280.0 MB/s | 1906.7 MB/s | **6.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 378.4 MB/s | 1264.0 MB/s | **3.3x** | 546.2 MB/s | 2151.2 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 357.3 MB/s | 926.1 MB/s | **2.6x** | 300.1 MB/s | 1776.5 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 215.4 MB/s | 1077.7 MB/s | **5.0x** | 190.5 MB/s | 1123.6 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 256.6 MB/s | 981.0 MB/s | **3.8x** | 268.9 MB/s | 1043.3 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 994.6 MB/s | 3181.9 MB/s | **3.2x** | 1384.0 MB/s | 5771.9 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 857.8 MB/s | 3202.4 MB/s | **3.7x** | 795.1 MB/s | 5950.5 MB/s | **7.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 301.1 MB/s | 543.7 MB/s | **1.8x** | 971.5 MB/s | 3792.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.0 MB/s | 543.9 MB/s | **1.8x** | 656.6 MB/s | 3839.1 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 652.5 MB/s | 1761.1 MB/s | **2.7x** | 961.7 MB/s | 6756.3 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 616.8 MB/s | 1562.1 MB/s | **2.5x** | 953.6 MB/s | 4749.0 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.9 MB/s | 1215.3 MB/s | **16.4x** | 920.0 MB/s | 6853.1 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.5 MB/s | 1181.3 MB/s | **15.4x** | 981.0 MB/s | 5277.7 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1588.6 MB/s | 8718.3 MB/s | **5.5x** | 1509.0 MB/s | 4912.5 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1223.0 MB/s | 6033.4 MB/s | **4.9x** | 1444.8 MB/s | 4981.9 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 738.7 MB/s | 5034.4 MB/s | **6.8x** | 890.5 MB/s | 5595.3 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 732.3 MB/s | 5280.0 MB/s | **7.2x** | 898.1 MB/s | 5509.0 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 229.8 MB/s | 5608.5 MB/s | **24.4x** | 4239.0 MB/s | 6808.1 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 232.2 MB/s | 1333.5 MB/s | **5.7x** | 3079.2 MB/s | 7634.8 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 149.0 MB/s | 5720.7 MB/s | **38.4x** | 1663.9 MB/s | 6746.4 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 150.7 MB/s | 1387.8 MB/s | **9.2x** | 1570.7 MB/s | 7968.9 MB/s | **5.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.6 MB/s | 189.0 MB/s | **2.1x** | 3727.1 MB/s | 11845.4 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.1 MB/s | 179.3 MB/s | **2.1x** | 1877.2 MB/s | 2414.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.7 MB/s | 150.2 MB/s | **2.0x** | 3980.5 MB/s | 10841.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.1 MB/s | 143.7 MB/s | **2.0x** | 1908.2 MB/s | 2397.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4507.7 MB/s | 5358.0 MB/s | **1.2x** | 5292.6 MB/s | 3499.1 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5718.6 MB/s | 5611.0 MB/s | **1.0x** | 7121.0 MB/s | 4355.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1018.0 MB/s | 1828.9 MB/s | **1.8x** | 1673.8 MB/s | 5459.9 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 986.8 MB/s | 1823.0 MB/s | **1.8x** | 1669.7 MB/s | 5601.0 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5962.1 MB/s | 5612.4 MB/s | **0.9x** | 5940.6 MB/s | 9771.4 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5632.3 MB/s | 5311.8 MB/s | **0.9x** | 5453.0 MB/s | 9686.1 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 684.3 MB/s | 5065.4 MB/s | **7.4x** | 3813.6 MB/s | 9592.9 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 684.7 MB/s | 5068.6 MB/s | **7.4x** | 3660.9 MB/s | 9668.1 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1049.4 MB/s | 1890.9 MB/s | **1.8x** | 1624.0 MB/s | 10888.7 MB/s | **6.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1038.9 MB/s | 1850.5 MB/s | **1.8x** | 2129.5 MB/s | 10181.8 MB/s | **4.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.4 MB/s | 1279.3 MB/s | **13.1x** | 1776.1 MB/s | 11772.9 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.0 MB/s | 1277.3 MB/s | **12.9x** | 2087.3 MB/s | 11862.4 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12727.1 MB/s | 25389.7 MB/s | **2.0x** | 5287.4 MB/s | 4773.6 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10173.7 MB/s | 22998.9 MB/s | **2.3x** | 6192.2 MB/s | 4882.9 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2230.8 MB/s | 11458.9 MB/s | **5.1x** | 1934.1 MB/s | 3346.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2114.4 MB/s | 10932.9 MB/s | **5.2x** | 2027.6 MB/s | 3156.2 MB/s | **1.6x** | - |
