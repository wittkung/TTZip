# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:12:27 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 892.3 MB/s | 2263.2 MB/s | **2.5x** | 691.3 MB/s | 1493.2 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 862.2 MB/s | 2374.7 MB/s | **2.8x** | 490.3 MB/s | 1393.3 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 294.0 MB/s | 569.3 MB/s | **1.9x** | 632.7 MB/s | 1344.8 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.5 MB/s | 617.4 MB/s | **2.1x** | 504.5 MB/s | 1379.0 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 440.6 MB/s | 1268.2 MB/s | **2.9x** | 597.1 MB/s | 2063.0 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 431.1 MB/s | 944.3 MB/s | **2.2x** | 306.1 MB/s | 1882.9 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 377.7 MB/s | 1275.7 MB/s | **3.4x** | 600.6 MB/s | 2135.3 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 373.1 MB/s | 972.8 MB/s | **2.6x** | 308.4 MB/s | 1921.5 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 279.3 MB/s | 1119.8 MB/s | **4.0x** | 304.9 MB/s | 1075.2 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 288.2 MB/s | 1065.0 MB/s | **3.7x** | 290.1 MB/s | 1126.1 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1085.0 MB/s | 2746.0 MB/s | **2.5x** | 1451.9 MB/s | 5815.0 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 957.1 MB/s | 3185.2 MB/s | **3.3x** | 828.4 MB/s | 5813.1 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.4 MB/s | 560.7 MB/s | **1.9x** | 991.7 MB/s | 3965.4 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.4 MB/s | 576.1 MB/s | **2.0x** | 694.6 MB/s | 3767.5 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 679.2 MB/s | 1778.8 MB/s | **2.6x** | 1089.6 MB/s | 6431.3 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 669.4 MB/s | 1663.3 MB/s | **2.5x** | 1165.5 MB/s | 4783.3 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.0 MB/s | 1265.6 MB/s | **15.8x** | 976.6 MB/s | 6850.3 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.5 MB/s | 1204.2 MB/s | **15.0x** | 1043.7 MB/s | 5187.0 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1680.9 MB/s | 9412.1 MB/s | **5.6x** | 1775.4 MB/s | 6952.2 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1291.3 MB/s | 6127.7 MB/s | **4.7x** | 1583.0 MB/s | 7108.5 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 794.7 MB/s | 5545.0 MB/s | **7.0x** | 933.7 MB/s | 5768.6 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 804.0 MB/s | 5329.5 MB/s | **6.6x** | 1006.0 MB/s | 5706.0 MB/s | **5.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 231.7 MB/s | 5237.4 MB/s | **22.6x** | 4078.7 MB/s | 7293.9 MB/s | **1.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 229.4 MB/s | 1326.1 MB/s | **5.8x** | 3293.6 MB/s | 8050.4 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.5 MB/s | 5787.1 MB/s | **40.9x** | 1688.6 MB/s | 7112.1 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.8 MB/s | 1394.0 MB/s | **10.3x** | 1436.2 MB/s | 8568.8 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.6 MB/s | 185.6 MB/s | **2.1x** | 3161.6 MB/s | 10651.0 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.9 MB/s | 178.4 MB/s | **2.1x** | 1803.8 MB/s | 2386.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.1 MB/s | 150.2 MB/s | **2.0x** | 3775.3 MB/s | 10531.7 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.4 MB/s | 141.4 MB/s | **2.0x** | 1617.1 MB/s | 2342.9 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5730.6 MB/s | 4677.3 MB/s | **0.8x** | 6785.2 MB/s | 5391.9 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5655.6 MB/s | 5066.1 MB/s | **0.9x** | 7070.8 MB/s | 6685.4 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 982.3 MB/s | 1756.6 MB/s | **1.8x** | 1609.1 MB/s | 5298.5 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 963.8 MB/s | 1763.3 MB/s | **1.8x** | 1524.6 MB/s | 5317.6 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5257.7 MB/s | 4781.8 MB/s | **0.9x** | 5643.6 MB/s | 8565.3 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5227.9 MB/s | 4812.6 MB/s | **0.9x** | 5299.5 MB/s | 9224.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 679.0 MB/s | 4976.9 MB/s | **7.3x** | 3705.3 MB/s | 9745.1 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 677.4 MB/s | 4973.7 MB/s | **7.3x** | 3469.6 MB/s | 9506.0 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1021.9 MB/s | 1843.8 MB/s | **1.8x** | 1740.8 MB/s | 8084.0 MB/s | **4.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1016.7 MB/s | 1840.1 MB/s | **1.8x** | 2037.8 MB/s | 10562.5 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.9 MB/s | 1260.2 MB/s | **13.3x** | 1731.4 MB/s | 12210.4 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.2 MB/s | 1252.3 MB/s | **13.0x** | 2067.0 MB/s | 11547.7 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15048.5 MB/s | 18970.3 MB/s | **1.3x** | 5882.9 MB/s | 7774.3 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10498.8 MB/s | 21403.3 MB/s | **2.0x** | 6150.3 MB/s | 9317.4 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2169.8 MB/s | 10817.0 MB/s | **5.0x** | 1948.7 MB/s | 3297.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2061.8 MB/s | 10599.5 MB/s | **5.1x** | 2029.5 MB/s | 3282.0 MB/s | **1.6x** | - |
