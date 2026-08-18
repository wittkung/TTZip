# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 17:10:26 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 892.1 MB/s | 1052.2 MB/s | **1.2x** | 667.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 829.2 MB/s | 728.3 MB/s | **0.9x** | 526.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 281.7 MB/s | 388.0 MB/s | **1.4x** | 569.5 MB/s | 1073.3 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 277.8 MB/s | 327.6 MB/s | **1.2x** | 433.6 MB/s | 641.3 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 427.8 MB/s | 1148.2 MB/s | **2.7x** | 523.7 MB/s | 1820.6 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 452.9 MB/s | 822.7 MB/s | **1.8x** | 295.7 MB/s | 1588.2 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 382.0 MB/s | 1221.3 MB/s | **3.2x** | 567.7 MB/s | 1497.5 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 361.1 MB/s | 898.2 MB/s | **2.5x** | 294.1 MB/s | 1709.5 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 265.6 MB/s | 883.4 MB/s | **3.3x** | 198.2 MB/s | 788.1 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 271.7 MB/s | 1058.5 MB/s | **3.9x** | 276.3 MB/s | 824.9 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.02 MB (0.2%) | 1109.6 MB/s | 6169.5 MB/s | **5.6x** | 1138.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.02 MB (0.2%) | 955.6 MB/s | 1433.8 MB/s | **1.5x** | 833.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.6 MB/s | 523.8 MB/s | **1.8x** | 885.0 MB/s | 3922.7 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.6 MB/s | 417.7 MB/s | **1.4x** | 665.1 MB/s | 1177.8 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 662.1 MB/s | 1588.7 MB/s | **2.4x** | 898.0 MB/s | 6067.3 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 635.9 MB/s | 1567.5 MB/s | **2.5x** | 951.4 MB/s | 4587.8 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.9 MB/s | 1214.3 MB/s | **16.0x** | 937.4 MB/s | 6241.6 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.6 MB/s | 1148.1 MB/s | **15.0x** | 904.4 MB/s | 4362.7 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1579.9 MB/s | 6713.9 MB/s | **4.2x** | 1555.6 MB/s | 5973.2 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1239.1 MB/s | 3747.3 MB/s | **3.0x** | 1569.2 MB/s | 5843.7 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 797.3 MB/s | 3912.8 MB/s | **4.9x** | 908.1 MB/s | 5068.9 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 732.7 MB/s | 3960.0 MB/s | **5.4x** | 861.2 MB/s | 3517.8 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 153.0 MB/s | 4126.1 MB/s | **27.0x** | 3891.3 MB/s | 5112.5 MB/s | **1.3x** | 2_SolidBuf_IO_and_CRC32 (90.9%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 149.9 MB/s | 4038.9 MB/s | **26.9x** | 2757.9 MB/s | 5529.8 MB/s | **2.0x** | 2_SolidBuf_IO_and_CRC32 (89.6%) |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 110.4 MB/s | 3207.8 MB/s | **29.1x** | 1512.5 MB/s | 4709.4 MB/s | **3.1x** | 2_SolidBuf_IO_and_CRC32 (86.7%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 113.4 MB/s | 3477.4 MB/s | **30.7x** | 1383.9 MB/s | 5630.4 MB/s | **4.1x** | 2_SolidBuf_IO_and_CRC32 (89.3%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.7 MB/s | 183.7 MB/s | **2.0x** | 3776.3 MB/s | 10785.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.6 MB/s | 175.6 MB/s | **2.1x** | 1694.9 MB/s | 2134.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.9 MB/s | 147.8 MB/s | **2.0x** | 3342.9 MB/s | 9918.3 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.1 MB/s | 141.5 MB/s | **2.1x** | 1480.3 MB/s | 2086.6 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4575.3 MB/s | 2717.2 MB/s | **0.6x** | 5674.8 MB/s | 5106.8 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 12.63 MB (12.6%) | 5357.6 MB/s | 7079.1 MB/s | **1.3x** | 5148.0 MB/s | 6989.1 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 843.0 MB/s | 1399.0 MB/s | **1.7x** | 1428.3 MB/s | 4518.8 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 823.9 MB/s | 1564.2 MB/s | **1.9x** | 1490.7 MB/s | 4853.8 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5229.7 MB/s | 18258.1 MB/s | **3.5x** | 5099.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4821.0 MB/s | 13250.5 MB/s | **2.7x** | 4869.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 635.5 MB/s | 16150.2 MB/s | **25.4x** | 3463.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 632.5 MB/s | 13412.9 MB/s | **21.2x** | 3191.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1015.5 MB/s | 1697.4 MB/s | **1.7x** | 1713.5 MB/s | 6609.2 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1015.0 MB/s | 1767.9 MB/s | **1.7x** | 2004.5 MB/s | 5315.1 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.8 MB/s | 1217.5 MB/s | **12.8x** | 1704.2 MB/s | 10739.4 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.7 MB/s | 1166.5 MB/s | **12.7x** | 2010.1 MB/s | 10665.6 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12874.4 MB/s | 10472.2 MB/s | **0.8x** | 5515.0 MB/s | 6769.0 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10034.6 MB/s | 9845.0 MB/s | **1.0x** | 5941.8 MB/s | 8061.5 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1936.4 MB/s | 8675.2 MB/s | **4.5x** | 1260.3 MB/s | 2634.3 MB/s | **2.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1781.9 MB/s | 9206.0 MB/s | **5.2x** | 1599.8 MB/s | 2244.0 MB/s | **1.4x** | - |
