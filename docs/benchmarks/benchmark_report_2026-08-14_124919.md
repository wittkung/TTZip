# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:49:19 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 842.3 MB/s | 532.1 MB/s | **0.6x** | 724.0 MB/s | 610.7 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 833.2 MB/s | 464.4 MB/s | **0.6x** | 520.7 MB/s | 482.3 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 237.9 MB/s | 245.2 MB/s | **1.0x** | 607.8 MB/s | 695.4 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.3 MB/s | 245.0 MB/s | **0.8x** | 471.7 MB/s | 479.9 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 358.8 MB/s | 1218.7 MB/s | **3.4x** | 491.1 MB/s | 1630.1 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 390.0 MB/s | 661.1 MB/s | **1.7x** | 288.1 MB/s | 1614.3 MB/s | **5.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 266.0 MB/s | 1064.3 MB/s | **4.0x** | 538.0 MB/s | 2168.7 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 299.8 MB/s | 871.6 MB/s | **2.9x** | 284.1 MB/s | 1944.0 MB/s | **6.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 279.4 MB/s | 1043.0 MB/s | **3.7x** | 289.0 MB/s | 1034.5 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 280.9 MB/s | 1079.4 MB/s | **3.8x** | 283.4 MB/s | 974.5 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1028.1 MB/s | 989.9 MB/s | **1.0x** | 1373.8 MB/s | 1769.0 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 913.7 MB/s | 875.3 MB/s | **1.0x** | 817.4 MB/s | 786.3 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.3 MB/s | 296.0 MB/s | **1.0x** | 963.8 MB/s | 1663.8 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.4 MB/s | 294.9 MB/s | **1.0x** | 633.4 MB/s | 629.2 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 646.5 MB/s | 1677.9 MB/s | **2.6x** | 943.4 MB/s | 6323.2 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 642.7 MB/s | 1611.7 MB/s | **2.5x** | 1038.1 MB/s | 4713.4 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.5 MB/s | 1242.2 MB/s | **16.9x** | 272.5 MB/s | 7300.0 MB/s | **26.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.4 MB/s | 1147.9 MB/s | **15.2x** | 1010.3 MB/s | 5394.9 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1641.6 MB/s | 4132.7 MB/s | **2.5x** | 1728.7 MB/s | 4851.2 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1248.0 MB/s | 4578.7 MB/s | **3.7x** | 1578.4 MB/s | 4972.9 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 782.8 MB/s | 4424.5 MB/s | **5.7x** | 932.2 MB/s | 4959.8 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 748.7 MB/s | 3730.9 MB/s | **5.0x** | 928.8 MB/s | 5526.8 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 235.2 MB/s | 225.4 MB/s | **1.0x** | 4440.2 MB/s | 5247.3 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 232.1 MB/s | 219.2 MB/s | **0.9x** | 3462.0 MB/s | 3327.4 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 140.6 MB/s | 145.7 MB/s | **1.0x** | 1609.3 MB/s | 4012.3 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 147.1 MB/s | 142.8 MB/s | **1.0x** | 1525.9 MB/s | 1460.3 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 89.1 MB/s | 186.5 MB/s | **2.1x** | 3936.2 MB/s | 11448.5 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.1 MB/s | 171.7 MB/s | **2.0x** | 1941.3 MB/s | 2413.1 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.3 MB/s | 149.4 MB/s | **2.0x** | 3771.1 MB/s | 11689.8 MB/s | **3.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 71.5 MB/s | 140.0 MB/s | **2.0x** | 1921.0 MB/s | 2443.4 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 6215.0 MB/s | 6542.2 MB/s | **1.1x** | 7036.7 MB/s | 6965.8 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 6328.4 MB/s | 6288.8 MB/s | **1.0x** | 7433.9 MB/s | 7016.9 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1045.0 MB/s | 1817.7 MB/s | **1.7x** | 1691.3 MB/s | 5793.6 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 995.5 MB/s | 1811.8 MB/s | **1.8x** | 1689.0 MB/s | 5677.0 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5629.4 MB/s | 5606.8 MB/s | **1.0x** | 6032.2 MB/s | 2088.7 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5676.8 MB/s | 5680.3 MB/s | **1.0x** | 4982.7 MB/s | 5372.8 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 692.2 MB/s | 680.6 MB/s | **1.0x** | 3770.1 MB/s | 2086.0 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 690.7 MB/s | 685.8 MB/s | **1.0x** | 3637.3 MB/s | 3636.6 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1016.0 MB/s | 1824.0 MB/s | **1.8x** | 1804.9 MB/s | 7108.0 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1045.3 MB/s | 1815.0 MB/s | **1.7x** | 2130.5 MB/s | 7363.9 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 97.2 MB/s | 1270.1 MB/s | **13.1x** | 1815.6 MB/s | 12446.6 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 96.6 MB/s | 1271.2 MB/s | **13.2x** | 1947.5 MB/s | 12264.2 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15667.6 MB/s | 4260.5 MB/s | **0.3x** | 6239.9 MB/s | 6947.0 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11324.0 MB/s | 4618.4 MB/s | **0.4x** | 6520.2 MB/s | 7121.0 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2168.8 MB/s | 9585.0 MB/s | **4.4x** | 1976.7 MB/s | 3239.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2075.7 MB/s | 9151.9 MB/s | **4.4x** | 2031.8 MB/s | 3317.6 MB/s | **1.6x** | - |
