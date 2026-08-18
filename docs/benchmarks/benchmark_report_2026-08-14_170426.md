# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 09:04:26 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 827.1 MB/s | 1125.2 MB/s | **1.4x** | 443.8 MB/s | 5652.9 MB/s | **12.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 748.2 MB/s | 564.7 MB/s | **0.8x** | 496.7 MB/s | 447.9 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.6 MB/s | 402.3 MB/s | **1.4x** | 539.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.1 MB/s | 243.4 MB/s | **0.8x** | 450.4 MB/s | 412.9 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 413.0 MB/s | 1211.0 MB/s | **2.9x** | 534.8 MB/s | 286.7 MB/s | **0.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 326.3 MB/s | 502.6 MB/s | **1.5x** | 266.4 MB/s | 1324.3 MB/s | **5.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 351.6 MB/s | 1184.5 MB/s | **3.4x** | 502.7 MB/s | 1660.3 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 306.2 MB/s | 884.0 MB/s | **2.9x** | 276.1 MB/s | 1653.5 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 194.7 MB/s | 798.2 MB/s | **4.1x** | 293.6 MB/s | 568.7 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 249.2 MB/s | 1058.4 MB/s | **4.2x** | 287.7 MB/s | 583.3 MB/s | **2.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.03 MB (0.2%) | 1079.0 MB/s | 6888.4 MB/s | **6.4x** | 1406.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 975.1 MB/s | 903.0 MB/s | **0.9x** | 865.5 MB/s | 813.4 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 305.4 MB/s | 506.9 MB/s | **1.7x** | 824.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.5 MB/s | 286.4 MB/s | **1.0x** | 622.7 MB/s | 614.8 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 612.4 MB/s | 1616.0 MB/s | **2.6x** | 779.5 MB/s | 5579.9 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 607.1 MB/s | 1418.0 MB/s | **2.3x** | 970.7 MB/s | 3863.6 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.0 MB/s | 1204.4 MB/s | **16.1x** | 896.5 MB/s | 5971.1 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.0 MB/s | 1148.2 MB/s | **14.9x** | 1013.4 MB/s | 4194.5 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1443.6 MB/s | 3700.2 MB/s | **2.6x** | 1552.0 MB/s | 4437.8 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1264.4 MB/s | 3990.3 MB/s | **3.2x** | 1593.1 MB/s | 4290.5 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 769.0 MB/s | 3585.1 MB/s | **4.7x** | 972.8 MB/s | 4928.9 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 779.7 MB/s | 4456.4 MB/s | **5.7x** | 938.2 MB/s | 4713.8 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 227.1 MB/s | 4628.9 MB/s | **20.4x** | 3913.2 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (93.1%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 206.8 MB/s | 205.6 MB/s | **1.0x** | 3380.8 MB/s | 3245.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.8 MB/s | 4660.3 MB/s | **32.0x** | 1565.6 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (93.8%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 144.1 MB/s | 145.6 MB/s | **1.0x** | 1450.3 MB/s | 1457.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.8 MB/s | 179.4 MB/s | **2.0x** | 1637.9 MB/s | 10753.4 MB/s | **6.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.7 MB/s | 167.0 MB/s | **2.1x** | 1818.5 MB/s | 2264.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 65.0 MB/s | 136.5 MB/s | **2.1x** | 2128.7 MB/s | 10361.8 MB/s | **4.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 65.2 MB/s | 132.1 MB/s | **2.0x** | 1701.2 MB/s | 2212.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5603.7 MB/s | 7629.5 MB/s | **1.4x** | 6452.8 MB/s | 5830.1 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5402.7 MB/s | 7521.4 MB/s | **1.4x** | 6212.1 MB/s | 5758.8 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 929.1 MB/s | 1420.2 MB/s | **1.5x** | 1650.0 MB/s | 5272.1 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 898.9 MB/s | 1727.8 MB/s | **1.9x** | 1646.9 MB/s | 4976.7 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 5303.1 MB/s | 4607.4 MB/s | **0.9x** | 5810.9 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (93.5%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5232.0 MB/s | 5168.7 MB/s | **1.0x** | 4646.5 MB/s | 5140.6 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 662.3 MB/s | 4384.2 MB/s | **6.6x** | 3688.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 664.3 MB/s | 654.7 MB/s | **1.0x** | 3193.6 MB/s | 3062.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 982.7 MB/s | 1706.3 MB/s | **1.7x** | 1465.8 MB/s | 5826.2 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 986.4 MB/s | 1729.6 MB/s | **1.8x** | 1934.7 MB/s | 6648.4 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.4 MB/s | 1159.2 MB/s | **12.7x** | 1505.0 MB/s | 11311.3 MB/s | **7.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 89.5 MB/s | 1215.5 MB/s | **13.6x** | 2013.1 MB/s | 10532.6 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12674.3 MB/s | 10547.3 MB/s | **0.8x** | 5690.2 MB/s | 6497.7 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10087.2 MB/s | 9578.1 MB/s | **0.9x** | 5864.4 MB/s | 6050.2 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1798.5 MB/s | 7871.1 MB/s | **4.4x** | 1663.1 MB/s | 2494.8 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1734.3 MB/s | 7390.8 MB/s | **4.3x** | 1642.1 MB/s | 3040.9 MB/s | **1.9x** | - |
