# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 11:34:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 857.8 MB/s | 283.3 MB/s | **0.3x** | 681.1 MB/s | 567.0 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 804.6 MB/s | 275.9 MB/s | **0.3x** | 518.1 MB/s | 419.5 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.4 MB/s | 284.7 MB/s | **1.0x** | 605.0 MB/s | 594.9 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.5 MB/s | 287.0 MB/s | **1.0x** | 461.1 MB/s | 468.2 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 394.5 MB/s | 6607.4 MB/s | **16.8x** | 562.8 MB/s | 1946.4 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 373.4 MB/s | 2168.0 MB/s | **5.8x** | 290.8 MB/s | 1947.0 MB/s | **6.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 323.3 MB/s | 6489.1 MB/s | **20.1x** | 544.3 MB/s | 1789.2 MB/s | **3.3x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 211.0 MB/s | 995.2 MB/s | **4.7x** | 267.3 MB/s | 944.8 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 282.4 MB/s | 199.5 MB/s | **0.7x** | 261.8 MB/s | 322.2 MB/s | **1.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 283.6 MB/s | 223.6 MB/s | **0.8x** | 267.3 MB/s | 315.0 MB/s | **1.2x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 967.9 MB/s | 285.2 MB/s | **0.3x** | 1206.5 MB/s | 837.3 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 775.2 MB/s | 284.9 MB/s | **0.4x** | 705.6 MB/s | 560.3 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.5 MB/s | 285.5 MB/s | **1.0x** | 867.6 MB/s | 841.6 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.8 MB/s | 280.7 MB/s | **1.0x** | 572.8 MB/s | 565.0 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 621.4 MB/s | 1568.6 MB/s | **2.5x** | 872.1 MB/s | 5934.0 MB/s | **6.8x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 601.3 MB/s | 1456.7 MB/s | **2.4x** | 919.2 MB/s | 4442.6 MB/s | **4.8x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 82.3 MB/s | 1178.5 MB/s | **14.3x** | 840.9 MB/s | 6416.9 MB/s | **7.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.4 MB/s | 1058.2 MB/s | **13.2x** | 896.6 MB/s | 4130.8 MB/s | **4.6x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1394.8 MB/s | 975.3 MB/s | **0.7x** | 1412.5 MB/s | 1074.8 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1036.6 MB/s | 797.1 MB/s | **0.8x** | 1264.2 MB/s | 1197.8 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 639.1 MB/s | 470.9 MB/s | **0.7x** | 788.1 MB/s | 1904.0 MB/s | **2.4x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 679.8 MB/s | 473.8 MB/s | **0.7x** | 774.1 MB/s | 1989.4 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 213.9 MB/s | 186.3 MB/s | **0.9x** | 3949.4 MB/s | 1613.5 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 199.9 MB/s | 181.7 MB/s | **0.9x** | 3219.5 MB/s | 1429.3 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.4 MB/s | 131.2 MB/s | **0.9x** | 1599.1 MB/s | 1441.1 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 141.0 MB/s | 178.8 MB/s | **1.3x** | 1477.9 MB/s | 1367.4 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.8 MB/s | 192.4 MB/s | **2.2x** | 3474.6 MB/s | 9165.8 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.8 MB/s | 182.8 MB/s | **2.2x** | 1714.3 MB/s | 2172.2 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.5 MB/s | 154.2 MB/s | **2.1x** | 3539.9 MB/s | 8863.3 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.7 MB/s | 150.5 MB/s | **2.1x** | 1716.4 MB/s | 2199.3 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5004.9 MB/s | 1277.9 MB/s | **0.3x** | 6267.2 MB/s | 1116.0 MB/s | **0.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5713.7 MB/s | 1287.6 MB/s | **0.2x** | 6021.1 MB/s | 4068.2 MB/s | **0.7x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 853.2 MB/s | 74.7 MB/s | **0.1x** | 1421.0 MB/s | 3597.4 MB/s | **2.5x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 884.5 MB/s | 75.5 MB/s | **0.1x** | 1119.7 MB/s | 3865.1 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5323.0 MB/s | 644.2 MB/s | **0.1x** | 5391.7 MB/s | 3376.5 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5363.5 MB/s | 614.2 MB/s | **0.1x** | 4953.9 MB/s | 3290.1 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 671.7 MB/s | 655.7 MB/s | **1.0x** | 3494.3 MB/s | 3295.9 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 671.8 MB/s | 652.0 MB/s | **1.0x** | 3291.2 MB/s | 2466.6 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.5 MB/s | 1599.1 MB/s | **1.6x** | 1719.7 MB/s | 5918.9 MB/s | **3.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.2 MB/s | 1627.6 MB/s | **1.6x** | 2013.8 MB/s | 6339.0 MB/s | **3.1x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.3 MB/s | 1150.3 MB/s | **12.1x** | 1735.8 MB/s | 10985.9 MB/s | **6.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.6 MB/s | 1152.3 MB/s | **11.9x** | 2063.7 MB/s | 6537.0 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14965.3 MB/s | 1800.2 MB/s | **0.1x** | 5928.8 MB/s | 5149.7 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10190.7 MB/s | 1304.9 MB/s | **0.1x** | 6351.5 MB/s | 5647.7 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2152.6 MB/s | 604.2 MB/s | **0.3x** | 1967.8 MB/s | 3076.1 MB/s | **1.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1928.8 MB/s | 610.3 MB/s | **0.3x** | 1867.4 MB/s | 3132.4 MB/s | **1.7x** |
