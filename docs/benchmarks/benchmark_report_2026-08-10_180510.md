# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 10:05:10 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 809.1 MB/s | 266.1 MB/s | **0.3x** | 655.8 MB/s | 540.1 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 794.5 MB/s | 267.5 MB/s | **0.3x** | 488.5 MB/s | 407.8 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 274.0 MB/s | 260.6 MB/s | **1.0x** | 558.3 MB/s | 533.9 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 236.4 MB/s | 257.8 MB/s | **1.1x** | 375.7 MB/s | 381.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 290.5 MB/s | 2951.4 MB/s | **10.2x** | 434.3 MB/s | 2078.0 MB/s | **4.8x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 336.3 MB/s | 822.8 MB/s | **2.4x** | 248.5 MB/s | 852.0 MB/s | **3.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 286.4 MB/s | 4865.1 MB/s | **17.0x** | 471.0 MB/s | 1753.7 MB/s | **3.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 270.8 MB/s | 1620.8 MB/s | **6.0x** | 264.1 MB/s | 1652.5 MB/s | **6.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 249.9 MB/s | 173.7 MB/s | **0.7x** | 221.4 MB/s | 289.3 MB/s | **1.3x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 246.4 MB/s | 192.8 MB/s | **0.8x** | 218.0 MB/s | 278.9 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 893.8 MB/s | 259.3 MB/s | **0.3x** | 1081.6 MB/s | 766.8 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 715.3 MB/s | 245.4 MB/s | **0.3x** | 646.7 MB/s | 502.0 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 272.3 MB/s | 269.8 MB/s | **1.0x** | 814.4 MB/s | 786.8 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 271.5 MB/s | 272.5 MB/s | **1.0x** | 555.8 MB/s | 561.9 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 592.2 MB/s | 1578.1 MB/s | **2.7x** | 843.2 MB/s | 4864.8 MB/s | **5.8x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 586.2 MB/s | 1397.3 MB/s | **2.4x** | 885.0 MB/s | 4387.4 MB/s | **5.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.2 MB/s | 1103.3 MB/s | **13.8x** | 860.5 MB/s | 6232.4 MB/s | **7.2x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 80.2 MB/s | 1037.6 MB/s | **12.9x** | 855.7 MB/s | 4101.3 MB/s | **4.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1380.7 MB/s | 896.0 MB/s | **0.6x** | 1228.3 MB/s | 1208.1 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 950.6 MB/s | 763.9 MB/s | **0.8x** | 1203.4 MB/s | 1060.3 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 633.5 MB/s | 434.2 MB/s | **0.7x** | 758.6 MB/s | 1997.1 MB/s | **2.6x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 645.6 MB/s | 455.0 MB/s | **0.7x** | 752.4 MB/s | 1936.4 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 174.2 MB/s | 171.6 MB/s | **1.0x** | 3705.6 MB/s | 1514.2 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 140.5 MB/s | 113.6 MB/s | **0.8x** | 2452.8 MB/s | 1202.3 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 128.4 MB/s | 151.2 MB/s | **1.2x** | 1542.8 MB/s | 1260.3 MB/s | **0.8x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 128.0 MB/s | 168.4 MB/s | **1.3x** | 1405.2 MB/s | 1417.3 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.4 MB/s | 172.6 MB/s | **2.0x** | 3374.7 MB/s | 7486.4 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.2 MB/s | 182.7 MB/s | **2.2x** | 1673.0 MB/s | 2143.4 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.5 MB/s | 150.0 MB/s | **2.0x** | 3376.5 MB/s | 8103.3 MB/s | **2.4x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 67.7 MB/s | 144.7 MB/s | **2.1x** | 1671.7 MB/s | 2009.7 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4812.3 MB/s | 948.2 MB/s | **0.2x** | 5324.4 MB/s | 1421.4 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5113.0 MB/s | 1290.2 MB/s | **0.3x** | 6452.8 MB/s | 3666.3 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 727.5 MB/s | 71.4 MB/s | **0.1x** | 1292.5 MB/s | 3421.6 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 845.0 MB/s | 75.1 MB/s | **0.1x** | 1444.9 MB/s | 3628.4 MB/s | **2.5x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4826.3 MB/s | 620.3 MB/s | **0.1x** | 4696.0 MB/s | 2802.6 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5000.1 MB/s | 607.0 MB/s | **0.1x** | 4685.8 MB/s | 2923.6 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 631.7 MB/s | 616.0 MB/s | **1.0x** | 3534.5 MB/s | 3190.6 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 611.7 MB/s | 522.0 MB/s | **0.9x** | 3082.2 MB/s | 3140.3 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1019.1 MB/s | 1607.2 MB/s | **1.6x** | 1676.4 MB/s | 5373.5 MB/s | **3.2x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1001.4 MB/s | 1605.9 MB/s | **1.6x** | 1998.9 MB/s | 7229.0 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.3 MB/s | 1072.5 MB/s | **11.5x** | 1623.2 MB/s | 8700.7 MB/s | **5.4x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.9 MB/s | 1133.7 MB/s | **12.3x** | 1910.4 MB/s | 6309.0 MB/s | **3.3x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14024.2 MB/s | 1570.2 MB/s | **0.1x** | 5169.3 MB/s | 3606.2 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9099.2 MB/s | 1188.3 MB/s | **0.1x** | 5038.4 MB/s | 5006.5 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1736.7 MB/s | 586.7 MB/s | **0.3x** | 1415.5 MB/s | 3112.7 MB/s | **2.2x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1874.4 MB/s | 579.4 MB/s | **0.3x** | 1401.7 MB/s | 2744.7 MB/s | **2.0x** |
