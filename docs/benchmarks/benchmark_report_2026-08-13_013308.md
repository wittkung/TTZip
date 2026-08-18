# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-12 17:33:08 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 685.7 MB/s | 184.0 MB/s | **0.3x** | 683.8 MB/s | 1504.8 MB/s | **2.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 816.9 MB/s | 190.3 MB/s | **0.2x** | 529.7 MB/s | 1866.7 MB/s | **3.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 282.0 MB/s | 185.5 MB/s | **0.7x** | 577.4 MB/s | 2017.7 MB/s | **3.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 280.8 MB/s | 190.5 MB/s | **0.7x** | 459.8 MB/s | 2096.0 MB/s | **4.6x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 384.4 MB/s | 662.3 MB/s | **1.7x** | 551.8 MB/s | 1949.2 MB/s | **3.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 364.5 MB/s | 550.5 MB/s | **1.5x** | 290.2 MB/s | 1479.2 MB/s | **5.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 323.3 MB/s | 653.9 MB/s | **2.0x** | 540.9 MB/s | 1878.6 MB/s | **3.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 312.7 MB/s | 556.4 MB/s | **1.8x** | 290.7 MB/s | 1824.9 MB/s | **6.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 209.2 MB/s | 402.8 MB/s | **1.9x** | 235.5 MB/s | 862.3 MB/s | **3.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 268.7 MB/s | 390.1 MB/s | **1.5x** | 255.2 MB/s | 695.1 MB/s | **2.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 917.7 MB/s | 213.6 MB/s | **0.2x** | 1180.5 MB/s | 2014.5 MB/s | **1.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 778.2 MB/s | 216.3 MB/s | **0.3x** | 709.4 MB/s | 1963.0 MB/s | **2.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.9 MB/s | 218.2 MB/s | **0.8x** | 863.6 MB/s | 1956.4 MB/s | **2.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 274.4 MB/s | 216.6 MB/s | **0.8x** | 570.7 MB/s | 1936.9 MB/s | **3.4x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 612.6 MB/s | 1069.3 MB/s | **1.7x** | 899.3 MB/s | 5261.3 MB/s | **5.9x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 592.5 MB/s | 1023.5 MB/s | **1.7x** | 932.8 MB/s | 3547.3 MB/s | **3.8x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 81.0 MB/s | 829.1 MB/s | **10.2x** | 848.9 MB/s | 5219.3 MB/s | **6.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.2 MB/s | 827.7 MB/s | **10.3x** | 884.4 MB/s | 3669.2 MB/s | **4.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 344.8 MB/s | 1740.8 MB/s | **5.0x** | 1423.3 MB/s | 4724.3 MB/s | **3.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1028.5 MB/s | 1375.3 MB/s | **1.3x** | 1340.8 MB/s | 5461.1 MB/s | **4.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 664.5 MB/s | 584.8 MB/s | **0.9x** | 834.3 MB/s | 4550.0 MB/s | **5.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 646.3 MB/s | 580.0 MB/s | **0.9x** | 864.5 MB/s | 4549.2 MB/s | **5.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 201.3 MB/s | 2372.0 MB/s | **11.8x** | 3504.5 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (76.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 168.7 MB/s | 2254.0 MB/s | **13.4x** | 2682.4 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (85.4%) |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.6 MB/s | 2264.2 MB/s | **16.7x** | 1613.2 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (88.5%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.2 MB/s | 2457.3 MB/s | **17.4x** | 1436.7 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.0 MB/s | 1811.1 MB/s | **20.1x** | 3420.1 MB/s | 8940.7 MB/s | **2.6x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.1 MB/s | 990.0 MB/s | **11.9x** | 1650.5 MB/s | 2158.1 MB/s | **1.3x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.8 MB/s | 1714.3 MB/s | **22.9x** | 3427.4 MB/s | 7815.4 MB/s | **2.3x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.3 MB/s | 1019.4 MB/s | **15.8x** | 1575.4 MB/s | 2088.1 MB/s | **1.3x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4870.0 MB/s | 1189.7 MB/s | **0.2x** | 5522.3 MB/s | 4538.3 MB/s | **0.8x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4865.3 MB/s | 1372.3 MB/s | **0.3x** | 6311.5 MB/s | 7259.4 MB/s | **1.2x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 959.5 MB/s | 74.5 MB/s | **0.1x** | 1596.0 MB/s | 4403.9 MB/s | **2.8x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 800.1 MB/s | 74.2 MB/s | **0.1x** | 1456.0 MB/s | 4180.2 MB/s | **2.9x** | 2_SolidBuf_IO_and_CRC32 (90.2%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4848.5 MB/s | 1826.6 MB/s | **0.4x** | 5057.4 MB/s | 6496.9 MB/s | **1.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4646.6 MB/s | 2051.9 MB/s | **0.4x** | 4746.9 MB/s | 7241.9 MB/s | **1.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 642.9 MB/s | 2065.6 MB/s | **3.2x** | 3454.4 MB/s | 7730.2 MB/s | **2.2x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 630.9 MB/s | 2047.5 MB/s | **3.2x** | 3225.5 MB/s | 7703.8 MB/s | **2.4x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 991.8 MB/s | 538.9 MB/s | **0.5x** | 1626.8 MB/s | 8586.1 MB/s | **5.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 960.3 MB/s | 526.8 MB/s | **0.5x** | 1917.4 MB/s | 8703.4 MB/s | **4.5x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.7 MB/s | 463.1 MB/s | **5.0x** | 1634.6 MB/s | 9948.4 MB/s | **6.1x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.3 MB/s | 479.4 MB/s | **5.3x** | 1808.1 MB/s | 9570.9 MB/s | **5.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11710.0 MB/s | 1568.0 MB/s | **0.1x** | 4949.2 MB/s | 6545.8 MB/s | **1.3x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9329.8 MB/s | 1093.6 MB/s | **0.1x** | 5686.8 MB/s | 8203.7 MB/s | **1.4x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2180.9 MB/s | 595.0 MB/s | **0.3x** | 1748.9 MB/s | 2894.9 MB/s | **1.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1740.8 MB/s | 558.6 MB/s | **0.3x** | 1734.2 MB/s | 2888.8 MB/s | **1.7x** | 2_7zDec_ParallelLZMA2Decode (100.0%) |
