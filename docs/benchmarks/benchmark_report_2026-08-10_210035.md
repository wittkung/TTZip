# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 13:00:35 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 885.6 MB/s | 294.9 MB/s | **0.3x** | 758.7 MB/s | 570.4 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 810.9 MB/s | 294.2 MB/s | **0.4x** | 532.1 MB/s | 445.1 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.4 MB/s | 296.8 MB/s | **1.0x** | 584.1 MB/s | 562.0 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.2 MB/s | 288.0 MB/s | **1.0x** | 465.7 MB/s | 435.7 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 444.4 MB/s | 7090.4 MB/s | **16.0x** | 551.0 MB/s | 2030.7 MB/s | **3.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 443.0 MB/s | 1950.5 MB/s | **4.4x** | 286.5 MB/s | 1467.7 MB/s | **5.1x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 357.4 MB/s | 6978.4 MB/s | **19.5x** | 571.9 MB/s | 2286.5 MB/s | **4.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 327.7 MB/s | 1757.2 MB/s | **5.4x** | 290.9 MB/s | 1583.7 MB/s | **5.4x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 259.0 MB/s | 214.8 MB/s | **0.8x** | 260.8 MB/s | 347.4 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 261.4 MB/s | 213.5 MB/s | **0.8x** | 257.7 MB/s | 338.9 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 894.9 MB/s | 279.2 MB/s | **0.3x** | 1113.0 MB/s | 802.6 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 743.7 MB/s | 274.1 MB/s | **0.4x** | 670.0 MB/s | 538.7 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 279.5 MB/s | 277.6 MB/s | **1.0x** | 830.1 MB/s | 795.6 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.6 MB/s | 277.3 MB/s | **1.0x** | 548.5 MB/s | 540.0 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 603.2 MB/s | 1600.9 MB/s | **2.7x** | 846.2 MB/s | 4337.1 MB/s | **5.1x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 574.3 MB/s | 1465.8 MB/s | **2.6x** | 874.1 MB/s | 4272.1 MB/s | **4.9x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 81.2 MB/s | 1158.0 MB/s | **14.3x** | 811.5 MB/s | 6185.1 MB/s | **7.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.2 MB/s | 1067.9 MB/s | **13.3x** | 861.2 MB/s | 4726.7 MB/s | **5.5x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1267.3 MB/s | 916.1 MB/s | **0.7x** | 1216.3 MB/s | 1170.8 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 913.3 MB/s | 789.7 MB/s | **0.9x** | 1213.5 MB/s | 1097.2 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 590.8 MB/s | 456.6 MB/s | **0.8x** | 775.6 MB/s | 1876.2 MB/s | **2.4x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 636.8 MB/s | 449.2 MB/s | **0.7x** | 727.6 MB/s | 1729.4 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 194.7 MB/s | 180.2 MB/s | **0.9x** | 3672.5 MB/s | 1590.7 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 189.2 MB/s | 179.6 MB/s | **0.9x** | 2948.8 MB/s | 1456.0 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 139.6 MB/s | 181.9 MB/s | **1.3x** | 1586.5 MB/s | 1571.5 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 134.3 MB/s | 180.9 MB/s | **1.3x** | 1455.1 MB/s | 1419.8 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.0 MB/s | 196.1 MB/s | **2.3x** | 3733.1 MB/s | 7247.5 MB/s | **1.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.8 MB/s | 171.0 MB/s | **2.2x** | 1681.2 MB/s | 2140.1 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 65.7 MB/s | 130.4 MB/s | **2.0x** | 3465.3 MB/s | 6086.5 MB/s | **1.8x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 56.4 MB/s | 132.7 MB/s | **2.4x** | 1640.5 MB/s | 2121.3 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4960.4 MB/s | 1260.6 MB/s | **0.3x** | 5432.1 MB/s | 1358.5 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4788.2 MB/s | 1316.8 MB/s | **0.3x** | 5226.9 MB/s | 3340.2 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 689.2 MB/s | 64.5 MB/s | **0.1x** | 1189.4 MB/s | 3555.6 MB/s | **3.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 740.0 MB/s | 69.9 MB/s | **0.1x** | 1204.1 MB/s | 2896.1 MB/s | **2.4x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4745.7 MB/s | 609.6 MB/s | **0.1x** | 4594.6 MB/s | 2934.5 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4852.1 MB/s | 624.5 MB/s | **0.1x** | 4528.9 MB/s | 3267.7 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 642.5 MB/s | 621.8 MB/s | **1.0x** | 3416.7 MB/s | 3294.4 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 667.5 MB/s | 637.2 MB/s | **1.0x** | 3320.1 MB/s | 3241.2 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 969.0 MB/s | 1585.0 MB/s | **1.6x** | 1551.2 MB/s | 5983.9 MB/s | **3.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 978.6 MB/s | 1591.1 MB/s | **1.6x** | 1914.6 MB/s | 6565.8 MB/s | **3.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.9 MB/s | 1102.9 MB/s | **12.0x** | 1619.9 MB/s | 8132.9 MB/s | **5.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.5 MB/s | 1103.2 MB/s | **12.1x** | 1895.8 MB/s | 9871.8 MB/s | **5.2x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11639.6 MB/s | 1352.1 MB/s | **0.1x** | 4997.5 MB/s | 2178.2 MB/s | **0.4x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 5016.5 MB/s | 1162.0 MB/s | **0.2x** | 2944.9 MB/s | 2343.9 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1774.8 MB/s | 542.8 MB/s | **0.3x** | 1085.0 MB/s | 3162.9 MB/s | **2.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1422.0 MB/s | 471.0 MB/s | **0.3x** | 1460.9 MB/s | 2820.7 MB/s | **1.9x** |
