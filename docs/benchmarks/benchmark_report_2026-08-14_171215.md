# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 09:12:15 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 809.2 MB/s | 778.8 MB/s | **1.0x** | 674.2 MB/s | 558.8 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 758.8 MB/s | 491.4 MB/s | **0.6x** | 490.6 MB/s | 456.8 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 265.4 MB/s | 357.7 MB/s | **1.3x** | 529.8 MB/s | 573.8 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 269.9 MB/s | 219.9 MB/s | **0.8x** | 444.4 MB/s | 418.9 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 387.6 MB/s | 1146.6 MB/s | **3.0x** | 518.4 MB/s | 1928.4 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 383.1 MB/s | 463.0 MB/s | **1.2x** | 155.6 MB/s | 1432.1 MB/s | **9.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 339.0 MB/s | 1057.7 MB/s | **3.1x** | 509.3 MB/s | 1697.9 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 329.0 MB/s | 815.0 MB/s | **2.5x** | 275.5 MB/s | 1714.5 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 245.3 MB/s | 990.2 MB/s | **4.0x** | 268.5 MB/s | 998.6 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 238.9 MB/s | 986.4 MB/s | **4.1x** | 274.0 MB/s | 1041.6 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1003.7 MB/s | 2429.0 MB/s | **2.4x** | 1269.1 MB/s | 5056.9 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 807.3 MB/s | 754.3 MB/s | **0.9x** | 705.3 MB/s | 703.1 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.9 MB/s | 390.5 MB/s | **1.4x** | 928.9 MB/s | 1248.3 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.1 MB/s | 280.7 MB/s | **1.0x** | 616.2 MB/s | 601.0 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 628.2 MB/s | 1358.9 MB/s | **2.2x** | 884.0 MB/s | 5761.4 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 619.4 MB/s | 1506.0 MB/s | **2.4x** | 926.8 MB/s | 4202.4 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.8 MB/s | 1185.2 MB/s | **16.1x** | 899.9 MB/s | 5653.8 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.7 MB/s | 1099.4 MB/s | **14.7x** | 956.1 MB/s | 4770.5 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1567.8 MB/s | 3869.9 MB/s | **2.5x** | 1431.7 MB/s | 4313.3 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1199.3 MB/s | 4001.8 MB/s | **3.3x** | 1388.7 MB/s | 4201.1 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 699.6 MB/s | 3326.3 MB/s | **4.8x** | 827.9 MB/s | 5061.1 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 716.2 MB/s | 4288.7 MB/s | **6.0x** | 823.9 MB/s | 5112.5 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 166.3 MB/s | 4490.1 MB/s | **27.0x** | 3950.9 MB/s | 5699.3 MB/s | **1.4x** | 2_SolidBuf_IO_and_CRC32 (92.7%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 158.0 MB/s | 150.3 MB/s | **1.0x** | 3070.3 MB/s | 3105.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 132.3 MB/s | 3863.9 MB/s | **29.2x** | 1610.8 MB/s | 5430.2 MB/s | **3.4x** | 2_SolidBuf_IO_and_CRC32 (91.9%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 129.6 MB/s | 132.5 MB/s | **1.0x** | 1336.1 MB/s | 1383.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.3 MB/s | 178.8 MB/s | **2.3x** | 3282.0 MB/s | 9712.6 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.9 MB/s | 148.9 MB/s | **2.0x** | 1707.5 MB/s | 2144.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.5 MB/s | 134.6 MB/s | **2.0x** | 3504.1 MB/s | 9988.9 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 63.6 MB/s | 130.5 MB/s | **2.1x** | 1746.3 MB/s | 2099.8 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5876.2 MB/s | 7316.0 MB/s | **1.2x** | 6437.8 MB/s | 6223.7 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 4434.1 MB/s | 7361.2 MB/s | **1.7x** | 5323.9 MB/s | 5893.7 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 870.9 MB/s | 1524.9 MB/s | **1.8x** | 1468.1 MB/s | 5439.0 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 891.0 MB/s | 1223.3 MB/s | **1.4x** | 1523.4 MB/s | 4949.2 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 5237.4 MB/s | 4396.6 MB/s | **0.8x** | 5694.8 MB/s | 1609.1 MB/s | **0.3x** | 2_SolidBuf_IO_and_CRC32 (92.0%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 4742.2 MB/s | 4337.4 MB/s | **0.9x** | 4867.9 MB/s | 4897.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 629.5 MB/s | 4248.6 MB/s | **6.7x** | 3703.0 MB/s | 10322.9 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 630.2 MB/s | 631.5 MB/s | **1.0x** | 3405.4 MB/s | 3437.2 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 952.6 MB/s | 1815.9 MB/s | **1.9x** | 1557.1 MB/s | 10271.5 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1025.3 MB/s | 1816.1 MB/s | **1.8x** | 1882.1 MB/s | 7022.0 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1219.8 MB/s | **13.0x** | 1578.3 MB/s | 12323.2 MB/s | **7.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.2 MB/s | 1231.4 MB/s | **13.2x** | 2011.0 MB/s | 12026.7 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14972.4 MB/s | 12286.1 MB/s | **0.8x** | 6147.4 MB/s | 6853.8 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11150.6 MB/s | 14323.0 MB/s | **1.3x** | 6336.1 MB/s | 6663.2 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1949.6 MB/s | 8795.4 MB/s | **4.5x** | 1699.2 MB/s | 3110.9 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1913.9 MB/s | 7761.3 MB/s | **4.1x** | 1374.3 MB/s | 3056.4 MB/s | **2.2x** | - |
