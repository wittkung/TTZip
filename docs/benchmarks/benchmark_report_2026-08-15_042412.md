# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:24:12 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 900.5 MB/s | 912.9 MB/s | **1.0x** | 648.3 MB/s | 1505.7 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 877.7 MB/s | 945.8 MB/s | **1.1x** | 566.0 MB/s | 1456.3 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 294.3 MB/s | 423.4 MB/s | **1.4x** | 607.6 MB/s | 1462.6 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.5 MB/s | 445.7 MB/s | **1.5x** | 491.6 MB/s | 1404.4 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 496.9 MB/s | 1207.1 MB/s | **2.4x** | 600.6 MB/s | 2086.5 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 465.7 MB/s | 909.4 MB/s | **2.0x** | 300.2 MB/s | 1915.0 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 402.5 MB/s | 1223.7 MB/s | **3.0x** | 590.4 MB/s | 2117.3 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 374.5 MB/s | 948.2 MB/s | **2.5x** | 298.0 MB/s | 1950.9 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 281.2 MB/s | 1021.6 MB/s | **3.6x** | 283.9 MB/s | 849.0 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 289.5 MB/s | 1077.8 MB/s | **3.7x** | 289.5 MB/s | 928.5 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1075.6 MB/s | 2592.9 MB/s | **2.4x** | 1403.6 MB/s | 4536.4 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 889.9 MB/s | 2967.0 MB/s | **3.3x** | 808.4 MB/s | 4823.8 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.9 MB/s | 547.6 MB/s | **1.9x** | 946.1 MB/s | 3035.7 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.4 MB/s | 542.7 MB/s | **1.9x** | 639.0 MB/s | 3167.4 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 636.7 MB/s | 1730.1 MB/s | **2.7x** | 904.2 MB/s | 5763.8 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 639.7 MB/s | 1581.8 MB/s | **2.5x** | 1030.7 MB/s | 4993.1 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.5 MB/s | 1229.6 MB/s | **15.9x** | 909.9 MB/s | 6868.0 MB/s | **7.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.5 MB/s | 1143.5 MB/s | **14.8x** | 967.5 MB/s | 4976.5 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1598.2 MB/s | 7543.4 MB/s | **4.7x** | 1665.4 MB/s | 5077.1 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1267.6 MB/s | 5780.1 MB/s | **4.6x** | 1554.8 MB/s | 5231.6 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 743.8 MB/s | 5282.6 MB/s | **7.1x** | 938.5 MB/s | 5690.3 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 801.8 MB/s | 4998.8 MB/s | **6.2x** | 914.8 MB/s | 6201.0 MB/s | **6.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 196.9 MB/s | 4333.5 MB/s | **22.0x** | 4139.5 MB/s | 3796.3 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 202.9 MB/s | 1325.5 MB/s | **6.5x** | 3374.3 MB/s | 5002.0 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.7 MB/s | 5266.8 MB/s | **38.2x** | 1678.3 MB/s | 4425.7 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.4 MB/s | 1344.0 MB/s | **9.9x** | 1515.5 MB/s | 4797.5 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.9 MB/s | 187.0 MB/s | **2.1x** | 3226.5 MB/s | 11312.1 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.4 MB/s | 171.1 MB/s | **2.1x** | 1859.1 MB/s | 2321.0 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.6 MB/s | 144.4 MB/s | **2.1x** | 3259.9 MB/s | 11518.5 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.2 MB/s | 136.5 MB/s | **2.0x** | 1880.2 MB/s | 2316.3 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5871.5 MB/s | 4734.4 MB/s | **0.8x** | 6341.0 MB/s | 3864.9 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5863.0 MB/s | 5426.2 MB/s | **0.9x** | 7140.2 MB/s | 4632.6 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 967.1 MB/s | 1652.6 MB/s | **1.7x** | 1533.3 MB/s | 5305.1 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 723.2 MB/s | 1679.2 MB/s | **2.3x** | 1128.5 MB/s | 5229.8 MB/s | **4.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5093.2 MB/s | 4759.3 MB/s | **0.9x** | 5798.2 MB/s | 5621.8 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 3512.7 MB/s | 4905.2 MB/s | **1.4x** | 4403.2 MB/s | 5129.8 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 666.1 MB/s | 4488.8 MB/s | **6.7x** | 3737.0 MB/s | 5025.4 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 642.6 MB/s | 4374.1 MB/s | **6.8x** | 3369.8 MB/s | 5293.3 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1013.7 MB/s | 1828.9 MB/s | **1.8x** | 1718.3 MB/s | 9325.7 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1007.8 MB/s | 1814.9 MB/s | **1.8x** | 2070.7 MB/s | 10569.0 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.1 MB/s | 1251.9 MB/s | **13.5x** | 1697.1 MB/s | 11833.5 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1230.5 MB/s | **13.1x** | 2020.0 MB/s | 10221.0 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13774.5 MB/s | 16924.9 MB/s | **1.2x** | 5285.2 MB/s | 5204.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10022.6 MB/s | 19827.2 MB/s | **2.0x** | 5152.9 MB/s | 4606.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2126.7 MB/s | 9886.3 MB/s | **4.6x** | 1765.9 MB/s | 2659.4 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1949.4 MB/s | 8775.5 MB/s | **4.5x** | 1690.0 MB/s | 2612.2 MB/s | **1.5x** | - |
