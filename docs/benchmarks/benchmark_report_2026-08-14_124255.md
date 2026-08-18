# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:42:55 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 836.1 MB/s | 342.2 MB/s | **0.4x** | 463.0 MB/s | 278.5 MB/s | **0.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 853.2 MB/s | 227.3 MB/s | **0.3x** | 426.0 MB/s | 413.3 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.1 MB/s | 273.1 MB/s | **1.0x** | 526.9 MB/s | 290.1 MB/s | **0.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.8 MB/s | 239.9 MB/s | **0.8x** | 458.8 MB/s | 368.8 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 511.0 MB/s | 1126.7 MB/s | **2.2x** | 569.8 MB/s | 1767.2 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 489.9 MB/s | 852.1 MB/s | **1.7x** | 295.3 MB/s | 1729.5 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 402.8 MB/s | 1174.5 MB/s | **2.9x** | 574.0 MB/s | 1527.3 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 386.8 MB/s | 879.6 MB/s | **2.3x** | 300.2 MB/s | 1398.8 MB/s | **4.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 235.9 MB/s | 1056.3 MB/s | **4.5x** | 260.9 MB/s | 803.3 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 251.8 MB/s | 1035.9 MB/s | **4.1x** | 219.4 MB/s | 742.2 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1097.4 MB/s | 476.9 MB/s | **0.4x** | 1465.9 MB/s | 1796.5 MB/s | **1.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 951.3 MB/s | 294.4 MB/s | **0.3x** | 844.4 MB/s | 668.8 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 300.0 MB/s | 545.4 MB/s | **1.8x** | 1004.9 MB/s | 1766.9 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.2 MB/s | 292.4 MB/s | **1.0x** | 675.0 MB/s | 624.5 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 621.0 MB/s | 1647.1 MB/s | **2.7x** | 967.5 MB/s | 5547.4 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 650.9 MB/s | 1543.3 MB/s | **2.4x** | 1072.1 MB/s | 4313.2 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.4 MB/s | 1247.9 MB/s | **15.9x** | 980.6 MB/s | 6504.1 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.5 MB/s | 1154.4 MB/s | **14.9x** | 1040.0 MB/s | 4902.8 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1256.0 MB/s | 4377.9 MB/s | **3.5x** | 1730.5 MB/s | 4670.8 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1310.5 MB/s | 4334.7 MB/s | **3.3x** | 1638.5 MB/s | 4664.1 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 674.5 MB/s | 4139.2 MB/s | **6.1x** | 415.2 MB/s | 5162.2 MB/s | **12.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 781.1 MB/s | 4379.5 MB/s | **5.6x** | 925.7 MB/s | 5097.3 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 227.2 MB/s | 2661.7 MB/s | **11.7x** | 4379.5 MB/s | 7558.9 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (98.7%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 222.4 MB/s | 194.5 MB/s | **0.9x** | 3167.1 MB/s | 1553.7 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.9 MB/s | 4552.6 MB/s | **31.4x** | 1642.0 MB/s | 5072.9 MB/s | **3.1x** | 2_SolidBuf_IO_and_CRC32 (93.8%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 143.0 MB/s | 194.8 MB/s | **1.4x** | 1493.4 MB/s | 1507.0 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.9 MB/s | 185.3 MB/s | **2.1x** | 3823.2 MB/s | 11685.7 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.6 MB/s | 170.9 MB/s | **2.1x** | 1817.3 MB/s | 2256.8 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.8 MB/s | 144.9 MB/s | **1.9x** | 4132.6 MB/s | 11073.1 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.6 MB/s | 142.3 MB/s | **2.0x** | 1912.8 MB/s | 2428.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 5388.9 MB/s | 6364.7 MB/s | **1.2x** | 6093.3 MB/s | 6927.7 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 5888.5 MB/s | 6300.4 MB/s | **1.1x** | 7303.0 MB/s | 6795.6 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 988.2 MB/s | 1767.6 MB/s | **1.8x** | 1670.3 MB/s | 5773.2 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 871.5 MB/s | 1784.0 MB/s | **2.0x** | 1707.5 MB/s | 5725.3 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5562.8 MB/s | 2663.0 MB/s | **0.5x** | 5560.8 MB/s | 2074.5 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5440.3 MB/s | 687.1 MB/s | **0.1x** | 5230.6 MB/s | 3935.4 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.4 MB/s | 4035.0 MB/s | **6.0x** | 3801.6 MB/s | 2051.2 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 688.1 MB/s | 672.8 MB/s | **1.0x** | 3608.6 MB/s | 3714.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1039.7 MB/s | 1858.6 MB/s | **1.8x** | 1757.9 MB/s | 7030.6 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1034.1 MB/s | 1855.4 MB/s | **1.8x** | 2121.3 MB/s | 7477.2 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.8 MB/s | 1264.5 MB/s | **13.2x** | 1814.2 MB/s | 12560.3 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.4 MB/s | 1265.5 MB/s | **13.1x** | 2129.0 MB/s | 11493.3 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15747.6 MB/s | 4679.9 MB/s | **0.3x** | 6152.2 MB/s | 6699.3 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10759.2 MB/s | 4684.9 MB/s | **0.4x** | 6627.5 MB/s | 6872.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2170.2 MB/s | 9381.7 MB/s | **4.3x** | 1941.9 MB/s | 3218.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2059.3 MB/s | 9601.3 MB/s | **4.7x** | 1995.9 MB/s | 3320.9 MB/s | **1.7x** | - |
