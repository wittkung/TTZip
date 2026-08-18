# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:47:29 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 948.6 MB/s | 893.7 MB/s | **0.9x** | 724.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 896.1 MB/s | 581.0 MB/s | **0.6x** | 568.0 MB/s | 561.9 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.7 MB/s | 409.5 MB/s | **1.4x** | 620.1 MB/s | 803.3 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.0 MB/s | 242.4 MB/s | **0.8x** | 481.5 MB/s | 495.3 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 512.0 MB/s | 1348.3 MB/s | **2.6x** | 565.1 MB/s | 2170.8 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 493.9 MB/s | 896.5 MB/s | **1.8x** | 304.5 MB/s | 1890.7 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 410.7 MB/s | 1269.3 MB/s | **3.1x** | 582.8 MB/s | 2075.5 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 390.7 MB/s | 950.0 MB/s | **2.4x** | 307.7 MB/s | 1917.0 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 271.1 MB/s | 1073.3 MB/s | **4.0x** | 276.1 MB/s | 1005.5 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 278.8 MB/s | 1077.5 MB/s | **3.9x** | 280.1 MB/s | 975.4 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.03 MB (0.2%) | 1128.2 MB/s | 6303.8 MB/s | **5.6x** | 1479.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 973.9 MB/s | 963.9 MB/s | **1.0x** | 881.5 MB/s | 844.3 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.6 MB/s | 533.7 MB/s | **1.8x** | 1048.2 MB/s | 1894.3 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.2 MB/s | 290.5 MB/s | **1.0x** | 692.9 MB/s | 680.4 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 693.1 MB/s | 1761.9 MB/s | **2.5x** | 1012.3 MB/s | 6641.0 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 667.6 MB/s | 1672.4 MB/s | **2.5x** | 1088.0 MB/s | 5032.4 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.5 MB/s | 1278.8 MB/s | **16.1x** | 1010.7 MB/s | 6569.3 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 81.1 MB/s | 1205.5 MB/s | **14.9x** | 1066.0 MB/s | 4770.3 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1741.4 MB/s | 4214.7 MB/s | **2.4x** | 1780.3 MB/s | 5181.3 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1314.1 MB/s | 4662.1 MB/s | **3.5x** | 1661.5 MB/s | 5327.9 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 795.4 MB/s | 4529.6 MB/s | **5.7x** | 920.3 MB/s | 6238.7 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 766.3 MB/s | 4865.4 MB/s | **6.3x** | 950.4 MB/s | 5540.3 MB/s | **5.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 240.7 MB/s | 4832.9 MB/s | **20.1x** | 4479.7 MB/s | 8130.7 MB/s | **1.8x** | 2_SolidBuf_IO_and_CRC32 (94.2%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 232.9 MB/s | 230.0 MB/s | **1.0x** | 3492.2 MB/s | 3389.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 147.3 MB/s | 4646.5 MB/s | **31.6x** | 1732.7 MB/s | 7715.8 MB/s | **4.5x** | 2_SolidBuf_IO_and_CRC32 (94.1%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 147.5 MB/s | 146.5 MB/s | **1.0x** | 1584.4 MB/s | 1558.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.1 MB/s | 188.0 MB/s | **2.1x** | 3882.8 MB/s | 11222.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.6 MB/s | 176.8 MB/s | **2.1x** | 1941.5 MB/s | 2396.5 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 77.0 MB/s | 150.8 MB/s | **2.0x** | 4237.9 MB/s | 11467.3 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.6 MB/s | 143.9 MB/s | **2.0x** | 1931.9 MB/s | 2410.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 6130.6 MB/s | 6495.2 MB/s | **1.1x** | 6952.8 MB/s | 7140.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 6060.9 MB/s | 6650.3 MB/s | **1.1x** | 6476.9 MB/s | 6213.5 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1023.5 MB/s | 1768.8 MB/s | **1.7x** | 1568.1 MB/s | 5712.3 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 897.7 MB/s | 1674.4 MB/s | **1.9x** | 1555.3 MB/s | 5625.6 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 5334.0 MB/s | 4729.5 MB/s | **0.9x** | 6051.4 MB/s | 6710.3 MB/s | **1.1x** | 2_SolidBuf_IO_and_CRC32 (92.7%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5471.5 MB/s | 5516.9 MB/s | **1.0x** | 5419.8 MB/s | 5317.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 689.7 MB/s | 4739.9 MB/s | **6.9x** | 3688.9 MB/s | 2100.0 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 685.0 MB/s | 686.4 MB/s | **1.0x** | 3561.1 MB/s | 3710.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1054.8 MB/s | 1856.3 MB/s | **1.8x** | 1805.5 MB/s | 6941.3 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1052.7 MB/s | 1865.4 MB/s | **1.8x** | 2116.3 MB/s | 7065.8 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.3 MB/s | 1280.7 MB/s | **13.0x** | 1826.8 MB/s | 11718.7 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.7 MB/s | 1268.5 MB/s | **12.8x** | 2136.0 MB/s | 12297.3 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15525.0 MB/s | 4770.4 MB/s | **0.3x** | 6184.0 MB/s | 6918.5 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11233.4 MB/s | 4832.1 MB/s | **0.4x** | 6579.4 MB/s | 7279.6 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2125.5 MB/s | 9549.5 MB/s | **4.5x** | 1978.6 MB/s | 3349.0 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2031.6 MB/s | 9385.3 MB/s | **4.6x** | 1667.9 MB/s | 3303.4 MB/s | **2.0x** | - |
