# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:43:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 901.8 MB/s | 284.0 MB/s | **0.3x** | 735.5 MB/s | 569.2 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 847.9 MB/s | 285.9 MB/s | **0.3x** | 533.0 MB/s | 476.6 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.2 MB/s | 273.4 MB/s | **0.9x** | 628.9 MB/s | 605.8 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.2 MB/s | 288.1 MB/s | **1.0x** | 486.2 MB/s | 473.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 387.9 MB/s | 5553.9 MB/s | **14.3x** | 577.1 MB/s | 2048.4 MB/s | **3.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 391.1 MB/s | 2093.5 MB/s | **5.4x** | 297.0 MB/s | 1952.1 MB/s | **6.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 336.0 MB/s | 5477.1 MB/s | **16.3x** | 578.3 MB/s | 1942.6 MB/s | **3.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 324.6 MB/s | 2173.5 MB/s | **6.7x** | 302.7 MB/s | 1888.6 MB/s | **6.2x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 293.0 MB/s | 226.7 MB/s | **0.8x** | 248.5 MB/s | 315.4 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 285.6 MB/s | 223.2 MB/s | **0.8x** | 237.6 MB/s | 313.8 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 959.9 MB/s | 282.1 MB/s | **0.3x** | 1190.5 MB/s | 859.5 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 775.8 MB/s | 267.0 MB/s | **0.3x** | 703.4 MB/s | 546.8 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.4 MB/s | 278.0 MB/s | **1.0x** | 868.5 MB/s | 822.9 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.2 MB/s | 279.6 MB/s | **1.0x** | 582.4 MB/s | 565.5 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 650.4 MB/s | 1639.2 MB/s | **2.5x** | 909.7 MB/s | 6037.1 MB/s | **6.6x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 619.8 MB/s | 1474.7 MB/s | **2.4x** | 962.7 MB/s | 4477.2 MB/s | **4.7x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 81.4 MB/s | 1172.5 MB/s | **14.4x** | 848.6 MB/s | 6669.0 MB/s | **7.9x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 82.6 MB/s | 1107.6 MB/s | **13.4x** | 935.0 MB/s | 4697.1 MB/s | **5.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1531.1 MB/s | 974.9 MB/s | **0.6x** | 1512.3 MB/s | 1399.5 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1151.6 MB/s | 882.6 MB/s | **0.8x** | 1535.1 MB/s | 1376.9 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 724.0 MB/s | 471.1 MB/s | **0.7x** | 893.8 MB/s | 2350.9 MB/s | **2.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 718.7 MB/s | 475.7 MB/s | **0.7x** | 908.1 MB/s | 2340.5 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 217.3 MB/s | 174.2 MB/s | **0.8x** | 3981.3 MB/s | 1461.5 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 212.2 MB/s | 177.7 MB/s | **0.8x** | 3139.8 MB/s | 1432.8 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.1 MB/s | 145.2 MB/s | **1.0x** | 1618.2 MB/s | 1534.4 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.5 MB/s | 187.1 MB/s | **1.3x** | 1486.0 MB/s | 1490.0 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.9 MB/s | 200.2 MB/s | **2.3x** | 3749.2 MB/s | 8548.0 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.3 MB/s | 184.9 MB/s | **2.2x** | 1789.2 MB/s | 2187.8 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.8 MB/s | 156.2 MB/s | **2.1x** | 3549.3 MB/s | 9584.0 MB/s | **2.7x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.2 MB/s | 146.1 MB/s | **2.1x** | 1743.7 MB/s | 2135.4 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4699.8 MB/s | 1470.4 MB/s | **0.3x** | 5207.7 MB/s | 1554.8 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5629.5 MB/s | 1400.2 MB/s | **0.2x** | 7109.6 MB/s | 3872.3 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 957.8 MB/s | 76.1 MB/s | **0.1x** | 1538.7 MB/s | 3769.6 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 665.8 MB/s | 61.9 MB/s | **0.1x** | 1510.8 MB/s | 3647.4 MB/s | **2.4x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5162.4 MB/s | 641.2 MB/s | **0.1x** | 5281.5 MB/s | 3557.4 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5176.3 MB/s | 659.3 MB/s | **0.1x** | 4972.4 MB/s | 3331.3 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 668.6 MB/s | 629.8 MB/s | **0.9x** | 3574.4 MB/s | 3350.3 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 655.2 MB/s | 640.8 MB/s | **1.0x** | 3521.7 MB/s | 2978.7 MB/s | **0.8x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1008.9 MB/s | 1579.5 MB/s | **1.6x** | 1669.4 MB/s | 5993.5 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1001.6 MB/s | 1631.4 MB/s | **1.6x** | 1996.4 MB/s | 7192.0 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.8 MB/s | 1106.7 MB/s | **12.2x** | 1593.1 MB/s | 11062.3 MB/s | **6.9x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.7 MB/s | 1061.7 MB/s | **11.5x** | 1977.8 MB/s | 6224.4 MB/s | **3.1x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12722.1 MB/s | 1440.8 MB/s | **0.1x** | 4664.3 MB/s | 3220.8 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9439.6 MB/s | 1099.6 MB/s | **0.1x** | 4671.2 MB/s | 2856.9 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1322.3 MB/s | 538.5 MB/s | **0.4x** | 1096.9 MB/s | 2822.2 MB/s | **2.6x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1936.6 MB/s | 542.3 MB/s | **0.3x** | 986.5 MB/s | 2909.7 MB/s | **2.9x** |
