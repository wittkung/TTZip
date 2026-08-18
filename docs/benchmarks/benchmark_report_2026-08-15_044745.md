# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:47:45 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 703.2 MB/s | 922.7 MB/s | **1.3x** | 748.7 MB/s | 1651.0 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 723.9 MB/s | 843.4 MB/s | **1.2x** | 512.2 MB/s | 1621.3 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.6 MB/s | 404.6 MB/s | **1.4x** | 603.2 MB/s | 1073.2 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 275.5 MB/s | 368.7 MB/s | **1.3x** | 447.9 MB/s | 1131.2 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 524.9 MB/s | 1136.5 MB/s | **2.2x** | 554.9 MB/s | 2064.8 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 478.7 MB/s | 821.3 MB/s | **1.7x** | 296.0 MB/s | 1735.0 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 402.1 MB/s | 1209.2 MB/s | **3.0x** | 573.8 MB/s | 2120.8 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 374.4 MB/s | 885.8 MB/s | **2.4x** | 293.2 MB/s | 1848.3 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 279.1 MB/s | 1028.7 MB/s | **3.7x** | 281.8 MB/s | 1039.9 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 267.9 MB/s | 1023.3 MB/s | **3.8x** | 285.3 MB/s | 1077.1 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1067.4 MB/s | 862.5 MB/s | **0.8x** | 1381.7 MB/s | 5588.2 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 840.5 MB/s | 2930.0 MB/s | **3.5x** | 788.3 MB/s | 5215.3 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 246.4 MB/s | 538.9 MB/s | **2.2x** | 951.8 MB/s | 4043.4 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.3 MB/s | 569.6 MB/s | **2.0x** | 588.8 MB/s | 3932.6 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 646.8 MB/s | 1699.7 MB/s | **2.6x** | 738.8 MB/s | 5922.8 MB/s | **8.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 623.5 MB/s | 1526.5 MB/s | **2.4x** | 514.9 MB/s | 4551.3 MB/s | **8.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.0 MB/s | 1240.3 MB/s | **16.5x** | 913.7 MB/s | 6499.5 MB/s | **7.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.8 MB/s | 1146.4 MB/s | **15.7x** | 647.1 MB/s | 4724.9 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1074.6 MB/s | 7815.5 MB/s | **7.3x** | 1008.8 MB/s | 3779.0 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1182.9 MB/s | 1802.1 MB/s | **1.5x** | 1373.2 MB/s | 4065.2 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 755.8 MB/s | 4207.4 MB/s | **5.6x** | 935.4 MB/s | 5408.7 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 537.2 MB/s | 4954.2 MB/s | **9.2x** | 592.3 MB/s | 5802.3 MB/s | **9.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 205.0 MB/s | 5704.2 MB/s | **27.8x** | 3511.9 MB/s | 6455.8 MB/s | **1.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 203.8 MB/s | 1366.7 MB/s | **6.7x** | 3341.1 MB/s | 8549.9 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.1 MB/s | 5263.6 MB/s | **38.4x** | 1633.9 MB/s | 6691.5 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 130.4 MB/s | 1352.1 MB/s | **10.4x** | 1473.6 MB/s | 8173.7 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.6 MB/s | 177.2 MB/s | **2.1x** | 3608.3 MB/s | 10837.2 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.2 MB/s | 171.1 MB/s | **2.1x** | 1774.8 MB/s | 2281.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.5 MB/s | 148.3 MB/s | **2.0x** | 3718.4 MB/s | 11038.8 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.3 MB/s | 137.7 MB/s | **2.0x** | 1838.5 MB/s | 2264.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5135.8 MB/s | 5426.3 MB/s | **1.1x** | 6883.0 MB/s | 3620.1 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 6022.0 MB/s | 5596.1 MB/s | **0.9x** | 7193.7 MB/s | 4652.5 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 972.3 MB/s | 1764.8 MB/s | **1.8x** | 1709.0 MB/s | 5902.9 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 854.4 MB/s | 1740.4 MB/s | **2.0x** | 1641.0 MB/s | 5089.4 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5532.1 MB/s | 4471.5 MB/s | **0.8x** | 5741.6 MB/s | 8577.5 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5431.9 MB/s | 4539.9 MB/s | **0.8x** | 5514.1 MB/s | 9495.6 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 649.9 MB/s | 4420.3 MB/s | **6.8x** | 3532.0 MB/s | 9615.3 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 672.7 MB/s | 4558.3 MB/s | **6.8x** | 3515.6 MB/s | 9569.6 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1034.8 MB/s | 1838.7 MB/s | **1.8x** | 1691.2 MB/s | 10537.1 MB/s | **6.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1011.3 MB/s | 1842.1 MB/s | **1.8x** | 2065.1 MB/s | 10495.4 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.8 MB/s | 1250.1 MB/s | **13.2x** | 1595.8 MB/s | 12441.4 MB/s | **7.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.1 MB/s | 1253.3 MB/s | **13.2x** | 1946.2 MB/s | 12181.3 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15191.9 MB/s | 19362.5 MB/s | **1.3x** | 5229.4 MB/s | 4409.1 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10892.0 MB/s | 22327.1 MB/s | **2.0x** | 5513.9 MB/s | 4830.7 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2212.2 MB/s | 10403.9 MB/s | **4.7x** | 1903.0 MB/s | 3253.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2003.2 MB/s | 10697.7 MB/s | **5.3x** | 1890.8 MB/s | 3154.8 MB/s | **1.7x** | - |
