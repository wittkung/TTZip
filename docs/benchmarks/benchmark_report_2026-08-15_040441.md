# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:04:41 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 896.0 MB/s | 894.8 MB/s | **1.0x** | 665.5 MB/s | 1188.7 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 842.5 MB/s | 778.3 MB/s | **0.9x** | 496.3 MB/s | 1136.1 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.5 MB/s | 398.5 MB/s | **1.4x** | 520.8 MB/s | 675.8 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.0 MB/s | 407.1 MB/s | **1.4x** | 447.6 MB/s | 911.9 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 457.1 MB/s | 1180.6 MB/s | **2.6x** | 452.0 MB/s | 1800.8 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 429.1 MB/s | 862.0 MB/s | **2.0x** | 298.7 MB/s | 1511.3 MB/s | **5.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 382.6 MB/s | 1271.5 MB/s | **3.3x** | 553.3 MB/s | 1851.6 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 346.2 MB/s | 912.6 MB/s | **2.6x** | 283.3 MB/s | 1339.1 MB/s | **4.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 270.5 MB/s | 987.1 MB/s | **3.6x** | 277.9 MB/s | 906.1 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 277.0 MB/s | 1060.4 MB/s | **3.8x** | 281.0 MB/s | 547.2 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 874.8 MB/s | 1670.6 MB/s | **1.9x** | 1352.3 MB/s | 3149.0 MB/s | **2.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 936.1 MB/s | 1739.8 MB/s | **1.9x** | 822.1 MB/s | 3901.2 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.7 MB/s | 515.8 MB/s | **1.7x** | 926.5 MB/s | 3182.0 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.5 MB/s | 541.3 MB/s | **1.9x** | 657.3 MB/s | 3135.9 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 634.3 MB/s | 1667.9 MB/s | **2.6x** | 920.4 MB/s | 6436.4 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 643.0 MB/s | 1542.8 MB/s | **2.4x** | 1018.8 MB/s | 4806.9 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.6 MB/s | 1226.8 MB/s | **16.0x** | 916.3 MB/s | 6898.5 MB/s | **7.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.7 MB/s | 1108.2 MB/s | **14.6x** | 990.9 MB/s | 4802.1 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1655.2 MB/s | 7598.2 MB/s | **4.6x** | 1616.6 MB/s | 4706.9 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1275.8 MB/s | 4003.3 MB/s | **3.1x** | 1601.1 MB/s | 5135.3 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 782.5 MB/s | 4887.8 MB/s | **6.2x** | 909.6 MB/s | 5736.6 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 786.9 MB/s | 5054.2 MB/s | **6.4x** | 930.2 MB/s | 5494.5 MB/s | **5.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 193.5 MB/s | 4073.7 MB/s | **21.1x** | 4027.8 MB/s | 3948.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 203.9 MB/s | 1241.4 MB/s | **6.1x** | 3288.3 MB/s | 4360.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 143.9 MB/s | 5046.3 MB/s | **35.1x** | 1588.5 MB/s | 4318.1 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.8 MB/s | 1257.1 MB/s | **8.6x** | 1489.6 MB/s | 5389.9 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.1 MB/s | 168.9 MB/s | **2.0x** | 3795.8 MB/s | 10368.6 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.4 MB/s | 174.7 MB/s | **2.2x** | 1824.4 MB/s | 2308.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.2 MB/s | 147.0 MB/s | **2.0x** | 3982.7 MB/s | 11067.6 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.4 MB/s | 141.0 MB/s | **2.0x** | 1832.5 MB/s | 2351.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5870.2 MB/s | 4027.1 MB/s | **0.7x** | 5841.3 MB/s | 4689.7 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 5890.0 MB/s | 13602.2 MB/s | **2.3x** | 5350.6 MB/s | 4877.6 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 948.9 MB/s | 1777.5 MB/s | **1.9x** | 1689.1 MB/s | 5552.4 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 967.6 MB/s | 1828.6 MB/s | **1.9x** | 1523.0 MB/s | 5982.9 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5520.0 MB/s | 4157.8 MB/s | **0.8x** | 5405.9 MB/s | 3769.1 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5132.8 MB/s | 4130.1 MB/s | **0.8x** | 4927.3 MB/s | 4771.4 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 670.7 MB/s | 4199.1 MB/s | **6.3x** | 3288.3 MB/s | 4517.3 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 688.9 MB/s | 4553.9 MB/s | **6.6x** | 3472.6 MB/s | 5005.6 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1030.8 MB/s | 1837.2 MB/s | **1.8x** | 1661.4 MB/s | 10466.4 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1012.5 MB/s | 1843.7 MB/s | **1.8x** | 1816.6 MB/s | 10337.7 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.7 MB/s | 1257.0 MB/s | **13.4x** | 1554.2 MB/s | 12089.2 MB/s | **7.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.6 MB/s | 1191.3 MB/s | **12.6x** | 1986.5 MB/s | 11565.4 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15481.3 MB/s | 19101.3 MB/s | **1.2x** | 5951.1 MB/s | 4437.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10669.1 MB/s | 20639.6 MB/s | **1.9x** | 5882.9 MB/s | 5132.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2197.4 MB/s | 10782.4 MB/s | **4.9x** | 1884.3 MB/s | 3143.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1997.6 MB/s | 10323.7 MB/s | **5.2x** | 1759.0 MB/s | 3120.3 MB/s | **1.8x** | - |
