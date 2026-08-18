# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 21:59:19 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 693.4 MB/s | 1230.8 MB/s | **1.8x** | 551.2 MB/s | 1183.6 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 697.8 MB/s | 1337.6 MB/s | **1.9x** | 431.0 MB/s | 1221.9 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 231.8 MB/s | 429.6 MB/s | **1.9x** | 442.2 MB/s | 965.0 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 230.7 MB/s | 415.9 MB/s | **1.8x** | 363.8 MB/s | 971.4 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 366.7 MB/s | 999.7 MB/s | **2.7x** | 480.5 MB/s | 1813.0 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 361.4 MB/s | 828.2 MB/s | **2.3x** | 280.0 MB/s | 1668.4 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 320.0 MB/s | 1115.5 MB/s | **3.5x** | 473.4 MB/s | 1994.1 MB/s | **4.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 316.5 MB/s | 803.1 MB/s | **2.5x** | 279.1 MB/s | 1682.1 MB/s | **6.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 275.9 MB/s | 950.3 MB/s | **3.4x** | 271.8 MB/s | 979.2 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 196.7 MB/s | 1004.0 MB/s | **5.1x** | 280.3 MB/s | 1068.3 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 912.9 MB/s | 1538.1 MB/s | **1.7x** | 1205.9 MB/s | 4624.0 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 855.5 MB/s | 1490.5 MB/s | **1.7x** | 735.3 MB/s | 4605.3 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 248.3 MB/s | 484.6 MB/s | **2.0x** | 813.6 MB/s | 3136.5 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 242.6 MB/s | 501.0 MB/s | **2.1x** | 573.6 MB/s | 3296.3 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 596.5 MB/s | 1619.8 MB/s | **2.7x** | 843.3 MB/s | 5234.6 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 581.6 MB/s | 1459.8 MB/s | **2.5x** | 828.6 MB/s | 3943.0 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 71.3 MB/s | 1124.2 MB/s | **15.8x** | 913.4 MB/s | 5618.3 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 71.8 MB/s | 1138.0 MB/s | **15.9x** | 955.1 MB/s | 4609.2 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1505.3 MB/s | 8309.0 MB/s | **5.5x** | 1565.5 MB/s | 4697.2 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1237.0 MB/s | 5661.1 MB/s | **4.6x** | 1523.9 MB/s | 4933.3 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 795.4 MB/s | 4788.8 MB/s | **6.0x** | 942.2 MB/s | 5320.8 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 750.7 MB/s | 4927.5 MB/s | **6.6x** | 910.1 MB/s | 5467.9 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 181.4 MB/s | 5190.1 MB/s | **28.6x** | 3370.0 MB/s | 5842.4 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 181.0 MB/s | 1266.4 MB/s | **7.0x** | 2968.5 MB/s | 6882.4 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 138.3 MB/s | 5125.3 MB/s | **37.1x** | 1621.9 MB/s | 6102.8 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.0 MB/s | 1338.3 MB/s | **9.9x** | 1426.7 MB/s | 7069.5 MB/s | **5.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.5 MB/s | 172.6 MB/s | **2.1x** | 3344.5 MB/s | 9575.2 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 77.1 MB/s | 173.4 MB/s | **2.2x** | 1743.2 MB/s | 2303.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.8 MB/s | 139.5 MB/s | **1.9x** | 3575.2 MB/s | 10581.1 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 66.4 MB/s | 140.0 MB/s | **2.1x** | 1743.5 MB/s | 2204.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4767.8 MB/s | 4714.2 MB/s | **1.0x** | 6532.1 MB/s | 3460.8 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5437.6 MB/s | 4586.1 MB/s | **0.8x** | 6597.1 MB/s | 3897.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 866.8 MB/s | 1522.6 MB/s | **1.8x** | 1387.0 MB/s | 4272.6 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 831.1 MB/s | 1541.3 MB/s | **1.9x** | 1374.8 MB/s | 4827.6 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4707.2 MB/s | 4268.1 MB/s | **0.9x** | 4852.0 MB/s | 8498.2 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 4736.7 MB/s | 4193.5 MB/s | **0.9x** | 4234.0 MB/s | 8091.3 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 554.9 MB/s | 4064.5 MB/s | **7.3x** | 3042.1 MB/s | 8063.7 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 553.2 MB/s | 3897.9 MB/s | **7.0x** | 2736.9 MB/s | 7165.6 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 925.0 MB/s | 1640.2 MB/s | **1.8x** | 1617.2 MB/s | 8733.4 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 955.1 MB/s | 1694.7 MB/s | **1.8x** | 1943.6 MB/s | 9214.8 MB/s | **4.7x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 89.5 MB/s | 1158.9 MB/s | **12.9x** | 1624.0 MB/s | 10235.9 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.4 MB/s | 1111.7 MB/s | **12.2x** | 1852.1 MB/s | 9809.3 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9611.6 MB/s | 14661.7 MB/s | **1.5x** | 4853.5 MB/s | 3749.0 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 8252.7 MB/s | 17391.2 MB/s | **2.1x** | 5152.2 MB/s | 3674.9 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2130.6 MB/s | 8535.5 MB/s | **4.0x** | 1609.6 MB/s | 2709.6 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1864.0 MB/s | 8983.1 MB/s | **4.8x** | 1560.9 MB/s | 2590.7 MB/s | **1.7x** | - |
