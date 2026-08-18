# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:40:19 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 920.2 MB/s | 407.1 MB/s | **0.4x** | 734.8 MB/s | 646.4 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 890.6 MB/s | 247.8 MB/s | **0.3x** | 566.4 MB/s | 477.8 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.4 MB/s | 420.3 MB/s | **1.4x** | 645.6 MB/s | 756.4 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.7 MB/s | 246.3 MB/s | **0.9x** | 510.2 MB/s | 473.6 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 506.6 MB/s | 1304.6 MB/s | **2.6x** | 613.6 MB/s | 1919.9 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 483.6 MB/s | 914.1 MB/s | **1.9x** | 311.1 MB/s | 1720.7 MB/s | **5.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 409.3 MB/s | 1286.2 MB/s | **3.1x** | 610.0 MB/s | 2154.2 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 391.1 MB/s | 948.2 MB/s | **2.4x** | 309.6 MB/s | 1904.9 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 272.5 MB/s | 1096.3 MB/s | **4.0x** | 265.0 MB/s | 1008.4 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 237.0 MB/s | 1083.1 MB/s | **4.6x** | 270.6 MB/s | 1064.9 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1070.6 MB/s | 563.2 MB/s | **0.5x** | 1450.9 MB/s | 1920.1 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 980.3 MB/s | 289.3 MB/s | **0.3x** | 863.0 MB/s | 677.9 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.8 MB/s | 574.6 MB/s | **1.9x** | 1030.4 MB/s | 1960.5 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.5 MB/s | 290.2 MB/s | **1.0x** | 693.2 MB/s | 680.4 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 692.2 MB/s | 1796.5 MB/s | **2.6x** | 1017.5 MB/s | 6582.4 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 667.5 MB/s | 1662.9 MB/s | **2.5x** | 1080.6 MB/s | 4817.1 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 81.3 MB/s | 1279.2 MB/s | **15.7x** | 940.8 MB/s | 6985.4 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.4 MB/s | 1171.9 MB/s | **14.6x** | 1076.8 MB/s | 5048.3 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1723.1 MB/s | 4732.2 MB/s | **2.7x** | 1735.4 MB/s | 5237.9 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1333.2 MB/s | 4870.4 MB/s | **3.7x** | 1623.6 MB/s | 5291.3 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 795.4 MB/s | 4598.4 MB/s | **5.8x** | 930.9 MB/s | 6166.6 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 746.7 MB/s | 4404.8 MB/s | **5.9x** | 917.0 MB/s | 5619.4 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 195.0 MB/s | 4537.5 MB/s | **23.3x** | 4356.9 MB/s | 8009.9 MB/s | **1.8x** | 2_SolidBuf_IO_and_CRC32 (93.2%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 203.0 MB/s | 185.0 MB/s | **0.9x** | 3136.7 MB/s | 1472.0 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.9 MB/s | 3889.3 MB/s | **28.6x** | 1715.8 MB/s | 6874.2 MB/s | **4.0x** | 2_SolidBuf_IO_and_CRC32 (91.5%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 140.6 MB/s | 186.8 MB/s | **1.3x** | 1559.8 MB/s | 1565.0 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 91.1 MB/s | 190.7 MB/s | **2.1x** | 4213.2 MB/s | 11405.8 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.0 MB/s | 178.5 MB/s | **2.1x** | 1925.3 MB/s | 2407.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.4 MB/s | 140.0 MB/s | **1.9x** | 4054.9 MB/s | 9651.8 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.2 MB/s | 143.9 MB/s | **2.1x** | 1812.1 MB/s | 2444.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 5908.3 MB/s | 5939.5 MB/s | **1.0x** | 6912.7 MB/s | 6612.3 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 6088.1 MB/s | 5950.1 MB/s | **1.0x** | 7138.2 MB/s | 6713.2 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1007.3 MB/s | 1603.2 MB/s | **1.6x** | 1694.1 MB/s | 5801.6 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 916.6 MB/s | 1751.2 MB/s | **1.9x** | 972.5 MB/s | 5983.5 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5218.2 MB/s | 3858.5 MB/s | **0.7x** | 5624.0 MB/s | 1944.6 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5211.6 MB/s | 678.1 MB/s | **0.1x** | 5415.8 MB/s | 3795.5 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 674.7 MB/s | 4682.5 MB/s | **6.9x** | 3880.6 MB/s | 2068.3 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 681.6 MB/s | 667.1 MB/s | **1.0x** | 3685.9 MB/s | 3557.5 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1012.1 MB/s | 1831.4 MB/s | **1.8x** | 1735.3 MB/s | 6874.0 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1011.7 MB/s | 1815.1 MB/s | **1.8x** | 2050.2 MB/s | 6566.6 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.4 MB/s | 1238.6 MB/s | **13.4x** | 1684.5 MB/s | 12370.1 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.2 MB/s | 1232.3 MB/s | **13.2x** | 2024.4 MB/s | 11964.7 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13774.9 MB/s | 4271.7 MB/s | **0.3x** | 6261.8 MB/s | 7595.0 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10346.6 MB/s | 4014.7 MB/s | **0.4x** | 6858.3 MB/s | 6879.5 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2060.1 MB/s | 7827.7 MB/s | **3.8x** | 1874.9 MB/s | 3163.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1932.9 MB/s | 7419.9 MB/s | **3.8x** | 1912.6 MB/s | 3040.2 MB/s | **1.6x** | - |
