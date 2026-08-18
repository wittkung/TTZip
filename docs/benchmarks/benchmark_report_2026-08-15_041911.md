# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:19:11 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 919.8 MB/s | 961.2 MB/s | **1.0x** | 702.7 MB/s | 1224.6 MB/s | **1.7x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 884.7 MB/s | 820.0 MB/s | **0.9x** | 561.3 MB/s | 1261.1 MB/s | **2.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 292.9 MB/s | 412.4 MB/s | **1.4x** | 633.0 MB/s | 1167.6 MB/s | **1.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 284.0 MB/s | 430.1 MB/s | **1.5x** | 471.4 MB/s | 1233.8 MB/s | **2.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 516.6 MB/s | 1264.5 MB/s | **2.4x** | 590.4 MB/s | 1919.3 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 473.5 MB/s | 919.5 MB/s | **1.9x** | 300.1 MB/s | 965.3 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 392.1 MB/s | 857.1 MB/s | **2.2x** | 549.3 MB/s | 1724.1 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 370.0 MB/s | 866.3 MB/s | **2.3x** | 294.9 MB/s | 1738.5 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 281.9 MB/s | 1066.6 MB/s | **3.8x** | 275.4 MB/s | 652.6 MB/s | **2.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 277.1 MB/s | 1042.5 MB/s | **3.8x** | 277.3 MB/s | 1021.9 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1011.8 MB/s | 1649.5 MB/s | **1.6x** | 1298.8 MB/s | 4382.6 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 912.8 MB/s | 1722.1 MB/s | **1.9x** | 769.5 MB/s | 4200.5 MB/s | **5.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 282.8 MB/s | 487.0 MB/s | **1.7x** | 983.8 MB/s | 3133.9 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 283.3 MB/s | 540.6 MB/s | **1.9x** | 681.8 MB/s | 3142.1 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 666.7 MB/s | 1713.6 MB/s | **2.6x** | 967.6 MB/s | 6076.5 MB/s | **6.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 642.0 MB/s | 1510.7 MB/s | **2.4x** | 1023.9 MB/s | 4833.8 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.7 MB/s | 1218.8 MB/s | **15.7x** | 929.9 MB/s | 7088.4 MB/s | **7.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.0 MB/s | 1051.9 MB/s | **13.2x** | 1020.9 MB/s | 4542.2 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1343.9 MB/s | 8413.5 MB/s | **6.3x** | 1673.5 MB/s | 4748.3 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1208.7 MB/s | 5885.5 MB/s | **4.9x** | 1569.4 MB/s | 5348.7 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 766.7 MB/s | 4605.8 MB/s | **6.0x** | 885.6 MB/s | 5497.2 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 762.7 MB/s | 5181.9 MB/s | **6.8x** | 882.5 MB/s | 5060.4 MB/s | **5.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 191.1 MB/s | 4413.6 MB/s | **23.1x** | 4162.7 MB/s | 4246.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 184.2 MB/s | 1292.6 MB/s | **7.0x** | 3348.6 MB/s | 3778.2 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 134.8 MB/s | 5059.9 MB/s | **37.5x** | 1731.2 MB/s | 4342.6 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 137.5 MB/s | 1256.9 MB/s | **9.1x** | 1501.3 MB/s | 4074.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.9 MB/s | 180.2 MB/s | **2.0x** | 3882.6 MB/s | 10791.0 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.2 MB/s | 169.3 MB/s | **2.0x** | 1834.5 MB/s | 2303.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.6 MB/s | 147.1 MB/s | **2.0x** | 3389.1 MB/s | 11373.2 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 139.2 MB/s | **2.0x** | 1453.9 MB/s | 2307.4 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5565.8 MB/s | 3770.8 MB/s | **0.7x** | 3721.6 MB/s | 4352.6 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 27.26 MB (27.3%) | 3175.2 MB/s | 8964.0 MB/s | **2.8x** | 5300.5 MB/s | 4055.0 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 813.4 MB/s | 1695.5 MB/s | **2.1x** | 1419.0 MB/s | 5773.1 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 908.2 MB/s | 1547.3 MB/s | **1.7x** | 1622.8 MB/s | 5530.1 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5494.3 MB/s | 2666.6 MB/s | **0.5x** | 5189.1 MB/s | 3612.1 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5468.8 MB/s | 4536.9 MB/s | **0.8x** | 4346.1 MB/s | 4592.1 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 680.8 MB/s | 4486.4 MB/s | **6.6x** | 3459.7 MB/s | 4635.9 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 679.3 MB/s | 4182.1 MB/s | **6.2x** | 3468.2 MB/s | 4500.2 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1042.6 MB/s | 1862.6 MB/s | **1.8x** | 1739.4 MB/s | 10930.5 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1038.9 MB/s | 1860.4 MB/s | **1.8x** | 2112.6 MB/s | 10726.9 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.9 MB/s | 1267.1 MB/s | **13.2x** | 1748.4 MB/s | 12397.3 MB/s | **7.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.3 MB/s | 1258.0 MB/s | **13.2x** | 1998.5 MB/s | 11908.0 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15099.4 MB/s | 19032.8 MB/s | **1.3x** | 6062.4 MB/s | 4735.4 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11212.1 MB/s | 16710.0 MB/s | **1.5x** | 6113.1 MB/s | 5068.7 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2223.7 MB/s | 10654.1 MB/s | **4.8x** | 1942.2 MB/s | 3216.9 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2066.3 MB/s | 10939.3 MB/s | **5.3x** | 2022.7 MB/s | 3300.9 MB/s | **1.6x** | - |
