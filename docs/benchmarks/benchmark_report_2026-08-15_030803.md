# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 19:08:03 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 912.3 MB/s | 974.7 MB/s | **1.1x** | 756.4 MB/s | 1365.4 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 874.8 MB/s | 839.0 MB/s | **1.0x** | 570.7 MB/s | 1345.6 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.4 MB/s | 411.8 MB/s | **1.4x** | 634.1 MB/s | 1240.4 MB/s | **2.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.5 MB/s | 432.3 MB/s | **1.5x** | 502.2 MB/s | 1267.7 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 454.4 MB/s | 1338.9 MB/s | **2.9x** | 617.3 MB/s | 2082.6 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 410.1 MB/s | 967.3 MB/s | **2.4x** | 313.4 MB/s | 1737.7 MB/s | **5.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 368.1 MB/s | 1365.9 MB/s | **3.7x** | 601.8 MB/s | 1919.8 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 342.1 MB/s | 917.1 MB/s | **2.7x** | 311.3 MB/s | 2077.2 MB/s | **6.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 282.6 MB/s | 1115.3 MB/s | **3.9x** | 271.0 MB/s | 838.5 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 192.1 MB/s | 1122.6 MB/s | **5.8x** | 251.4 MB/s | 885.6 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1072.5 MB/s | 2575.3 MB/s | **2.4x** | 1395.9 MB/s | 4225.2 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 937.9 MB/s | 2703.4 MB/s | **2.9x** | 851.6 MB/s | 4433.5 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 299.8 MB/s | 508.2 MB/s | **1.7x** | 1009.2 MB/s | 3391.0 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.5 MB/s | 543.2 MB/s | **1.9x** | 692.1 MB/s | 3409.6 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 669.3 MB/s | 1783.2 MB/s | **2.7x** | 1065.3 MB/s | 5582.3 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 665.4 MB/s | 1650.9 MB/s | **2.5x** | 1156.0 MB/s | 4057.5 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.7 MB/s | 1275.2 MB/s | **16.0x** | 863.3 MB/s | 6723.7 MB/s | **7.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.8 MB/s | 1172.9 MB/s | **14.7x** | 1076.0 MB/s | 5214.3 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1798.1 MB/s | 8189.4 MB/s | **4.6x** | 1802.2 MB/s | 5421.1 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1356.1 MB/s | 4111.6 MB/s | **3.0x** | 1684.2 MB/s | 5484.2 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 806.5 MB/s | 4967.8 MB/s | **6.2x** | 995.1 MB/s | 6053.8 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 809.8 MB/s | 3969.8 MB/s | **4.9x** | 981.2 MB/s | 5925.1 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 236.8 MB/s | 4578.0 MB/s | **19.3x** | 4391.2 MB/s | 3530.5 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 232.8 MB/s | 1258.1 MB/s | **5.4x** | 3331.7 MB/s | 4590.1 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.6 MB/s | 5188.1 MB/s | **35.6x** | 1676.0 MB/s | 4503.9 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.4 MB/s | 1296.7 MB/s | **9.0x** | 1567.8 MB/s | 4872.1 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.5 MB/s | 182.6 MB/s | **2.1x** | 3751.1 MB/s | 10829.1 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.6 MB/s | 174.3 MB/s | **2.1x** | 1783.1 MB/s | 2402.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.6 MB/s | 145.0 MB/s | **1.9x** | 3939.4 MB/s | 10492.7 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.8 MB/s | 141.1 MB/s | **2.0x** | 1863.1 MB/s | 2402.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4110.1 MB/s | 3813.5 MB/s | **0.9x** | 7125.0 MB/s | 4170.7 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 5747.0 MB/s | 14101.3 MB/s | **2.5x** | 6405.6 MB/s | 5402.8 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1026.9 MB/s | 1756.2 MB/s | **1.7x** | 1635.6 MB/s | 5173.7 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 956.3 MB/s | 1694.0 MB/s | **1.8x** | 1665.7 MB/s | 4778.1 MB/s | **2.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5478.4 MB/s | 5018.8 MB/s | **0.9x** | 5629.2 MB/s | 3422.0 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5499.9 MB/s | 4997.9 MB/s | **0.9x** | 5370.9 MB/s | 5194.5 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 670.0 MB/s | 4685.9 MB/s | **7.0x** | 3645.5 MB/s | 4507.7 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 670.2 MB/s | 4681.4 MB/s | **7.0x** | 3301.9 MB/s | 5075.4 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1023.4 MB/s | 1850.5 MB/s | **1.8x** | 1570.0 MB/s | 9554.6 MB/s | **6.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1006.6 MB/s | 1850.5 MB/s | **1.8x** | 2078.4 MB/s | 9817.6 MB/s | **4.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.8 MB/s | 1266.8 MB/s | **13.4x** | 1743.6 MB/s | 11833.2 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.1 MB/s | 1267.9 MB/s | **13.2x** | 2101.6 MB/s | 11645.5 MB/s | **5.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13302.1 MB/s | 16072.3 MB/s | **1.2x** | 6350.8 MB/s | 4947.7 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9585.1 MB/s | 18515.6 MB/s | **1.9x** | 6393.3 MB/s | 5593.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2103.2 MB/s | 10714.5 MB/s | **5.1x** | 1961.7 MB/s | 3244.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2005.4 MB/s | 10988.5 MB/s | **5.5x** | 2012.6 MB/s | 3306.0 MB/s | **1.6x** | - |
