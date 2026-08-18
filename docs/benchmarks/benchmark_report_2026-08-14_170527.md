# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 09:05:27 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 768.6 MB/s | 1012.9 MB/s | **1.3x** | 575.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 718.7 MB/s | 468.8 MB/s | **0.7x** | 452.8 MB/s | 423.0 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 268.5 MB/s | 351.7 MB/s | **1.3x** | 543.6 MB/s | 576.4 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 265.3 MB/s | 221.4 MB/s | **0.8x** | 421.6 MB/s | 429.5 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 364.1 MB/s | 1098.6 MB/s | **3.0x** | 515.7 MB/s | 1834.1 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 363.4 MB/s | 791.2 MB/s | **2.2x** | 267.7 MB/s | 1672.9 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 297.4 MB/s | 1085.0 MB/s | **3.6x** | 510.5 MB/s | 1901.7 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 281.2 MB/s | 790.3 MB/s | **2.8x** | 273.3 MB/s | 1596.4 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 216.9 MB/s | 961.5 MB/s | **4.4x** | 251.5 MB/s | 805.7 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 215.5 MB/s | 897.3 MB/s | **4.2x** | 238.4 MB/s | 726.8 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.03 MB (0.2%) | 966.1 MB/s | 5012.0 MB/s | **5.2x** | 1174.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 806.7 MB/s | 814.7 MB/s | **1.0x** | 723.0 MB/s | 717.0 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 261.7 MB/s | 409.3 MB/s | **1.6x** | 845.5 MB/s | 890.7 MB/s | **1.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 268.4 MB/s | 238.9 MB/s | **0.9x** | 589.2 MB/s | 487.1 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 578.8 MB/s | 1353.0 MB/s | **2.3x** | 808.1 MB/s | 3423.1 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 528.2 MB/s | 1381.1 MB/s | **2.6x** | 804.9 MB/s | 2977.4 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.3 MB/s | 1077.5 MB/s | **14.7x** | 798.9 MB/s | 5287.2 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.7 MB/s | 1076.0 MB/s | **14.4x** | 857.4 MB/s | 4349.2 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1411.6 MB/s | 3926.3 MB/s | **2.8x** | 1302.7 MB/s | 3389.9 MB/s | **2.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1078.3 MB/s | 3467.4 MB/s | **3.2x** | 1210.6 MB/s | 3393.3 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 654.7 MB/s | 3454.7 MB/s | **5.3x** | 747.6 MB/s | 3617.2 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 613.5 MB/s | 4040.0 MB/s | **6.6x** | 660.5 MB/s | 4792.3 MB/s | **7.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 125.5 MB/s | 3340.5 MB/s | **26.6x** | 3592.9 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (89.1%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 154.8 MB/s | 160.6 MB/s | **1.0x** | 3073.1 MB/s | 2853.0 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 114.9 MB/s | 3469.5 MB/s | **30.2x** | 1525.6 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (91.3%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 127.7 MB/s | 127.7 MB/s | **1.0x** | 1392.6 MB/s | 1367.7 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.5 MB/s | 176.2 MB/s | **2.1x** | 3303.4 MB/s | 10163.8 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.3 MB/s | 163.5 MB/s | **2.2x** | 1249.0 MB/s | 2095.8 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.0 MB/s | 143.6 MB/s | **2.0x** | 2739.7 MB/s | 9363.2 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.7 MB/s | 135.1 MB/s | **1.9x** | 1734.4 MB/s | 2116.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5357.4 MB/s | 6895.0 MB/s | **1.3x** | 6675.5 MB/s | 5828.9 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5859.5 MB/s | 7508.1 MB/s | **1.3x** | 5294.3 MB/s | 6476.8 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 871.8 MB/s | 1542.9 MB/s | **1.8x** | 1355.1 MB/s | 4657.8 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 842.4 MB/s | 1524.0 MB/s | **1.8x** | 1380.8 MB/s | 4275.3 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 4620.6 MB/s | 3611.4 MB/s | **0.8x** | 4812.9 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (93.7%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 4853.3 MB/s | 4623.3 MB/s | **1.0x** | 4758.1 MB/s | 4819.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 606.3 MB/s | 4105.3 MB/s | **6.8x** | 3290.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 594.5 MB/s | 597.3 MB/s | **1.0x** | 3115.3 MB/s | 3247.1 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1015.0 MB/s | 1752.7 MB/s | **1.7x** | 1707.5 MB/s | 4274.3 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1011.8 MB/s | 1817.1 MB/s | **1.8x** | 1869.1 MB/s | 8463.6 MB/s | **4.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.8 MB/s | 1217.5 MB/s | **13.0x** | 1605.6 MB/s | 9004.2 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.4 MB/s | 1154.4 MB/s | **12.5x** | 1965.3 MB/s | 5850.7 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15219.6 MB/s | 10813.6 MB/s | **0.7x** | 5948.5 MB/s | 6057.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10074.0 MB/s | 10957.7 MB/s | **1.1x** | 6255.8 MB/s | 5829.7 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2082.8 MB/s | 7547.4 MB/s | **3.6x** | 1521.2 MB/s | 2909.2 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1777.4 MB/s | 8479.9 MB/s | **4.8x** | 1879.9 MB/s | 2816.2 MB/s | **1.5x** | - |
