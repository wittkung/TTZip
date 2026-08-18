# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 11:13:19 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 819.8 MB/s | 135.7 MB/s | **0.2x** | 713.5 MB/s | 440.8 MB/s | **0.6x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 824.0 MB/s | 283.3 MB/s | **0.3x** | 525.4 MB/s | 438.6 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.0 MB/s | 275.2 MB/s | **1.0x** | 597.4 MB/s | 509.7 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.8 MB/s | 227.2 MB/s | **0.8x** | 456.8 MB/s | 431.7 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 380.1 MB/s | 4071.1 MB/s | **10.7x** | 584.1 MB/s | 1670.6 MB/s | **2.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 368.7 MB/s | 2065.3 MB/s | **5.6x** | 283.0 MB/s | 1818.5 MB/s | **6.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 318.3 MB/s | 5052.1 MB/s | **15.9x** | 547.8 MB/s | 1943.2 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 309.3 MB/s | 2001.5 MB/s | **6.5x** | 292.2 MB/s | 1615.5 MB/s | **5.5x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 256.1 MB/s | 97.3 MB/s | **0.4x** | 248.6 MB/s | 312.8 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 276.2 MB/s | 210.3 MB/s | **0.8x** | 257.5 MB/s | 233.3 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 903.4 MB/s | 262.6 MB/s | **0.3x** | 1142.3 MB/s | 811.1 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 655.7 MB/s | 273.5 MB/s | **0.4x** | 589.4 MB/s | 511.4 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 249.3 MB/s | 251.5 MB/s | **1.0x** | 725.3 MB/s | 687.4 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 254.2 MB/s | 262.9 MB/s | **1.0x** | 507.6 MB/s | 487.1 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 538.9 MB/s | 1462.9 MB/s | **2.7x** | 759.7 MB/s | 4381.3 MB/s | **5.8x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 530.1 MB/s | 1269.6 MB/s | **2.4x** | 779.5 MB/s | 4009.6 MB/s | **5.1x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 82.1 MB/s | 997.2 MB/s | **12.1x** | 845.9 MB/s | 4770.7 MB/s | **5.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 78.7 MB/s | 1083.0 MB/s | **13.8x** | 851.6 MB/s | 4339.2 MB/s | **5.1x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1155.9 MB/s | 875.2 MB/s | **0.8x** | 1072.0 MB/s | 891.9 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 903.0 MB/s | 729.9 MB/s | **0.8x** | 1172.3 MB/s | 968.8 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 593.8 MB/s | 430.0 MB/s | **0.7x** | 699.1 MB/s | 1581.8 MB/s | **2.3x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 620.9 MB/s | 444.4 MB/s | **0.7x** | 598.9 MB/s | 1811.8 MB/s | **3.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 207.5 MB/s | 182.2 MB/s | **0.9x** | 3752.0 MB/s | 1579.1 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 160.9 MB/s | 163.3 MB/s | **1.0x** | 2915.9 MB/s | 1375.2 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 140.3 MB/s | 141.4 MB/s | **1.0x** | 1579.5 MB/s | 1453.1 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 144.3 MB/s | 178.7 MB/s | **1.2x** | 1474.0 MB/s | 1468.1 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.8 MB/s | 196.1 MB/s | **2.2x** | 3520.0 MB/s | 6633.8 MB/s | **1.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.3 MB/s | 133.8 MB/s | **1.7x** | 1604.1 MB/s | 2035.1 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.1 MB/s | 149.0 MB/s | **2.0x** | 3471.4 MB/s | 8642.8 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.4 MB/s | 148.5 MB/s | **2.1x** | 1751.3 MB/s | 2101.3 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5528.1 MB/s | 1496.5 MB/s | **0.3x** | 5190.2 MB/s | 1602.1 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5378.6 MB/s | 1418.4 MB/s | **0.3x** | 7046.6 MB/s | 4199.1 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1009.2 MB/s | 78.4 MB/s | **0.1x** | 1573.4 MB/s | 3592.9 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 926.7 MB/s | 78.6 MB/s | **0.1x** | 1590.3 MB/s | 3899.6 MB/s | **2.5x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4031.3 MB/s | 591.4 MB/s | **0.1x** | 4054.8 MB/s | 3351.0 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 3845.0 MB/s | 571.3 MB/s | **0.1x** | 3616.0 MB/s | 2690.1 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 667.4 MB/s | 619.3 MB/s | **0.9x** | 3708.2 MB/s | 3383.4 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 662.5 MB/s | 643.4 MB/s | **1.0x** | 3488.6 MB/s | 3552.4 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1024.3 MB/s | 1609.4 MB/s | **1.6x** | 1721.2 MB/s | 6535.5 MB/s | **3.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1020.4 MB/s | 1643.6 MB/s | **1.6x** | 2007.5 MB/s | 9387.7 MB/s | **4.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.9 MB/s | 1151.4 MB/s | **12.0x** | 1720.2 MB/s | 11363.3 MB/s | **6.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.2 MB/s | 1142.1 MB/s | **11.9x** | 2041.0 MB/s | 6089.5 MB/s | **3.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14939.7 MB/s | 1447.4 MB/s | **0.1x** | 5887.5 MB/s | 5098.5 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10098.9 MB/s | 1297.2 MB/s | **0.1x** | 6194.9 MB/s | 3785.7 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2069.1 MB/s | 602.4 MB/s | **0.3x** | 1849.3 MB/s | 3343.9 MB/s | **1.8x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1952.7 MB/s | 600.9 MB/s | **0.3x** | 1567.8 MB/s | 3168.6 MB/s | **2.0x** |
