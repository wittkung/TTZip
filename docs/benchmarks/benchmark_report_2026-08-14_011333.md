# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 17:13:33 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 944.4 MB/s | 431.3 MB/s | **0.5x** | 675.2 MB/s | 594.4 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 904.4 MB/s | 247.4 MB/s | **0.3x** | 550.0 MB/s | 430.3 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.9 MB/s | 306.8 MB/s | **1.1x** | 545.1 MB/s | 359.7 MB/s | **0.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.2 MB/s | 244.4 MB/s | **0.8x** | 185.6 MB/s | 449.3 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 462.6 MB/s | 636.4 MB/s | **1.4x** | 585.8 MB/s | 1860.8 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 430.1 MB/s | 529.2 MB/s | **1.2x** | 290.5 MB/s | 244.8 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 375.9 MB/s | 646.3 MB/s | **1.7x** | 343.9 MB/s | 1994.0 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 350.4 MB/s | 555.6 MB/s | **1.6x** | 297.8 MB/s | 249.3 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 238.6 MB/s | 384.0 MB/s | **1.6x** | 272.9 MB/s | 854.9 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 240.5 MB/s | 399.8 MB/s | **1.7x** | 210.9 MB/s | 787.4 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1040.3 MB/s | 470.4 MB/s | **0.5x** | 1324.7 MB/s | 1740.6 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 917.7 MB/s | 283.8 MB/s | **0.3x** | 813.0 MB/s | 629.3 MB/s | **0.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.7 MB/s | 538.7 MB/s | **1.9x** | 973.2 MB/s | 1811.3 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.1 MB/s | 288.9 MB/s | **1.0x** | 653.5 MB/s | 633.5 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 660.5 MB/s | 1014.5 MB/s | **1.5x** | 956.4 MB/s | 5497.8 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 638.1 MB/s | 1025.7 MB/s | **1.6x** | 1021.2 MB/s | 740.8 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.2 MB/s | 845.4 MB/s | **11.0x** | 937.8 MB/s | 5710.5 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.7 MB/s | 819.4 MB/s | **11.0x** | 1011.3 MB/s | 734.1 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 877.8 MB/s | 1760.7 MB/s | **2.0x** | 1581.3 MB/s | 5431.0 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1273.2 MB/s | 1452.0 MB/s | **1.1x** | 1557.9 MB/s | 5165.4 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 745.0 MB/s | 583.4 MB/s | **0.8x** | 893.2 MB/s | 5307.9 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 742.0 MB/s | 593.2 MB/s | **0.8x** | 939.9 MB/s | 5410.5 MB/s | **5.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 228.2 MB/s | 2067.6 MB/s | **9.1x** | 3975.0 MB/s | 7002.8 MB/s | **1.8x** | 2_SolidBuf_IO_and_CRC32 (98.7%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 217.4 MB/s | 194.8 MB/s | **0.9x** | 3242.3 MB/s | 1462.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 145.6 MB/s | 2669.4 MB/s | **18.3x** | 1222.8 MB/s | 6639.2 MB/s | **5.4x** | 2_SolidBuf_IO_and_CRC32 (97.7%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 144.6 MB/s | 191.8 MB/s | **1.3x** | 1480.4 MB/s | 1487.5 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.6 MB/s | 1887.5 MB/s | **21.3x** | 3831.5 MB/s | 9484.4 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.9 MB/s | 875.8 MB/s | **10.8x** | 1779.4 MB/s | 926.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.8 MB/s | 1904.1 MB/s | **25.8x** | 3706.8 MB/s | 9679.6 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.0 MB/s | 1058.9 MB/s | **14.9x** | 1800.7 MB/s | 912.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5339.6 MB/s | 1380.1 MB/s | **0.3x** | 5868.0 MB/s | 6043.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 6245.3 MB/s | 1524.0 MB/s | **0.2x** | 7202.3 MB/s | 8964.8 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 913.5 MB/s | 76.9 MB/s | **0.1x** | 1457.1 MB/s | 5485.2 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 929.9 MB/s | 77.6 MB/s | **0.1x** | 1602.9 MB/s | 5259.5 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5286.5 MB/s | 2191.1 MB/s | **0.4x** | 5282.2 MB/s | 1987.8 MB/s | **0.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5343.9 MB/s | 676.3 MB/s | **0.1x** | 5075.1 MB/s | 3617.3 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 683.9 MB/s | 3429.2 MB/s | **5.0x** | 3770.7 MB/s | 1986.4 MB/s | **0.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 678.7 MB/s | 673.5 MB/s | **1.0x** | 3542.2 MB/s | 3644.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1010.2 MB/s | 564.0 MB/s | **0.6x** | 1631.1 MB/s | 7328.7 MB/s | **4.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1010.5 MB/s | 561.6 MB/s | **0.6x** | 2031.8 MB/s | 1441.9 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.0 MB/s | 485.0 MB/s | **5.2x** | 1683.6 MB/s | 12000.5 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.9 MB/s | 493.2 MB/s | **5.3x** | 1967.6 MB/s | 1399.1 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12454.3 MB/s | 1572.9 MB/s | **0.1x** | 5302.4 MB/s | 6939.5 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10624.0 MB/s | 1191.2 MB/s | **0.1x** | 4962.1 MB/s | 8749.3 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2023.4 MB/s | 608.2 MB/s | **0.3x** | 1804.3 MB/s | 2952.9 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1840.6 MB/s | 608.3 MB/s | **0.3x** | 1610.0 MB/s | 3021.6 MB/s | **1.9x** | - |
