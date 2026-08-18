# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:37:33 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 854.6 MB/s | 926.0 MB/s | **1.1x** | 711.7 MB/s | 1340.4 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 839.7 MB/s | 913.7 MB/s | **1.1x** | 552.9 MB/s | 1406.6 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.4 MB/s | 428.7 MB/s | **1.5x** | 587.5 MB/s | 1380.8 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.4 MB/s | 450.6 MB/s | **1.6x** | 489.5 MB/s | 1319.6 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 458.9 MB/s | 1243.5 MB/s | **2.7x** | 602.0 MB/s | 2040.4 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 431.2 MB/s | 909.5 MB/s | **2.1x** | 300.8 MB/s | 1843.5 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 379.0 MB/s | 1250.1 MB/s | **3.3x** | 600.6 MB/s | 2199.1 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 344.8 MB/s | 928.5 MB/s | **2.7x** | 295.7 MB/s | 1897.4 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 269.2 MB/s | 1078.9 MB/s | **4.0x** | 280.2 MB/s | 1109.6 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 200.3 MB/s | 1050.1 MB/s | **5.2x** | 285.9 MB/s | 1095.4 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1049.2 MB/s | 2561.5 MB/s | **2.4x** | 1391.9 MB/s | 5534.3 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 933.6 MB/s | 2899.2 MB/s | **3.1x** | 829.1 MB/s | 5513.1 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.7 MB/s | 570.9 MB/s | **1.9x** | 974.2 MB/s | 3906.2 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.4 MB/s | 572.5 MB/s | **2.0x** | 671.4 MB/s | 3910.2 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 647.3 MB/s | 1768.7 MB/s | **2.7x** | 942.6 MB/s | 6329.9 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 646.5 MB/s | 1620.6 MB/s | **2.5x** | 1057.8 MB/s | 4888.0 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.2 MB/s | 1256.8 MB/s | **16.5x** | 922.0 MB/s | 7071.0 MB/s | **7.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 78.4 MB/s | 1136.2 MB/s | **14.5x** | 1024.9 MB/s | 4998.1 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1581.1 MB/s | 9616.5 MB/s | **6.1x** | 1628.7 MB/s | 5498.1 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1281.5 MB/s | 5883.3 MB/s | **4.6x** | 1544.8 MB/s | 5330.1 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 789.2 MB/s | 5235.7 MB/s | **6.6x** | 934.9 MB/s | 5676.0 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 812.6 MB/s | 5302.3 MB/s | **6.5x** | 944.5 MB/s | 5815.2 MB/s | **6.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 218.1 MB/s | 5100.5 MB/s | **23.4x** | 3875.9 MB/s | 6107.2 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 216.2 MB/s | 1297.8 MB/s | **6.0x** | 3091.0 MB/s | 6620.8 MB/s | **2.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.7 MB/s | 5064.1 MB/s | **35.0x** | 1664.8 MB/s | 6212.5 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.7 MB/s | 1344.6 MB/s | **9.6x** | 1380.9 MB/s | 7344.8 MB/s | **5.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.4 MB/s | 184.4 MB/s | **2.2x** | 3291.6 MB/s | 9708.0 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.1 MB/s | 167.8 MB/s | **2.4x** | 1397.1 MB/s | 2190.9 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.9 MB/s | 140.0 MB/s | **1.9x** | 3441.9 MB/s | 9860.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.2 MB/s | 139.0 MB/s | **2.0x** | 1746.2 MB/s | 2279.1 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4729.7 MB/s | 5151.0 MB/s | **1.1x** | 5660.1 MB/s | 4227.1 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5564.6 MB/s | 4791.4 MB/s | **0.9x** | 6655.1 MB/s | 4197.8 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 755.5 MB/s | 1548.9 MB/s | **2.1x** | 1289.5 MB/s | 4706.9 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 765.7 MB/s | 1557.4 MB/s | **2.0x** | 1386.6 MB/s | 4536.9 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5236.0 MB/s | 20371.3 MB/s | **3.9x** | 5295.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5214.5 MB/s | 20584.7 MB/s | **3.9x** | 4696.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 667.3 MB/s | 19771.1 MB/s | **29.6x** | 3537.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 636.8 MB/s | 19771.9 MB/s | **31.0x** | 3533.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1013.5 MB/s | 1842.9 MB/s | **1.8x** | 1696.9 MB/s | 6846.9 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1009.2 MB/s | 1836.1 MB/s | **1.8x** | 2060.4 MB/s | 10473.7 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.3 MB/s | 1247.9 MB/s | **13.2x** | 1714.6 MB/s | 12167.4 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 1246.2 MB/s | **13.3x** | 1994.4 MB/s | 11747.5 MB/s | **5.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14660.1 MB/s | 19671.9 MB/s | **1.3x** | 5145.6 MB/s | 4949.1 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10874.2 MB/s | 18538.1 MB/s | **1.7x** | 5773.0 MB/s | 4483.8 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2010.3 MB/s | 8886.4 MB/s | **4.4x** | 1808.0 MB/s | 2962.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2082.2 MB/s | 10542.7 MB/s | **5.1x** | 1982.4 MB/s | 3124.8 MB/s | **1.6x** | - |
