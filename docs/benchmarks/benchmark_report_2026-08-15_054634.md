# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:46:34 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 798.0 MB/s | 2161.4 MB/s | **2.7x** | 669.2 MB/s | 1348.0 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 858.6 MB/s | 2260.4 MB/s | **2.6x** | 545.0 MB/s | 1494.8 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 278.0 MB/s | 552.2 MB/s | **2.0x** | 570.0 MB/s | 1413.5 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 285.3 MB/s | 579.7 MB/s | **2.0x** | 491.6 MB/s | 1419.7 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 401.2 MB/s | 1201.7 MB/s | **3.0x** | 607.7 MB/s | 2261.8 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 393.3 MB/s | 933.9 MB/s | **2.4x** | 297.4 MB/s | 1923.2 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 335.1 MB/s | 1252.4 MB/s | **3.7x** | 607.0 MB/s | 2233.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 332.9 MB/s | 946.5 MB/s | **2.8x** | 297.3 MB/s | 1930.4 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 271.0 MB/s | 1048.0 MB/s | **3.9x** | 178.8 MB/s | 1115.9 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 266.8 MB/s | 1027.5 MB/s | **3.9x** | 284.9 MB/s | 1114.5 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1053.1 MB/s | 2709.1 MB/s | **2.6x** | 1375.0 MB/s | 5339.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 863.1 MB/s | 2637.4 MB/s | **3.1x** | 791.0 MB/s | 5100.3 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.4 MB/s | 565.2 MB/s | **1.9x** | 967.5 MB/s | 3759.0 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.6 MB/s | 554.0 MB/s | **1.9x** | 291.8 MB/s | 3794.5 MB/s | **13.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 660.5 MB/s | 1708.1 MB/s | **2.6x** | 971.9 MB/s | 5877.7 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 630.5 MB/s | 1615.9 MB/s | **2.6x** | 1048.5 MB/s | 4645.2 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.4 MB/s | 1244.1 MB/s | **16.7x** | 925.8 MB/s | 6568.8 MB/s | **7.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 65.1 MB/s | 1138.5 MB/s | **17.5x** | 986.3 MB/s | 4821.0 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1567.8 MB/s | 6004.7 MB/s | **3.8x** | 1547.1 MB/s | 4634.3 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1307.5 MB/s | 5756.4 MB/s | **4.4x** | 1541.7 MB/s | 4869.2 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 784.9 MB/s | 4806.0 MB/s | **6.1x** | 928.5 MB/s | 5636.7 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 811.5 MB/s | 4877.8 MB/s | **6.0x** | 922.8 MB/s | 5781.3 MB/s | **6.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 168.5 MB/s | 5620.1 MB/s | **33.4x** | 3713.7 MB/s | 5961.3 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 189.5 MB/s | 1397.0 MB/s | **7.4x** | 3228.0 MB/s | 7177.3 MB/s | **2.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 140.1 MB/s | 5335.4 MB/s | **38.1x** | 1611.8 MB/s | 5739.8 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.7 MB/s | 1373.0 MB/s | **9.7x** | 1460.5 MB/s | 7807.8 MB/s | **5.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.8 MB/s | 159.4 MB/s | **1.9x** | 1793.0 MB/s | 10835.5 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.4 MB/s | 167.1 MB/s | **2.1x** | 1800.2 MB/s | 2252.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.5 MB/s | 146.8 MB/s | **2.0x** | 3574.7 MB/s | 9150.8 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.5 MB/s | 125.8 MB/s | **1.8x** | 1704.5 MB/s | 1862.8 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4281.0 MB/s | 4913.7 MB/s | **1.1x** | 6903.4 MB/s | 3109.6 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5734.8 MB/s | 4902.9 MB/s | **0.9x** | 6475.2 MB/s | 3264.1 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 948.6 MB/s | 1582.6 MB/s | **1.7x** | 1536.1 MB/s | 4428.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 755.1 MB/s | 1731.5 MB/s | **2.3x** | 1639.4 MB/s | 5024.6 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4860.3 MB/s | 4945.7 MB/s | **1.0x** | 4083.5 MB/s | 4891.5 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4970.5 MB/s | 4307.1 MB/s | **0.9x** | 4707.3 MB/s | 6558.1 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 610.2 MB/s | 4586.9 MB/s | **7.5x** | 3540.5 MB/s | 4446.6 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 482.6 MB/s | 4555.7 MB/s | **9.4x** | 3210.4 MB/s | 5223.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1008.0 MB/s | 1817.1 MB/s | **1.8x** | 1580.2 MB/s | 6996.4 MB/s | **4.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1001.6 MB/s | 1798.4 MB/s | **1.8x** | 1956.5 MB/s | 9589.0 MB/s | **4.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.6 MB/s | 1235.1 MB/s | **13.2x** | 1694.1 MB/s | 10782.0 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.5 MB/s | 1236.0 MB/s | **13.2x** | 1906.5 MB/s | 10345.1 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11758.8 MB/s | 22580.8 MB/s | **1.9x** | 5087.5 MB/s | 4942.1 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10203.6 MB/s | 19271.1 MB/s | **1.9x** | 5981.3 MB/s | 5058.5 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2201.0 MB/s | 10187.8 MB/s | **4.6x** | 1891.1 MB/s | 3166.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1769.3 MB/s | 9053.1 MB/s | **5.1x** | 1896.6 MB/s | 3067.1 MB/s | **1.6x** | - |
