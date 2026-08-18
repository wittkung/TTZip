# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 10:29:54 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 969.4 MB/s | 285.2 MB/s | **0.3x** | 771.0 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 944.9 MB/s | 288.0 MB/s | **0.3x** | 585.2 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.0 MB/s | 295.9 MB/s | **1.0x** | 638.5 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.2 MB/s | 292.2 MB/s | **1.0x** | 509.1 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 429.9 MB/s | 5246.4 MB/s | **12.2x** | 626.2 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 394.4 MB/s | 2192.8 MB/s | **5.6x** | 315.4 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 368.8 MB/s | 4771.4 MB/s | **12.9x** | 628.6 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 343.2 MB/s | 2171.1 MB/s | **6.3x** | 315.2 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 306.3 MB/s | 232.2 MB/s | **0.8x** | 194.5 MB/s | 0.0 MB/s | **0.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 300.5 MB/s | 233.2 MB/s | **0.8x** | 276.5 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1038.7 MB/s | 283.7 MB/s | **0.3x** | 1296.4 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 846.1 MB/s | 279.6 MB/s | **0.3x** | 756.6 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.3 MB/s | 283.3 MB/s | **1.0x** | 936.0 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 287.6 MB/s | 272.7 MB/s | **0.9x** | 619.0 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 688.7 MB/s | 1695.6 MB/s | **2.5x** | 992.7 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 627.2 MB/s | 1537.9 MB/s | **2.5x** | 994.5 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 86.1 MB/s | 1195.3 MB/s | **13.9x** | 916.8 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 84.3 MB/s | 1093.3 MB/s | **13.0x** | 954.2 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1131.4 MB/s | 667.7 MB/s | **0.6x** | 1403.4 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 982.9 MB/s | 899.5 MB/s | **0.9x** | 1284.6 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 694.1 MB/s | 478.7 MB/s | **0.7x** | 802.3 MB/s | 0.0 MB/s | **0.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 665.6 MB/s | 483.1 MB/s | **0.7x** | 832.3 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 235.4 MB/s | 185.4 MB/s | **0.8x** | 4047.0 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 227.3 MB/s | 185.6 MB/s | **0.8x** | 3213.1 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 149.0 MB/s | 135.0 MB/s | **0.9x** | 1658.1 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 149.0 MB/s | 186.4 MB/s | **1.3x** | 1530.5 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 90.3 MB/s | 198.5 MB/s | **2.2x** | 3663.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.1 MB/s | 188.9 MB/s | **2.2x** | 1795.9 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.9 MB/s | 159.1 MB/s | **2.1x** | 3657.4 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.7 MB/s | 149.4 MB/s | **2.1x** | 1812.8 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5476.2 MB/s | 1405.0 MB/s | **0.3x** | 6805.5 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5706.1 MB/s | 1371.0 MB/s | **0.2x** | 7114.7 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 1023.5 MB/s | 79.7 MB/s | **0.1x** | 1613.7 MB/s | 0.0 MB/s | **0.0x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 988.9 MB/s | 78.9 MB/s | **0.1x** | 1588.9 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5374.0 MB/s | 660.1 MB/s | **0.1x** | 5573.9 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5319.4 MB/s | 631.2 MB/s | **0.1x** | 5150.3 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 682.7 MB/s | 670.0 MB/s | **1.0x** | 3797.0 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 685.0 MB/s | 675.7 MB/s | **1.0x** | 3555.9 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1031.7 MB/s | 1655.7 MB/s | **1.6x** | 1735.9 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1018.5 MB/s | 1646.8 MB/s | **1.6x** | 2055.1 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.0 MB/s | 1140.3 MB/s | **11.8x** | 1775.3 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.1 MB/s | 1167.2 MB/s | **12.0x** | 2106.7 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15564.7 MB/s | 1798.0 MB/s | **0.1x** | 6129.0 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10848.3 MB/s | 1326.1 MB/s | **0.1x** | 7040.8 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 2092.3 MB/s | 608.6 MB/s | **0.3x** | 1946.2 MB/s | 0.0 MB/s | **0.0x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 2038.6 MB/s | 611.2 MB/s | **0.3x** | 1962.3 MB/s | 0.0 MB/s | **0.0x** |
