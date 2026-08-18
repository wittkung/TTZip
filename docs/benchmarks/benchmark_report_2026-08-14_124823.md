# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:48:23 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 908.9 MB/s | 1156.9 MB/s | **1.3x** | 724.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 887.7 MB/s | 573.0 MB/s | **0.6x** | 535.8 MB/s | 528.2 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.6 MB/s | 415.9 MB/s | **1.4x** | 582.0 MB/s | 789.5 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.6 MB/s | 245.3 MB/s | **0.9x** | 466.0 MB/s | 483.2 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 508.2 MB/s | 1298.0 MB/s | **2.6x** | 599.0 MB/s | 2222.4 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 487.1 MB/s | 920.9 MB/s | **1.9x** | 308.8 MB/s | 1891.9 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 408.2 MB/s | 1274.2 MB/s | **3.1x** | 594.9 MB/s | 2156.0 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 385.4 MB/s | 919.1 MB/s | **2.4x** | 307.5 MB/s | 1913.0 MB/s | **6.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 273.0 MB/s | 1080.3 MB/s | **4.0x** | 273.8 MB/s | 933.2 MB/s | **3.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 288.4 MB/s | 1107.5 MB/s | **3.8x** | 285.1 MB/s | 892.2 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.03 MB (0.2%) | 1162.3 MB/s | 7430.4 MB/s | **6.4x** | 1497.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 986.1 MB/s | 947.3 MB/s | **1.0x** | 861.6 MB/s | 844.1 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.9 MB/s | 506.5 MB/s | **1.7x** | 1020.2 MB/s | 1829.4 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 299.5 MB/s | 292.9 MB/s | **1.0x** | 701.7 MB/s | 686.7 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 681.6 MB/s | 1825.2 MB/s | **2.7x** | 1040.5 MB/s | 6294.0 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 661.8 MB/s | 1642.0 MB/s | **2.5x** | 1089.3 MB/s | 4979.8 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.3 MB/s | 1270.0 MB/s | **16.4x** | 991.3 MB/s | 7379.0 MB/s | **7.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.0 MB/s | 1070.3 MB/s | **13.4x** | 1063.8 MB/s | 5490.1 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1725.9 MB/s | 4985.5 MB/s | **2.9x** | 1761.0 MB/s | 4996.9 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1334.9 MB/s | 5015.2 MB/s | **3.8x** | 1659.3 MB/s | 5251.6 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 778.7 MB/s | 4492.2 MB/s | **5.8x** | 939.4 MB/s | 6233.9 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 773.1 MB/s | 587.8 MB/s | **0.8x** | 940.5 MB/s | 4849.7 MB/s | **5.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 239.0 MB/s | 4729.5 MB/s | **19.8x** | 4389.6 MB/s | 7599.4 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (94.2%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 198.9 MB/s | 223.8 MB/s | **1.1x** | 3370.7 MB/s | 3290.3 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 146.0 MB/s | 4614.5 MB/s | **31.6x** | 1687.1 MB/s | 6857.1 MB/s | **4.1x** | 2_SolidBuf_IO_and_CRC32 (92.7%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 147.1 MB/s | 147.9 MB/s | **1.0x** | 1575.1 MB/s | 1548.5 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.6 MB/s | 183.1 MB/s | **2.0x** | 4053.1 MB/s | 11214.7 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.8 MB/s | 174.8 MB/s | **2.1x** | 1939.8 MB/s | 2259.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.5 MB/s | 150.0 MB/s | **2.0x** | 4100.6 MB/s | 11166.1 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.9 MB/s | 144.3 MB/s | **2.0x** | 1911.8 MB/s | 2444.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 6372.0 MB/s | 6593.6 MB/s | **1.0x** | 7077.0 MB/s | 6821.4 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 6302.5 MB/s | 6660.9 MB/s | **1.1x** | 6268.5 MB/s | 6452.4 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1032.8 MB/s | 1787.1 MB/s | **1.7x** | 1709.7 MB/s | 5996.3 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1013.8 MB/s | 1837.7 MB/s | **1.8x** | 1677.7 MB/s | 5975.5 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 5565.0 MB/s | 4979.6 MB/s | **0.9x** | 5920.6 MB/s | 7568.3 MB/s | **1.3x** | 2_SolidBuf_IO_and_CRC32 (93.1%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5529.0 MB/s | 5507.4 MB/s | **1.0x** | 5630.0 MB/s | 5595.6 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 690.0 MB/s | 4787.0 MB/s | **6.9x** | 3833.7 MB/s | 2121.5 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 681.8 MB/s | 682.9 MB/s | **1.0x** | 3679.1 MB/s | 3582.4 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1018.2 MB/s | 1881.2 MB/s | **1.8x** | 1742.4 MB/s | 7266.5 MB/s | **4.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1049.4 MB/s | 1868.4 MB/s | **1.8x** | 2143.8 MB/s | 7302.1 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.6 MB/s | 1264.2 MB/s | **13.1x** | 1810.5 MB/s | 12422.5 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.6 MB/s | 1265.6 MB/s | **13.0x** | 2164.1 MB/s | 12343.9 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 16020.7 MB/s | 4638.3 MB/s | **0.3x** | 6117.9 MB/s | 6983.1 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11478.0 MB/s | 4622.5 MB/s | **0.4x** | 6574.5 MB/s | 6806.9 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2173.2 MB/s | 9580.5 MB/s | **4.4x** | 1938.4 MB/s | 3297.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2013.5 MB/s | 9704.4 MB/s | **4.8x** | 2015.5 MB/s | 3339.7 MB/s | **1.7x** | - |
