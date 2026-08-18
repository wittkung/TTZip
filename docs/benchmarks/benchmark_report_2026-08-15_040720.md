# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:07:20 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 840.8 MB/s | 900.9 MB/s | **1.1x** | 688.6 MB/s | 1192.4 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 839.9 MB/s | 804.5 MB/s | **1.0x** | 552.1 MB/s | 1353.8 MB/s | **2.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.3 MB/s | 393.7 MB/s | **1.3x** | 587.6 MB/s | 1272.4 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 256.6 MB/s | 424.4 MB/s | **1.7x** | 430.0 MB/s | 1166.3 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 360.5 MB/s | 952.7 MB/s | **2.6x** | 553.8 MB/s | 1776.6 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 388.6 MB/s | 814.4 MB/s | **2.1x** | 283.9 MB/s | 1685.3 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 319.6 MB/s | 1086.6 MB/s | **3.4x** | 551.4 MB/s | 1952.7 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 304.1 MB/s | 770.9 MB/s | **2.5x** | 278.4 MB/s | 1596.0 MB/s | **5.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 222.0 MB/s | 662.5 MB/s | **3.0x** | 234.9 MB/s | 889.6 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 237.4 MB/s | 882.2 MB/s | **3.7x** | 240.8 MB/s | 786.9 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1003.7 MB/s | 1736.5 MB/s | **1.7x** | 1347.6 MB/s | 3913.5 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 902.5 MB/s | 1742.3 MB/s | **1.9x** | 774.5 MB/s | 3461.9 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 273.0 MB/s | 486.5 MB/s | **1.8x** | 847.4 MB/s | 2786.2 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 285.9 MB/s | 530.9 MB/s | **1.9x** | 641.2 MB/s | 2844.6 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 651.3 MB/s | 1679.1 MB/s | **2.6x** | 943.8 MB/s | 4928.9 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 627.9 MB/s | 1553.4 MB/s | **2.5x** | 1013.2 MB/s | 4282.1 MB/s | **4.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.1 MB/s | 1232.6 MB/s | **16.2x** | 898.5 MB/s | 6520.8 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.3 MB/s | 1009.8 MB/s | **13.2x** | 972.6 MB/s | 4766.2 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1404.7 MB/s | 5008.1 MB/s | **3.6x** | 1344.7 MB/s | 3917.7 MB/s | **2.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1150.6 MB/s | 3278.0 MB/s | **2.8x** | 1382.7 MB/s | 4821.3 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 720.0 MB/s | 4135.6 MB/s | **5.7x** | 836.8 MB/s | 4207.5 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 744.3 MB/s | 4136.2 MB/s | **5.6x** | 882.8 MB/s | 4658.4 MB/s | **5.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 198.0 MB/s | 3954.1 MB/s | **20.0x** | 3762.4 MB/s | 3188.7 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 183.1 MB/s | 1155.9 MB/s | **6.3x** | 3035.1 MB/s | 4001.8 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 125.8 MB/s | 4428.7 MB/s | **35.2x** | 1474.8 MB/s | 3501.7 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 119.5 MB/s | 1181.8 MB/s | **9.9x** | 1246.4 MB/s | 3749.1 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.8 MB/s | 170.4 MB/s | **2.0x** | 3649.1 MB/s | 8890.3 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 78.0 MB/s | 167.6 MB/s | **2.1x** | 1726.5 MB/s | 2152.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.7 MB/s | 146.0 MB/s | **2.0x** | 3552.0 MB/s | 9432.8 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.3 MB/s | 141.0 MB/s | **2.0x** | 1735.4 MB/s | 2216.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5258.3 MB/s | 3709.4 MB/s | **0.7x** | 6380.8 MB/s | 3868.4 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.01 MB (10.0%) | 4157.7 MB/s | 13554.0 MB/s | **3.3x** | 4772.1 MB/s | 4968.0 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 970.4 MB/s | 1713.8 MB/s | **1.8x** | 1608.7 MB/s | 4514.8 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 949.6 MB/s | 1734.0 MB/s | **1.8x** | 1654.4 MB/s | 4893.1 MB/s | **3.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5475.6 MB/s | 4664.6 MB/s | **0.9x** | 5274.1 MB/s | 3552.4 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5486.6 MB/s | 4967.1 MB/s | **0.9x** | 4600.9 MB/s | 4143.1 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 676.0 MB/s | 4485.8 MB/s | **6.6x** | 3587.3 MB/s | 5134.0 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 677.3 MB/s | 4578.1 MB/s | **6.8x** | 3718.6 MB/s | 4700.8 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1022.6 MB/s | 1848.8 MB/s | **1.8x** | 1615.1 MB/s | 10320.1 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1022.8 MB/s | 1848.8 MB/s | **1.8x** | 2054.8 MB/s | 10199.1 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.5 MB/s | 1255.0 MB/s | **13.3x** | 1701.9 MB/s | 12121.9 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.9 MB/s | 1235.0 MB/s | **13.0x** | 2058.4 MB/s | 11024.6 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15738.1 MB/s | 19043.4 MB/s | **1.2x** | 5741.3 MB/s | 4971.2 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11008.9 MB/s | 18314.6 MB/s | **1.7x** | 6354.4 MB/s | 5549.0 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2262.4 MB/s | 11166.6 MB/s | **4.9x** | 2000.2 MB/s | 3248.4 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1883.3 MB/s | 11588.1 MB/s | **6.2x** | 1945.4 MB/s | 3143.6 MB/s | **1.6x** | - |
