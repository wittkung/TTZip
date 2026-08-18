# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 09:06:56 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 821.7 MB/s | 1106.0 MB/s | **1.3x** | 662.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 830.2 MB/s | 533.6 MB/s | **0.6x** | 509.0 MB/s | 530.7 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 269.4 MB/s | 362.2 MB/s | **1.3x** | 557.3 MB/s | 567.8 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.5 MB/s | 238.1 MB/s | **0.8x** | 444.2 MB/s | 399.7 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 324.9 MB/s | 1200.2 MB/s | **3.7x** | 280.0 MB/s | 2051.6 MB/s | **7.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 426.3 MB/s | 690.1 MB/s | **1.6x** | 260.6 MB/s | 1483.5 MB/s | **5.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 347.0 MB/s | 1105.9 MB/s | **3.2x** | 462.6 MB/s | 1827.5 MB/s | **4.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 378.6 MB/s | 828.8 MB/s | **2.2x** | 293.9 MB/s | 1531.1 MB/s | **5.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 183.4 MB/s | 1074.4 MB/s | **5.9x** | 285.8 MB/s | 927.6 MB/s | **3.2x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 270.4 MB/s | 1114.4 MB/s | **4.1x** | 281.4 MB/s | 880.2 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.03 MB (0.2%) | 1082.7 MB/s | 6696.1 MB/s | **6.2x** | 1421.8 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 918.2 MB/s | 569.5 MB/s | **0.6x** | 819.4 MB/s | 258.9 MB/s | **0.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.4 MB/s | 550.2 MB/s | **1.9x** | 989.7 MB/s | 1583.0 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 295.8 MB/s | 292.1 MB/s | **1.0x** | 659.7 MB/s | 620.5 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 657.2 MB/s | 1795.1 MB/s | **2.7x** | 982.3 MB/s | 6463.6 MB/s | **6.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 646.8 MB/s | 1550.5 MB/s | **2.4x** | 1097.8 MB/s | 4330.5 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.4 MB/s | 1241.9 MB/s | **16.3x** | 927.9 MB/s | 6215.9 MB/s | **6.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.4 MB/s | 1174.2 MB/s | **15.4x** | 1009.6 MB/s | 4981.3 MB/s | **4.9x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1596.1 MB/s | 3276.9 MB/s | **2.1x** | 1557.7 MB/s | 4376.1 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1259.8 MB/s | 4016.2 MB/s | **3.2x** | 1524.9 MB/s | 4298.0 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 755.6 MB/s | 4075.7 MB/s | **5.4x** | 874.2 MB/s | 5148.0 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 783.3 MB/s | 4637.4 MB/s | **5.9x** | 875.0 MB/s | 4846.0 MB/s | **5.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 193.9 MB/s | 4394.6 MB/s | **22.7x** | 3978.1 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (94.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 179.1 MB/s | 178.2 MB/s | **1.0x** | 3152.2 MB/s | 3221.2 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 131.7 MB/s | 4442.6 MB/s | **33.7x** | 1565.6 MB/s | 0.0 MB/s | **0.0x** | 2_SolidBuf_IO_and_CRC32 (93.8%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 129.7 MB/s | 120.4 MB/s | **0.9x** | 1240.5 MB/s | 1369.8 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.3 MB/s | 155.9 MB/s | **1.8x** | 3726.0 MB/s | 10141.0 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 83.4 MB/s | 168.7 MB/s | **2.0x** | 1762.4 MB/s | 2234.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.3 MB/s | 137.6 MB/s | **1.9x** | 3860.1 MB/s | 9735.9 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.8 MB/s | 137.8 MB/s | **1.9x** | 1808.6 MB/s | 2262.2 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5396.6 MB/s | 8343.0 MB/s | **1.5x** | 5984.0 MB/s | 6101.7 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5906.8 MB/s | 8038.1 MB/s | **1.4x** | 7294.5 MB/s | 6169.5 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1012.5 MB/s | 1674.1 MB/s | **1.7x** | 1652.4 MB/s | 5338.6 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 969.6 MB/s | 1724.6 MB/s | **1.8x** | 1495.7 MB/s | 5528.6 MB/s | **3.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 5541.1 MB/s | 4694.1 MB/s | **0.8x** | 5920.3 MB/s | 1416.4 MB/s | **0.2x** | 2_SolidBuf_IO_and_CRC32 (92.7%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5271.9 MB/s | 5393.2 MB/s | **1.0x** | 4889.7 MB/s | 5171.8 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 671.0 MB/s | 4673.4 MB/s | **7.0x** | 3195.5 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 653.2 MB/s | 644.5 MB/s | **1.0x** | 3413.9 MB/s | 3264.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1025.2 MB/s | 1843.5 MB/s | **1.8x** | 1724.3 MB/s | 6604.9 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1030.1 MB/s | 1823.5 MB/s | **1.8x** | 1988.6 MB/s | 9570.3 MB/s | **4.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.2 MB/s | 1247.6 MB/s | **13.2x** | 1574.0 MB/s | 11005.7 MB/s | **7.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 81.9 MB/s | 1177.4 MB/s | **14.4x** | 156.0 MB/s | 6111.3 MB/s | **39.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 6539.0 MB/s | 8537.3 MB/s | **1.3x** | 3377.4 MB/s | 976.1 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9343.8 MB/s | 9706.3 MB/s | **1.0x** | 1924.7 MB/s | 6013.8 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1024.5 MB/s | 4261.9 MB/s | **4.2x** | 541.5 MB/s | 1332.5 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1085.6 MB/s | 1639.2 MB/s | **1.5x** | 428.5 MB/s | 1179.3 MB/s | **2.8x** | - |
