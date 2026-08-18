# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 11:56:07 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 884.0 MB/s | 288.4 MB/s | **0.3x** | 744.9 MB/s | 604.5 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 820.1 MB/s | 285.5 MB/s | **0.3x** | 535.8 MB/s | 409.7 MB/s | **0.8x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.9 MB/s | 289.1 MB/s | **1.0x** | 621.5 MB/s | 628.8 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.5 MB/s | 286.5 MB/s | **1.0x** | 457.5 MB/s | 395.7 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 391.8 MB/s | 5930.9 MB/s | **15.1x** | 509.1 MB/s | 2048.7 MB/s | **4.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 379.4 MB/s | 2116.3 MB/s | **5.6x** | 281.2 MB/s | 1814.4 MB/s | **6.5x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 351.0 MB/s | 6870.7 MB/s | **19.6x** | 532.4 MB/s | 1520.2 MB/s | **2.9x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 330.3 MB/s | 2073.5 MB/s | **6.3x** | 295.4 MB/s | 1760.8 MB/s | **6.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 286.7 MB/s | 231.9 MB/s | **0.8x** | 274.7 MB/s | 270.6 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 298.1 MB/s | 229.7 MB/s | **0.8x** | 276.3 MB/s | 327.1 MB/s | **1.2x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1045.1 MB/s | 285.6 MB/s | **0.3x** | 1302.5 MB/s | 877.4 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 858.3 MB/s | 285.7 MB/s | **0.3x** | 752.8 MB/s | 599.9 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.4 MB/s | 291.8 MB/s | **1.0x** | 937.7 MB/s | 920.8 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 280.6 MB/s | 262.1 MB/s | **0.9x** | 596.9 MB/s | 572.3 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 640.4 MB/s | 1632.8 MB/s | **2.5x** | 905.7 MB/s | 5595.9 MB/s | **6.2x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 644.0 MB/s | 1533.6 MB/s | **2.4x** | 1005.2 MB/s | 4296.7 MB/s | **4.3x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 83.8 MB/s | 1214.5 MB/s | **14.5x** | 883.0 MB/s | 7042.7 MB/s | **8.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 83.7 MB/s | 1085.9 MB/s | **13.0x** | 929.8 MB/s | 4463.0 MB/s | **4.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1461.2 MB/s | 989.7 MB/s | **0.7x** | 1466.8 MB/s | 1208.8 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1070.5 MB/s | 883.6 MB/s | **0.8x** | 1371.6 MB/s | 1284.6 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 691.6 MB/s | 472.2 MB/s | **0.7x** | 826.5 MB/s | 2246.1 MB/s | **2.7x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 696.6 MB/s | 482.1 MB/s | **0.7x** | 831.5 MB/s | 2214.8 MB/s | **2.7x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 232.1 MB/s | 184.4 MB/s | **0.8x** | 4045.5 MB/s | 1664.6 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 227.7 MB/s | 186.2 MB/s | **0.8x** | 3224.0 MB/s | 1508.2 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 144.6 MB/s | 177.2 MB/s | **1.2x** | 1629.1 MB/s | 1450.9 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 142.5 MB/s | 133.1 MB/s | **0.9x** | 1502.3 MB/s | 1389.1 MB/s | **0.9x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.3 MB/s | 193.5 MB/s | **2.2x** | 3550.6 MB/s | 9382.0 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.2 MB/s | 179.6 MB/s | **2.2x** | 1781.9 MB/s | 2091.7 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.2 MB/s | 158.3 MB/s | **2.1x** | 3568.5 MB/s | 9286.6 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.3 MB/s | 149.2 MB/s | **2.1x** | 1778.6 MB/s | 2250.8 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5063.2 MB/s | 1311.9 MB/s | **0.3x** | 6009.5 MB/s | 1573.3 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 4593.5 MB/s | 1407.0 MB/s | **0.3x** | 4941.3 MB/s | 2297.8 MB/s | **0.5x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 900.2 MB/s | 75.5 MB/s | **0.1x** | 1527.7 MB/s | 2937.2 MB/s | **1.9x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 956.9 MB/s | 74.1 MB/s | **0.1x** | 1654.7 MB/s | 3398.6 MB/s | **2.1x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5095.4 MB/s | 631.2 MB/s | **0.1x** | 5298.5 MB/s | 3626.5 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4608.8 MB/s | 627.8 MB/s | **0.1x** | 3985.3 MB/s | 2897.4 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 652.9 MB/s | 628.6 MB/s | **1.0x** | 3488.4 MB/s | 3439.9 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 647.8 MB/s | 635.3 MB/s | **1.0x** | 3426.2 MB/s | 3356.8 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 952.5 MB/s | 1512.3 MB/s | **1.6x** | 1513.4 MB/s | 6475.4 MB/s | **4.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 939.3 MB/s | 1369.5 MB/s | **1.5x** | 1675.0 MB/s | 8859.9 MB/s | **5.3x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.1 MB/s | 1022.4 MB/s | **11.0x** | 1625.7 MB/s | 9673.4 MB/s | **6.0x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.5 MB/s | 1109.3 MB/s | **12.1x** | 1974.5 MB/s | 10427.5 MB/s | **5.3x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11500.2 MB/s | 1581.7 MB/s | **0.1x** | 5500.5 MB/s | 3935.6 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9079.9 MB/s | 1143.4 MB/s | **0.1x** | 5494.1 MB/s | 3798.7 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1411.2 MB/s | 508.2 MB/s | **0.4x** | 1394.6 MB/s | 2590.7 MB/s | **1.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1893.5 MB/s | 540.6 MB/s | **0.3x** | 1361.8 MB/s | 3160.8 MB/s | **2.3x** |
