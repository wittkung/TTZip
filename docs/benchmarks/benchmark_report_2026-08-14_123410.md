# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:34:10 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 939.9 MB/s | 403.1 MB/s | **0.4x** | 792.3 MB/s | 606.6 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 929.0 MB/s | 251.0 MB/s | **0.3x** | 576.5 MB/s | 502.8 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 298.1 MB/s | 432.0 MB/s | **1.4x** | 671.8 MB/s | 753.2 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 298.7 MB/s | 255.2 MB/s | **0.9x** | 519.9 MB/s | 481.4 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 538.8 MB/s | 1296.4 MB/s | **2.4x** | 636.0 MB/s | 2240.7 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 484.2 MB/s | 919.1 MB/s | **1.9x** | 306.4 MB/s | 1840.8 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 428.4 MB/s | 1273.6 MB/s | **3.0x** | 622.6 MB/s | 2122.9 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 396.8 MB/s | 980.0 MB/s | **2.5x** | 310.8 MB/s | 1990.8 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 240.0 MB/s | 1091.4 MB/s | **4.5x** | 255.8 MB/s | 863.1 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 304.0 MB/s | 1127.6 MB/s | **3.7x** | 254.2 MB/s | 876.1 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1103.7 MB/s | 550.3 MB/s | **0.5x** | 1476.8 MB/s | 1936.5 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1000.5 MB/s | 302.1 MB/s | **0.3x** | 869.3 MB/s | 692.9 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.1 MB/s | 478.0 MB/s | **1.6x** | 948.2 MB/s | 1827.7 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 303.2 MB/s | 291.2 MB/s | **1.0x** | 708.1 MB/s | 670.5 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 677.8 MB/s | 1816.6 MB/s | **2.7x** | 1021.6 MB/s | 6912.5 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 670.2 MB/s | 1643.3 MB/s | **2.5x** | 1179.1 MB/s | 5076.7 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.4 MB/s | 1281.2 MB/s | **16.6x** | 995.0 MB/s | 7665.0 MB/s | **7.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.7 MB/s | 1208.6 MB/s | **15.6x** | 1078.7 MB/s | 5498.6 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1522.5 MB/s | 4896.7 MB/s | **3.2x** | 1683.6 MB/s | 5212.2 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1339.9 MB/s | 4676.1 MB/s | **3.5x** | 1722.8 MB/s | 5262.2 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 799.5 MB/s | 4625.8 MB/s | **5.8x** | 1002.4 MB/s | 6092.5 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 829.9 MB/s | 3303.2 MB/s | **4.0x** | 1004.7 MB/s | 6112.4 MB/s | **6.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 243.3 MB/s | 4781.6 MB/s | **19.7x** | 4291.0 MB/s | 8186.5 MB/s | **1.9x** | 2_SolidBuf_IO_and_CRC32 (93.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 231.9 MB/s | 196.6 MB/s | **0.8x** | 3383.9 MB/s | 1556.2 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 153.2 MB/s | 4392.1 MB/s | **28.7x** | 1703.5 MB/s | 7255.1 MB/s | **4.3x** | 2_SolidBuf_IO_and_CRC32 (93.0%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 151.9 MB/s | 197.9 MB/s | **1.3x** | 1557.7 MB/s | 1534.7 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 91.1 MB/s | 186.8 MB/s | **2.1x** | 4036.1 MB/s | 11037.8 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.4 MB/s | 173.4 MB/s | **2.1x** | 1793.3 MB/s | 2364.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.2 MB/s | 149.1 MB/s | **2.0x** | 4019.2 MB/s | 10909.2 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 142.6 MB/s | **2.0x** | 1804.6 MB/s | 2367.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 5811.5 MB/s | 6027.7 MB/s | **1.0x** | 6838.3 MB/s | 6472.7 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 5255.2 MB/s | 6140.3 MB/s | **1.2x** | 7344.2 MB/s | 6842.6 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1045.3 MB/s | 1744.0 MB/s | **1.7x** | 1720.3 MB/s | 5463.5 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 987.4 MB/s | 1807.1 MB/s | **1.8x** | 1710.4 MB/s | 5673.0 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5394.2 MB/s | 2674.4 MB/s | **0.5x** | 6003.9 MB/s | 2095.6 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5375.4 MB/s | 690.7 MB/s | **0.1x** | 5804.7 MB/s | 3913.8 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 685.5 MB/s | 4762.1 MB/s | **6.9x** | 4014.4 MB/s | 2111.6 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 686.8 MB/s | 682.8 MB/s | **1.0x** | 3806.1 MB/s | 3803.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1036.0 MB/s | 1859.0 MB/s | **1.8x** | 1806.2 MB/s | 7340.1 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1037.3 MB/s | 1860.8 MB/s | **1.8x** | 2159.1 MB/s | 7725.3 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.5 MB/s | 1246.0 MB/s | **12.9x** | 1810.0 MB/s | 12698.0 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.0 MB/s | 1264.8 MB/s | **13.0x** | 1978.9 MB/s | 12408.5 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15825.5 MB/s | 4240.2 MB/s | **0.3x** | 6711.6 MB/s | 7244.6 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10519.4 MB/s | 4276.8 MB/s | **0.4x** | 6912.9 MB/s | 7469.4 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2209.6 MB/s | 9575.8 MB/s | **4.3x** | 2014.6 MB/s | 3396.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2051.7 MB/s | 9689.6 MB/s | **4.7x** | 2022.4 MB/s | 3376.4 MB/s | **1.7x** | - |
