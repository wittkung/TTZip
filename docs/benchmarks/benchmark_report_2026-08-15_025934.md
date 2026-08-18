# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 18:59:34 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 681.5 MB/s | 726.1 MB/s | **1.1x** | 572.1 MB/s | 847.4 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 653.8 MB/s | 724.7 MB/s | **1.1x** | 436.9 MB/s | 762.2 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 265.6 MB/s | 323.6 MB/s | **1.2x** | 507.5 MB/s | 1110.8 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 244.6 MB/s | 342.3 MB/s | **1.4x** | 396.1 MB/s | 646.1 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 345.1 MB/s | 1017.2 MB/s | **2.9x** | 485.3 MB/s | 1861.3 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 344.6 MB/s | 731.3 MB/s | **2.1x** | 263.7 MB/s | 1526.5 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 284.5 MB/s | 1021.8 MB/s | **3.6x** | 468.1 MB/s | 1877.2 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 276.6 MB/s | 762.3 MB/s | **2.8x** | 254.3 MB/s | 1561.2 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 221.6 MB/s | 814.0 MB/s | **3.7x** | 228.0 MB/s | 675.9 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 220.4 MB/s | 813.3 MB/s | **3.7x** | 227.9 MB/s | 706.5 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 817.8 MB/s | 2082.4 MB/s | **2.5x** | 1039.5 MB/s | 3446.4 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 813.2 MB/s | 1340.6 MB/s | **1.6x** | 660.6 MB/s | 1019.2 MB/s | **1.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 250.6 MB/s | 431.2 MB/s | **1.7x** | 770.0 MB/s | 2727.9 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 242.2 MB/s | 470.9 MB/s | **1.9x** | 536.7 MB/s | 1017.2 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 551.7 MB/s | 1443.1 MB/s | **2.6x** | 779.7 MB/s | 4298.0 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 551.1 MB/s | 1282.4 MB/s | **2.3x** | 823.4 MB/s | 3461.2 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.3 MB/s | 1077.3 MB/s | **14.9x** | 785.4 MB/s | 4225.3 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.6 MB/s | 1046.0 MB/s | **14.4x** | 818.0 MB/s | 4168.7 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1457.2 MB/s | 5758.3 MB/s | **4.0x** | 1160.8 MB/s | 3101.8 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1042.7 MB/s | 3506.6 MB/s | **3.4x** | 1201.0 MB/s | 3967.0 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 602.9 MB/s | 3415.4 MB/s | **5.7x** | 645.9 MB/s | 4011.6 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 591.2 MB/s | 3450.1 MB/s | **5.8x** | 688.6 MB/s | 3472.8 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 90.3 MB/s | 3119.8 MB/s | **34.6x** | 2328.2 MB/s | 4316.8 MB/s | **1.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 84.0 MB/s | 751.7 MB/s | **8.9x** | 1875.7 MB/s | 3060.3 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 81.9 MB/s | 2814.6 MB/s | **34.4x** | 1246.5 MB/s | 3774.8 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 104.6 MB/s | 1068.5 MB/s | **10.2x** | 1363.7 MB/s | 4081.8 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.4 MB/s | 180.8 MB/s | **2.1x** | 3095.5 MB/s | 5993.4 MB/s | **1.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.1 MB/s | 148.0 MB/s | **1.8x** | 1610.7 MB/s | 2024.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 66.4 MB/s | 145.7 MB/s | **2.2x** | 2393.0 MB/s | 6592.7 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 57.1 MB/s | 126.5 MB/s | **2.2x** | 1208.5 MB/s | 1687.9 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4206.4 MB/s | 3669.6 MB/s | **0.9x** | 4636.8 MB/s | 3280.6 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 4597.5 MB/s | 3445.1 MB/s | **0.7x** | 4277.2 MB/s | 2781.3 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 722.0 MB/s | 1364.2 MB/s | **1.9x** | 887.0 MB/s | 3787.7 MB/s | **4.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 627.0 MB/s | 1194.5 MB/s | **1.9x** | 911.6 MB/s | 2981.7 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 3668.1 MB/s | 12336.8 MB/s | **3.4x** | 2944.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 3746.5 MB/s | 12992.4 MB/s | **3.5x** | 3031.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 485.2 MB/s | 12498.5 MB/s | **25.8x** | 2615.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 553.7 MB/s | 14720.1 MB/s | **26.6x** | 2443.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 962.9 MB/s | 1580.1 MB/s | **1.6x** | 1396.5 MB/s | 5661.0 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 868.7 MB/s | 1584.2 MB/s | **1.8x** | 1691.4 MB/s | 6964.0 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 85.0 MB/s | 1088.0 MB/s | **12.8x** | 1411.4 MB/s | 8275.2 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 87.4 MB/s | 1214.9 MB/s | **13.9x** | 1885.5 MB/s | 8010.8 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10920.5 MB/s | 17377.3 MB/s | **1.6x** | 4848.7 MB/s | 4137.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9649.6 MB/s | 15626.7 MB/s | **1.6x** | 5275.4 MB/s | 4420.2 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1839.3 MB/s | 7699.2 MB/s | **4.2x** | 1481.7 MB/s | 2705.9 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1941.0 MB/s | 7532.2 MB/s | **3.9x** | 910.7 MB/s | 2536.3 MB/s | **2.8x** | - |
