# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 17:49:18 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 803.3 MB/s | 874.4 MB/s | **1.1x** | 717.2 MB/s | 1196.7 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 836.8 MB/s | 809.2 MB/s | **1.0x** | 539.0 MB/s | 811.4 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 290.1 MB/s | 409.1 MB/s | **1.4x** | 639.2 MB/s | 1184.3 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 291.1 MB/s | 419.5 MB/s | **1.4x** | 480.5 MB/s | 722.8 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 453.8 MB/s | 1148.6 MB/s | **2.5x** | 600.0 MB/s | 1818.2 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 410.0 MB/s | 870.2 MB/s | **2.1x** | 297.9 MB/s | 1699.3 MB/s | **5.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 248.5 MB/s | 1176.4 MB/s | **4.7x** | 511.0 MB/s | 1822.9 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 312.3 MB/s | 723.8 MB/s | **2.3x** | 247.8 MB/s | 1574.2 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 248.5 MB/s | 977.2 MB/s | **3.9x** | 276.4 MB/s | 846.5 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 246.6 MB/s | 1046.5 MB/s | **4.2x** | 280.9 MB/s | 1066.6 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 997.2 MB/s | 2399.3 MB/s | **2.4x** | 1391.8 MB/s | 5127.2 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 905.4 MB/s | 1571.8 MB/s | **1.7x** | 774.8 MB/s | 1332.6 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 300.5 MB/s | 557.7 MB/s | **1.9x** | 945.5 MB/s | 3528.5 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.7 MB/s | 546.8 MB/s | **1.8x** | 652.2 MB/s | 1234.3 MB/s | **1.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 645.0 MB/s | 1716.7 MB/s | **2.7x** | 950.4 MB/s | 5612.4 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 625.6 MB/s | 1495.3 MB/s | **2.4x** | 999.6 MB/s | 4259.8 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.9 MB/s | 1210.2 MB/s | **15.9x** | 935.7 MB/s | 5917.3 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.2 MB/s | 1093.6 MB/s | **14.4x** | 984.8 MB/s | 5052.0 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1584.6 MB/s | 6000.3 MB/s | **3.8x** | 1616.1 MB/s | 5620.6 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1257.5 MB/s | 3835.2 MB/s | **3.0x** | 1574.4 MB/s | 5806.3 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 734.8 MB/s | 4466.5 MB/s | **6.1x** | 949.3 MB/s | 5303.9 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 766.3 MB/s | 4963.0 MB/s | **6.5x** | 946.0 MB/s | 5646.5 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 200.5 MB/s | 4347.5 MB/s | **21.7x** | 4334.7 MB/s | 5825.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 207.6 MB/s | 1186.9 MB/s | **5.7x** | 3256.1 MB/s | 4237.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.3 MB/s | 4902.4 MB/s | **35.7x** | 1692.9 MB/s | 6722.9 MB/s | **4.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.7 MB/s | 1266.1 MB/s | **8.9x** | 1542.5 MB/s | 5422.3 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.8 MB/s | 179.6 MB/s | **2.1x** | 3934.9 MB/s | 10688.1 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.1 MB/s | 171.5 MB/s | **2.1x** | 1837.3 MB/s | 2275.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.1 MB/s | 146.1 MB/s | **1.9x** | 4121.1 MB/s | 11330.4 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.1 MB/s | 138.2 MB/s | **2.0x** | 1874.2 MB/s | 2231.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5988.8 MB/s | 4172.4 MB/s | **0.7x** | 7073.3 MB/s | 7250.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 12.64 MB (12.6%) | 6213.7 MB/s | 12651.3 MB/s | **2.0x** | 7416.8 MB/s | 8488.3 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1007.2 MB/s | 1793.5 MB/s | **1.8x** | 1682.1 MB/s | 5900.8 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 987.4 MB/s | 1816.1 MB/s | **1.8x** | 1689.0 MB/s | 5587.6 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5554.6 MB/s | 20676.8 MB/s | **3.7x** | 5899.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5481.9 MB/s | 21343.7 MB/s | **3.9x** | 5490.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 681.7 MB/s | 19761.6 MB/s | **29.0x** | 3668.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 681.6 MB/s | 20020.0 MB/s | **29.4x** | 3600.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1034.6 MB/s | 1857.6 MB/s | **1.8x** | 1777.6 MB/s | 5949.6 MB/s | **3.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1033.7 MB/s | 1845.8 MB/s | **1.8x** | 2110.3 MB/s | 7248.7 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.0 MB/s | 1258.9 MB/s | **13.1x** | 1788.1 MB/s | 11536.9 MB/s | **6.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.5 MB/s | 1258.9 MB/s | **13.2x** | 2136.5 MB/s | 11987.9 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 16101.2 MB/s | 20953.7 MB/s | **1.3x** | 5993.4 MB/s | 8284.0 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11374.8 MB/s | 17251.6 MB/s | **1.5x** | 6368.7 MB/s | 8738.1 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2023.3 MB/s | 10664.1 MB/s | **5.3x** | 1952.6 MB/s | 3257.1 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1994.5 MB/s | 10835.4 MB/s | **5.4x** | 1987.7 MB/s | 3179.1 MB/s | **1.6x** | - |
