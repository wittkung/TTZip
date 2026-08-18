# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 19:02:58 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 644.1 MB/s | 839.3 MB/s | **1.3x** | 553.9 MB/s | 1145.3 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 767.1 MB/s | 771.3 MB/s | **1.0x** | 505.9 MB/s | 778.8 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.9 MB/s | 364.6 MB/s | **1.3x** | 546.0 MB/s | 997.7 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 270.6 MB/s | 399.9 MB/s | **1.5x** | 425.9 MB/s | 719.3 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 437.8 MB/s | 1141.2 MB/s | **2.6x** | 564.8 MB/s | 1722.0 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 441.5 MB/s | 797.4 MB/s | **1.8x** | 286.9 MB/s | 1652.6 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 370.0 MB/s | 1140.7 MB/s | **3.1x** | 545.1 MB/s | 1883.4 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 345.4 MB/s | 826.8 MB/s | **2.4x** | 269.6 MB/s | 1732.4 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 210.8 MB/s | 895.5 MB/s | **4.2x** | 237.9 MB/s | 684.3 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 207.5 MB/s | 960.6 MB/s | **4.6x** | 208.6 MB/s | 630.6 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 867.8 MB/s | 2509.9 MB/s | **2.9x** | 1294.6 MB/s | 4014.9 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 865.3 MB/s | 1510.3 MB/s | **1.7x** | 776.7 MB/s | 1290.9 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.4 MB/s | 482.6 MB/s | **1.7x** | 937.5 MB/s | 3340.9 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.0 MB/s | 526.8 MB/s | **1.8x** | 626.7 MB/s | 1138.5 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 637.2 MB/s | 1455.9 MB/s | **2.3x** | 891.5 MB/s | 4956.6 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 618.9 MB/s | 1478.7 MB/s | **2.4x** | 981.7 MB/s | 4262.4 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.9 MB/s | 1173.1 MB/s | **15.7x** | 899.6 MB/s | 6509.8 MB/s | **7.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.9 MB/s | 1114.3 MB/s | **15.1x** | 951.9 MB/s | 4578.0 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1548.5 MB/s | 5714.4 MB/s | **3.7x** | 1514.8 MB/s | 4717.6 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1259.2 MB/s | 3472.0 MB/s | **2.8x** | 1480.7 MB/s | 4187.9 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 704.1 MB/s | 4011.2 MB/s | **5.7x** | 845.0 MB/s | 4744.3 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 723.4 MB/s | 4203.8 MB/s | **5.8x** | 779.3 MB/s | 5100.3 MB/s | **6.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 160.6 MB/s | 4540.7 MB/s | **28.3x** | 4014.6 MB/s | 6539.0 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 152.9 MB/s | 1151.8 MB/s | **7.5x** | 3028.7 MB/s | 4827.9 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 125.0 MB/s | 2278.3 MB/s | **18.2x** | 1483.0 MB/s | 5948.9 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 128.7 MB/s | 1193.7 MB/s | **9.3x** | 1444.6 MB/s | 4992.9 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.4 MB/s | 174.3 MB/s | **2.2x** | 3217.7 MB/s | 10769.2 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.5 MB/s | 165.3 MB/s | **2.1x** | 1714.4 MB/s | 2200.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 62.6 MB/s | 139.4 MB/s | **2.2x** | 2879.9 MB/s | 8699.3 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.9 MB/s | 119.3 MB/s | **1.8x** | 1714.7 MB/s | 2024.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4958.4 MB/s | 3666.5 MB/s | **0.7x** | 5317.1 MB/s | 3987.8 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 5236.3 MB/s | 12759.9 MB/s | **2.4x** | 5657.0 MB/s | 3727.3 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 849.3 MB/s | 1553.2 MB/s | **1.8x** | 1606.1 MB/s | 5623.5 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 852.4 MB/s | 1586.3 MB/s | **1.9x** | 1279.3 MB/s | 5174.2 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5248.3 MB/s | 20779.7 MB/s | **4.0x** | 5503.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5106.8 MB/s | 20643.8 MB/s | **4.0x** | 5292.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 664.1 MB/s | 17983.9 MB/s | **27.1x** | 3582.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 655.3 MB/s | 18789.1 MB/s | **28.7x** | 3484.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1015.4 MB/s | 1714.2 MB/s | **1.7x** | 1600.9 MB/s | 6662.6 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1012.1 MB/s | 1792.3 MB/s | **1.8x** | 1817.6 MB/s | 6846.8 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.3 MB/s | 1179.5 MB/s | **13.1x** | 1506.3 MB/s | 10899.8 MB/s | **7.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.3 MB/s | 1204.5 MB/s | **12.8x** | 1686.5 MB/s | 11385.8 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11730.7 MB/s | 16637.8 MB/s | **1.4x** | 5455.6 MB/s | 4428.1 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10656.7 MB/s | 15840.5 MB/s | **1.5x** | 6233.2 MB/s | 5301.5 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1978.2 MB/s | 9721.1 MB/s | **4.9x** | 1872.3 MB/s | 3181.7 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1899.0 MB/s | 9848.2 MB/s | **5.2x** | 1986.9 MB/s | 3177.2 MB/s | **1.6x** | - |
