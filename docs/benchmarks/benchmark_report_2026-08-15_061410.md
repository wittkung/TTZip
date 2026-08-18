# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:14:10 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 877.9 MB/s | 2199.5 MB/s | **2.5x** | 654.8 MB/s | 1331.2 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 787.5 MB/s | 2242.9 MB/s | **2.8x** | 506.7 MB/s | 1483.4 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.4 MB/s | 550.9 MB/s | **1.9x** | 585.2 MB/s | 1287.8 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.1 MB/s | 591.5 MB/s | **2.1x** | 458.6 MB/s | 1229.4 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 434.1 MB/s | 1178.1 MB/s | **2.7x** | 567.2 MB/s | 1876.5 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 413.2 MB/s | 907.7 MB/s | **2.2x** | 283.0 MB/s | 1848.4 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 331.4 MB/s | 1083.9 MB/s | **3.3x** | 568.7 MB/s | 2210.0 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 318.9 MB/s | 849.2 MB/s | **2.7x** | 292.2 MB/s | 1888.7 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 258.8 MB/s | 887.9 MB/s | **3.4x** | 278.2 MB/s | 1046.4 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 258.7 MB/s | 921.8 MB/s | **3.6x** | 267.6 MB/s | 1010.6 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 967.2 MB/s | 2806.8 MB/s | **2.9x** | 1268.4 MB/s | 4370.3 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 877.9 MB/s | 3020.7 MB/s | **3.4x** | 825.8 MB/s | 5808.0 MB/s | **7.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 278.8 MB/s | 546.0 MB/s | **2.0x** | 893.8 MB/s | 3568.5 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.2 MB/s | 550.7 MB/s | **2.0x** | 603.4 MB/s | 3506.7 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 633.4 MB/s | 1634.7 MB/s | **2.6x** | 922.2 MB/s | 5357.9 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 609.3 MB/s | 1556.1 MB/s | **2.6x** | 860.6 MB/s | 4459.6 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.3 MB/s | 1201.0 MB/s | **16.2x** | 851.4 MB/s | 6228.7 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.9 MB/s | 1106.1 MB/s | **15.2x** | 898.2 MB/s | 4049.5 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1544.5 MB/s | 8625.1 MB/s | **5.6x** | 1348.5 MB/s | 4715.5 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1197.4 MB/s | 5707.0 MB/s | **4.8x** | 1328.7 MB/s | 5061.5 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 695.2 MB/s | 4709.8 MB/s | **6.8x** | 860.2 MB/s | 5114.6 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 737.0 MB/s | 4687.9 MB/s | **6.4x** | 853.7 MB/s | 5133.8 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 182.5 MB/s | 4902.9 MB/s | **26.9x** | 4091.8 MB/s | 6774.1 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 160.6 MB/s | 1299.0 MB/s | **8.1x** | 3090.8 MB/s | 8067.9 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 133.0 MB/s | 5316.6 MB/s | **40.0x** | 1649.1 MB/s | 6702.0 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 131.6 MB/s | 1352.9 MB/s | **10.3x** | 1501.9 MB/s | 8345.3 MB/s | **5.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.8 MB/s | 180.2 MB/s | **2.1x** | 3488.2 MB/s | 9970.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.6 MB/s | 173.8 MB/s | **2.1x** | 1738.1 MB/s | 2358.9 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.6 MB/s | 144.5 MB/s | **2.0x** | 3637.4 MB/s | 10267.3 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.6 MB/s | 138.5 MB/s | **2.0x** | 1680.9 MB/s | 2249.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5039.3 MB/s | 4543.2 MB/s | **0.9x** | 4587.2 MB/s | 3764.7 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5229.7 MB/s | 4247.3 MB/s | **0.8x** | 6892.5 MB/s | 4579.7 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 966.6 MB/s | 1751.3 MB/s | **1.8x** | 1524.2 MB/s | 4574.3 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 943.0 MB/s | 1724.7 MB/s | **1.8x** | 1530.8 MB/s | 4849.6 MB/s | **3.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5079.3 MB/s | 5134.9 MB/s | **1.0x** | 5463.0 MB/s | 8734.8 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4927.6 MB/s | 4897.2 MB/s | **1.0x** | 5157.2 MB/s | 8843.5 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 646.4 MB/s | 4880.5 MB/s | **7.5x** | 3395.6 MB/s | 9288.2 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 644.9 MB/s | 4789.6 MB/s | **7.4x** | 2968.5 MB/s | 8234.1 MB/s | **2.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1014.3 MB/s | 1816.7 MB/s | **1.8x** | 1716.8 MB/s | 9668.5 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.0 MB/s | 1858.1 MB/s | **1.8x** | 2014.1 MB/s | 9712.3 MB/s | **4.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.9 MB/s | 1252.1 MB/s | **13.2x** | 1723.4 MB/s | 11421.1 MB/s | **6.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.2 MB/s | 1259.2 MB/s | **13.1x** | 2064.1 MB/s | 11410.2 MB/s | **5.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12805.6 MB/s | 18805.0 MB/s | **1.5x** | 5809.3 MB/s | 4809.0 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9837.2 MB/s | 21288.7 MB/s | **2.2x** | 5835.3 MB/s | 5817.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2268.4 MB/s | 10677.6 MB/s | **4.7x** | 1931.3 MB/s | 3270.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2098.5 MB/s | 10240.2 MB/s | **4.9x** | 1999.6 MB/s | 3226.5 MB/s | **1.6x** | - |
