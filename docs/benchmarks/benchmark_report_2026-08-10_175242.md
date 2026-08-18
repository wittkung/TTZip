# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:52:42 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 627.4 MB/s | 238.6 MB/s | **0.4x** | 444.8 MB/s | 381.8 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 673.4 MB/s | 272.1 MB/s | **0.4x** | 387.8 MB/s | 391.1 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 265.8 MB/s | 263.3 MB/s | **1.0x** | 531.8 MB/s | 480.9 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.0 MB/s | 268.4 MB/s | **1.0x** | 456.2 MB/s | 387.8 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 389.9 MB/s | 5494.0 MB/s | **14.1x** | 566.3 MB/s | 2147.8 MB/s | **3.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 364.0 MB/s | 1509.4 MB/s | **4.1x** | 279.0 MB/s | 1639.0 MB/s | **5.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 309.5 MB/s | 4969.2 MB/s | **16.1x** | 540.3 MB/s | 1173.5 MB/s | **2.2x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 303.0 MB/s | 1777.4 MB/s | **5.9x** | 284.6 MB/s | 1531.5 MB/s | **5.4x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 261.9 MB/s | 173.4 MB/s | **0.7x** | 220.2 MB/s | 237.7 MB/s | **1.1x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 260.6 MB/s | 213.1 MB/s | **0.8x** | 211.2 MB/s | 317.8 MB/s | **1.5x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 868.7 MB/s | 268.8 MB/s | **0.3x** | 1107.5 MB/s | 771.9 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 782.0 MB/s | 252.2 MB/s | **0.3x** | 695.2 MB/s | 542.4 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.5 MB/s | 274.1 MB/s | **1.0x** | 859.8 MB/s | 824.3 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 267.6 MB/s | 278.5 MB/s | **1.0x** | 557.3 MB/s | 541.9 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 583.0 MB/s | 1579.6 MB/s | **2.7x** | 827.6 MB/s | 5074.3 MB/s | **6.1x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 564.0 MB/s | 1410.3 MB/s | **2.5x** | 858.3 MB/s | 4233.8 MB/s | **4.9x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.8 MB/s | 1139.1 MB/s | **14.1x** | 812.4 MB/s | 6034.4 MB/s | **7.4x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 79.9 MB/s | 960.4 MB/s | **12.0x** | 858.0 MB/s | 4459.3 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1258.0 MB/s | 843.6 MB/s | **0.7x** | 1165.7 MB/s | 912.2 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 920.0 MB/s | 425.5 MB/s | **0.5x** | 1155.8 MB/s | 992.0 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 631.6 MB/s | 435.4 MB/s | **0.7x** | 721.3 MB/s | 1683.9 MB/s | **2.3x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 638.2 MB/s | 456.5 MB/s | **0.7x** | 752.8 MB/s | 1878.8 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 157.3 MB/s | 167.5 MB/s | **1.1x** | 3650.4 MB/s | 1403.5 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 180.4 MB/s | 149.0 MB/s | **0.8x** | 2945.3 MB/s | 1355.1 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 132.1 MB/s | 170.3 MB/s | **1.3x** | 1522.5 MB/s | 1515.0 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 135.4 MB/s | 172.7 MB/s | **1.3x** | 1403.8 MB/s | 1351.2 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.1 MB/s | 186.7 MB/s | **2.2x** | 3471.1 MB/s | 6889.5 MB/s | **2.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.1 MB/s | 176.5 MB/s | **2.2x** | 1693.2 MB/s | 2138.8 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.9 MB/s | 144.3 MB/s | **2.0x** | 3370.6 MB/s | 7315.6 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.9 MB/s | 146.0 MB/s | **2.1x** | 1684.4 MB/s | 2119.2 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4468.4 MB/s | 1239.4 MB/s | **0.3x** | 5853.5 MB/s | 1504.0 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5027.3 MB/s | 1330.9 MB/s | **0.3x** | 6516.2 MB/s | 3692.7 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 877.2 MB/s | 75.0 MB/s | **0.1x** | 1485.5 MB/s | 3567.0 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 817.6 MB/s | 73.9 MB/s | **0.1x** | 1314.9 MB/s | 3444.6 MB/s | **2.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5051.8 MB/s | 640.2 MB/s | **0.1x** | 5037.6 MB/s | 2984.0 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4975.2 MB/s | 605.2 MB/s | **0.1x** | 4845.3 MB/s | 2767.5 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 660.5 MB/s | 652.6 MB/s | **1.0x** | 3590.4 MB/s | 3373.4 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 659.3 MB/s | 644.2 MB/s | **1.0x** | 3520.8 MB/s | 3416.7 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 999.2 MB/s | 1594.7 MB/s | **1.6x** | 1689.5 MB/s | 6085.9 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.0 MB/s | 1623.3 MB/s | **1.6x** | 2031.1 MB/s | 8066.0 MB/s | **4.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.5 MB/s | 1126.3 MB/s | **12.2x** | 1671.7 MB/s | 9561.0 MB/s | **5.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.3 MB/s | 1097.1 MB/s | **11.9x** | 2000.1 MB/s | 10454.7 MB/s | **5.2x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13770.5 MB/s | 1653.0 MB/s | **0.1x** | 4997.7 MB/s | 4424.9 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9384.3 MB/s | 1136.6 MB/s | **0.1x** | 5484.0 MB/s | 3424.3 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1815.9 MB/s | 574.4 MB/s | **0.3x** | 1708.5 MB/s | 3008.3 MB/s | **1.8x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1856.0 MB/s | 585.7 MB/s | **0.3x** | 1766.1 MB/s | 3075.6 MB/s | **1.7x** |
