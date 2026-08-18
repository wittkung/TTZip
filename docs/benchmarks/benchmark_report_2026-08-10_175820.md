# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:58:20 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 797.1 MB/s | 268.2 MB/s | **0.3x** | 665.7 MB/s | 529.6 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 755.3 MB/s | 273.4 MB/s | **0.4x** | 480.3 MB/s | 414.8 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.0 MB/s | 270.9 MB/s | **1.0x** | 562.3 MB/s | 567.4 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 277.0 MB/s | 254.6 MB/s | **0.9x** | 458.7 MB/s | 372.9 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 385.7 MB/s | 5588.2 MB/s | **14.5x** | 537.3 MB/s | 1949.1 MB/s | **3.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 343.2 MB/s | 1548.8 MB/s | **4.5x** | 277.4 MB/s | 1401.5 MB/s | **5.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 258.7 MB/s | 4647.6 MB/s | **18.0x** | 427.6 MB/s | 1478.2 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 278.5 MB/s | 1548.4 MB/s | **5.6x** | 267.9 MB/s | 1612.8 MB/s | **6.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 136.1 MB/s | 194.3 MB/s | **1.4x** | 133.7 MB/s | 228.2 MB/s | **1.7x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 187.3 MB/s | 192.4 MB/s | **1.0x** | 160.5 MB/s | 281.0 MB/s | **1.8x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 770.2 MB/s | 257.6 MB/s | **0.3x** | 922.7 MB/s | 680.7 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 641.0 MB/s | 244.2 MB/s | **0.4x** | 578.0 MB/s | 429.8 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 247.8 MB/s | 236.7 MB/s | **1.0x** | 772.6 MB/s | 538.9 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 260.1 MB/s | 243.7 MB/s | **0.9x** | 527.7 MB/s | 472.6 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 551.0 MB/s | 1368.2 MB/s | **2.5x** | 612.1 MB/s | 4428.3 MB/s | **7.2x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 509.4 MB/s | 1094.0 MB/s | **2.1x** | 693.4 MB/s | 3594.7 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 74.1 MB/s | 780.8 MB/s | **10.5x** | 763.3 MB/s | 4906.0 MB/s | **6.4x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 70.7 MB/s | 1030.3 MB/s | **14.6x** | 708.8 MB/s | 4022.9 MB/s | **5.7x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1003.8 MB/s | 639.7 MB/s | **0.6x** | 860.6 MB/s | 698.8 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 766.1 MB/s | 584.9 MB/s | **0.8x** | 1002.3 MB/s | 826.5 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 534.2 MB/s | 400.6 MB/s | **0.8x** | 586.3 MB/s | 1696.6 MB/s | **2.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 620.0 MB/s | 406.8 MB/s | **0.7x** | 543.3 MB/s | 1402.4 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 140.2 MB/s | 142.9 MB/s | **1.0x** | 3476.8 MB/s | 1408.0 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 132.3 MB/s | 140.4 MB/s | **1.1x** | 2482.4 MB/s | 1263.3 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 114.7 MB/s | 148.3 MB/s | **1.3x** | 1411.6 MB/s | 1389.8 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 127.3 MB/s | 146.2 MB/s | **1.1x** | 1420.7 MB/s | 1352.6 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.5 MB/s | 185.8 MB/s | **2.2x** | 3370.9 MB/s | 8808.9 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.9 MB/s | 172.2 MB/s | **2.2x** | 1686.0 MB/s | 2077.2 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.4 MB/s | 152.0 MB/s | **2.2x** | 3347.1 MB/s | 7688.7 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 66.3 MB/s | 140.8 MB/s | **2.1x** | 1647.0 MB/s | 2179.2 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4384.1 MB/s | 1278.6 MB/s | **0.3x** | 5748.9 MB/s | 1528.7 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5200.5 MB/s | 1297.2 MB/s | **0.2x** | 6121.6 MB/s | 3781.1 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 737.3 MB/s | 75.4 MB/s | **0.1x** | 1111.6 MB/s | 2495.4 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 727.2 MB/s | 73.1 MB/s | **0.1x** | 1240.9 MB/s | 3276.9 MB/s | **2.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4962.7 MB/s | 635.6 MB/s | **0.1x** | 4857.2 MB/s | 3200.0 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5045.9 MB/s | 648.2 MB/s | **0.1x** | 4776.4 MB/s | 3410.9 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 650.8 MB/s | 649.6 MB/s | **1.0x** | 3411.8 MB/s | 3338.2 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 638.6 MB/s | 628.6 MB/s | **1.0x** | 3401.1 MB/s | 3166.1 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1003.3 MB/s | 1538.2 MB/s | **1.5x** | 1630.0 MB/s | 5827.4 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 992.4 MB/s | 1484.1 MB/s | **1.5x** | 1860.5 MB/s | 6009.0 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.9 MB/s | 1103.1 MB/s | **12.1x** | 1639.3 MB/s | 10058.8 MB/s | **6.1x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.7 MB/s | 1115.2 MB/s | **12.2x** | 1878.3 MB/s | 10027.5 MB/s | **5.3x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9771.5 MB/s | 1118.3 MB/s | **0.1x** | 4568.8 MB/s | 4196.1 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 7170.8 MB/s | 657.9 MB/s | **0.1x** | 4063.0 MB/s | 2069.7 MB/s | **0.5x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1795.2 MB/s | 538.1 MB/s | **0.3x** | 1213.9 MB/s | 2433.6 MB/s | **2.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1895.5 MB/s | 549.3 MB/s | **0.3x** | 1061.4 MB/s | 2809.1 MB/s | **2.6x** |
