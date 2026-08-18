# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:44:35 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 847.1 MB/s | 1005.7 MB/s | **1.2x** | 634.6 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 822.4 MB/s | 522.3 MB/s | **0.6x** | 516.1 MB/s | 451.4 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 297.2 MB/s | 375.7 MB/s | **1.3x** | 594.7 MB/s | 633.0 MB/s | **1.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.2 MB/s | 234.5 MB/s | **0.8x** | 455.7 MB/s | 402.9 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 464.6 MB/s | 1079.8 MB/s | **2.3x** | 519.4 MB/s | 1806.3 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 471.7 MB/s | 770.1 MB/s | **1.6x** | 293.9 MB/s | 1611.6 MB/s | **5.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 396.0 MB/s | 1233.6 MB/s | **3.1x** | 573.4 MB/s | 1871.8 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 357.6 MB/s | 827.5 MB/s | **2.3x** | 278.8 MB/s | 1622.0 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 222.8 MB/s | 1055.2 MB/s | **4.7x** | 254.2 MB/s | 774.8 MB/s | **3.0x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 167.2 MB/s | 1019.6 MB/s | **6.1x** | 202.1 MB/s | 928.8 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.03 MB (0.2%) | 1077.9 MB/s | 6385.6 MB/s | **5.9x** | 1489.4 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 984.9 MB/s | 954.2 MB/s | **1.0x** | 883.1 MB/s | 828.9 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.8 MB/s | 537.3 MB/s | **1.8x** | 1040.1 MB/s | 1896.6 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.1 MB/s | 286.9 MB/s | **1.0x** | 694.0 MB/s | 677.7 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 684.0 MB/s | 1799.9 MB/s | **2.6x** | 1039.9 MB/s | 5577.3 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 670.1 MB/s | 1424.1 MB/s | **2.1x** | 1100.8 MB/s | 5018.8 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.8 MB/s | 1146.4 MB/s | **14.2x** | 1007.9 MB/s | 6835.1 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.8 MB/s | 1208.3 MB/s | **15.0x** | 1076.1 MB/s | 5084.7 MB/s | **4.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1721.9 MB/s | 4743.1 MB/s | **2.8x** | 1820.5 MB/s | 4525.6 MB/s | **2.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1312.9 MB/s | 4993.9 MB/s | **3.8x** | 1682.5 MB/s | 5091.6 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 770.1 MB/s | 3733.2 MB/s | **4.8x** | 939.1 MB/s | 5005.8 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 807.7 MB/s | 4085.6 MB/s | **5.1x** | 966.3 MB/s | 5500.8 MB/s | **5.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 223.6 MB/s | 4736.1 MB/s | **21.2x** | 4411.2 MB/s | 7628.7 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (93.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 233.1 MB/s | 230.6 MB/s | **1.0x** | 3467.0 MB/s | 3389.1 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 148.4 MB/s | 4499.8 MB/s | **30.3x** | 1708.2 MB/s | 7174.8 MB/s | **4.2x** | 2_SolidBuf_IO_and_CRC32 (92.9%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 147.7 MB/s | 148.3 MB/s | **1.0x** | 1504.6 MB/s | 1598.3 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 91.4 MB/s | 182.2 MB/s | **2.0x** | 4178.0 MB/s | 11457.7 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.0 MB/s | 173.8 MB/s | **2.1x** | 1945.8 MB/s | 2347.9 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 76.4 MB/s | 150.4 MB/s | **2.0x** | 4080.3 MB/s | 11439.8 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.3 MB/s | 142.1 MB/s | **2.0x** | 1896.3 MB/s | 2443.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 5709.9 MB/s | 6674.4 MB/s | **1.2x** | 6115.9 MB/s | 6106.0 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 6330.9 MB/s | 6734.9 MB/s | **1.1x** | 4669.5 MB/s | 7328.2 MB/s | **1.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1041.0 MB/s | 1791.5 MB/s | **1.7x** | 1721.6 MB/s | 5868.7 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1015.7 MB/s | 1815.8 MB/s | **1.8x** | 1691.7 MB/s | 5993.1 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 5570.7 MB/s | 4994.5 MB/s | **0.9x** | 5493.0 MB/s | 7902.7 MB/s | **1.4x** | 2_SolidBuf_IO_and_CRC32 (92.7%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5535.8 MB/s | 5321.2 MB/s | **1.0x** | 5357.0 MB/s | 5267.3 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 686.4 MB/s | 4659.8 MB/s | **6.8x** | 3638.6 MB/s | 2107.8 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 689.9 MB/s | 684.7 MB/s | **1.0x** | 3514.3 MB/s | 3627.2 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1035.5 MB/s | 1886.1 MB/s | **1.8x** | 1791.0 MB/s | 7282.1 MB/s | **4.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1053.4 MB/s | 1835.8 MB/s | **1.7x** | 1979.8 MB/s | 7596.5 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.6 MB/s | 1228.2 MB/s | **12.5x** | 1843.4 MB/s | 11664.6 MB/s | **6.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 98.7 MB/s | 1270.8 MB/s | **12.9x** | 2169.9 MB/s | 11670.7 MB/s | **5.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15587.0 MB/s | 4799.7 MB/s | **0.3x** | 6234.3 MB/s | 7205.0 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11630.2 MB/s | 4796.7 MB/s | **0.4x** | 6545.9 MB/s | 7042.1 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2078.2 MB/s | 9143.6 MB/s | **4.4x** | 2002.3 MB/s | 3330.2 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2042.6 MB/s | 9170.2 MB/s | **4.5x** | 2008.4 MB/s | 3251.7 MB/s | **1.6x** | - |
