# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:22:19 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 840.7 MB/s | 884.2 MB/s | **1.1x** | 738.8 MB/s | 1145.3 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 814.9 MB/s | 726.4 MB/s | **0.9x** | 540.3 MB/s | 1444.7 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.7 MB/s | 400.3 MB/s | **1.4x** | 590.3 MB/s | 1260.6 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.0 MB/s | 392.1 MB/s | **1.4x** | 470.6 MB/s | 1115.5 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 472.8 MB/s | 1230.1 MB/s | **2.6x** | 256.6 MB/s | 1751.9 MB/s | **6.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 449.9 MB/s | 778.8 MB/s | **1.7x** | 300.7 MB/s | 1756.0 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 405.6 MB/s | 1273.8 MB/s | **3.1x** | 595.8 MB/s | 1985.1 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 294.7 MB/s | 933.3 MB/s | **3.2x** | 292.4 MB/s | 1876.2 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 275.3 MB/s | 1007.6 MB/s | **3.7x** | 278.4 MB/s | 351.6 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 278.9 MB/s | 975.8 MB/s | **3.5x** | 283.4 MB/s | 879.9 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1041.5 MB/s | 2143.9 MB/s | **2.1x** | 1345.2 MB/s | 4455.0 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 961.3 MB/s | 2689.5 MB/s | **2.8x** | 844.4 MB/s | 4457.3 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.5 MB/s | 527.8 MB/s | **1.8x** | 941.5 MB/s | 3504.3 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.3 MB/s | 548.1 MB/s | **1.9x** | 673.5 MB/s | 3280.7 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 667.7 MB/s | 1702.0 MB/s | **2.5x** | 976.6 MB/s | 5787.2 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 659.0 MB/s | 1649.0 MB/s | **2.5x** | 1073.3 MB/s | 4968.1 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.7 MB/s | 1268.1 MB/s | **15.9x** | 955.8 MB/s | 7177.9 MB/s | **7.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 79.1 MB/s | 1176.1 MB/s | **14.9x** | 1057.7 MB/s | 5220.3 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1635.7 MB/s | 7270.0 MB/s | **4.4x** | 1593.1 MB/s | 5112.7 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1240.4 MB/s | 5127.1 MB/s | **4.1x** | 1546.9 MB/s | 4822.2 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 778.7 MB/s | 4998.3 MB/s | **6.4x** | 872.9 MB/s | 5538.0 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 754.6 MB/s | 4920.7 MB/s | **6.5x** | 938.1 MB/s | 5358.5 MB/s | **5.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 211.2 MB/s | 4469.6 MB/s | **21.2x** | 4212.5 MB/s | 4135.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 212.9 MB/s | 1227.9 MB/s | **5.8x** | 3428.3 MB/s | 3442.5 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 144.4 MB/s | 5152.1 MB/s | **35.7x** | 1725.3 MB/s | 4611.5 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.5 MB/s | 1306.9 MB/s | **9.4x** | 1525.6 MB/s | 5045.8 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.1 MB/s | 178.4 MB/s | **2.1x** | 3611.3 MB/s | 10622.4 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.5 MB/s | 169.0 MB/s | **2.0x** | 1901.9 MB/s | 2323.8 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.3 MB/s | 148.1 MB/s | **1.9x** | 3634.6 MB/s | 11309.1 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.4 MB/s | 142.6 MB/s | **2.0x** | 1895.5 MB/s | 2401.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 6224.6 MB/s | 3789.2 MB/s | **0.6x** | 6555.4 MB/s | 4563.1 MB/s | **0.7x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 34.91 MB (34.9%) | 6125.0 MB/s | 8030.7 MB/s | **1.3x** | 5905.8 MB/s | 5402.0 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 814.9 MB/s | 1341.7 MB/s | **1.6x** | 1475.8 MB/s | 5678.3 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 969.5 MB/s | 1712.6 MB/s | **1.8x** | 1681.1 MB/s | 5785.2 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5604.8 MB/s | 5030.8 MB/s | **0.9x** | 5396.6 MB/s | 3715.3 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5423.8 MB/s | 5064.5 MB/s | **0.9x** | 5035.8 MB/s | 4748.0 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 664.3 MB/s | 4608.1 MB/s | **6.9x** | 3566.6 MB/s | 4840.7 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 683.6 MB/s | 4325.9 MB/s | **6.3x** | 3629.0 MB/s | 4483.9 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1047.6 MB/s | 1865.4 MB/s | **1.8x** | 1794.8 MB/s | 10836.5 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1040.6 MB/s | 1865.5 MB/s | **1.8x** | 2008.8 MB/s | 10686.6 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.6 MB/s | 1242.0 MB/s | **12.7x** | 1775.4 MB/s | 12394.4 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.6 MB/s | 1267.2 MB/s | **13.4x** | 2095.1 MB/s | 12178.6 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15108.3 MB/s | 17219.0 MB/s | **1.1x** | 5741.5 MB/s | 4977.8 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10998.6 MB/s | 17043.7 MB/s | **1.5x** | 6428.8 MB/s | 5380.8 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2225.2 MB/s | 10828.5 MB/s | **4.9x** | 1892.5 MB/s | 3183.0 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2024.6 MB/s | 10940.5 MB/s | **5.4x** | 1992.9 MB/s | 3269.8 MB/s | **1.6x** | - |
