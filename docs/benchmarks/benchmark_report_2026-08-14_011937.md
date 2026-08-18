# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-13 17:19:37 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 805.1 MB/s | 301.4 MB/s | **0.4x** | 695.7 MB/s | 650.2 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 791.4 MB/s | 215.4 MB/s | **0.3x** | 533.5 MB/s | 438.1 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 296.3 MB/s | 422.0 MB/s | **1.4x** | 578.3 MB/s | 709.3 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.6 MB/s | 245.0 MB/s | **0.8x** | 464.3 MB/s | 437.9 MB/s | **0.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 439.0 MB/s | 656.7 MB/s | **1.5x** | 553.0 MB/s | 1727.0 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 458.4 MB/s | 561.4 MB/s | **1.2x** | 301.4 MB/s | 248.7 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 400.8 MB/s | 651.7 MB/s | **1.6x** | 587.8 MB/s | 2125.3 MB/s | **3.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 372.8 MB/s | 512.8 MB/s | **1.4x** | 294.6 MB/s | 247.0 MB/s | **0.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 291.4 MB/s | 399.6 MB/s | **1.4x** | 261.0 MB/s | 915.4 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 171.7 MB/s | 384.6 MB/s | **2.2x** | 172.0 MB/s | 927.3 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 994.6 MB/s | 534.8 MB/s | **0.5x** | 1333.3 MB/s | 1525.4 MB/s | **1.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 519.9 MB/s | 294.4 MB/s | **0.6x** | 198.1 MB/s | 634.7 MB/s | **3.2x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 304.0 MB/s | 468.8 MB/s | **1.5x** | 969.2 MB/s | 1759.0 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 300.6 MB/s | 301.0 MB/s | **1.0x** | 665.6 MB/s | 629.5 MB/s | **0.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 651.3 MB/s | 1042.9 MB/s | **1.6x** | 919.2 MB/s | 6684.1 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 643.2 MB/s | 1067.7 MB/s | **1.7x** | 1042.0 MB/s | 770.8 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.3 MB/s | 856.2 MB/s | **11.2x** | 753.4 MB/s | 7480.4 MB/s | **9.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.3 MB/s | 800.8 MB/s | **10.6x** | 997.1 MB/s | 614.1 MB/s | **0.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1583.2 MB/s | 1857.9 MB/s | **1.2x** | 1661.8 MB/s | 6107.4 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1225.8 MB/s | 1437.0 MB/s | **1.2x** | 1440.6 MB/s | 6194.3 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.3%) | 597.8 MB/s | 543.2 MB/s | **0.9x** | 649.1 MB/s | 4631.3 MB/s | **7.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 659.5 MB/s | 573.2 MB/s | **0.9x** | 544.6 MB/s | 5101.9 MB/s | **9.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 178.0 MB/s | 2424.8 MB/s | **13.6x** | 3316.5 MB/s | 6856.7 MB/s | **2.1x** | 2_SolidBuf_IO_and_CRC32 (96.8%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 170.7 MB/s | 170.6 MB/s | **1.0x** | 2970.4 MB/s | 1399.6 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 127.6 MB/s | 2482.7 MB/s | **19.5x** | 1610.6 MB/s | 5554.3 MB/s | **3.4x** | 2_SolidBuf_IO_and_CRC32 (97.0%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 130.6 MB/s | 175.9 MB/s | **1.3x** | 1265.9 MB/s | 1416.5 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 84.6 MB/s | 1582.3 MB/s | **18.7x** | 3537.0 MB/s | 10429.3 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 79.4 MB/s | 856.3 MB/s | **10.8x** | 1779.2 MB/s | 913.3 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.1 MB/s | 1785.4 MB/s | **25.5x** | 3548.8 MB/s | 8907.3 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 68.9 MB/s | 1009.5 MB/s | **14.7x** | 1756.3 MB/s | 826.9 MB/s | **0.5x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5906.4 MB/s | 1209.4 MB/s | **0.2x** | 6729.3 MB/s | 5892.5 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5962.2 MB/s | 1572.1 MB/s | **0.3x** | 6001.1 MB/s | 7863.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 610.5 MB/s | 75.8 MB/s | **0.1x** | 1114.3 MB/s | 5032.5 MB/s | **4.5x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 786.0 MB/s | 73.8 MB/s | **0.1x** | 1565.7 MB/s | 3502.5 MB/s | **2.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5126.1 MB/s | 2993.9 MB/s | **0.6x** | 5158.4 MB/s | 1643.6 MB/s | **0.3x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 4921.7 MB/s | 651.2 MB/s | **0.1x** | 4187.3 MB/s | 3136.0 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 639.8 MB/s | 2816.6 MB/s | **4.4x** | 3197.5 MB/s | 1947.1 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 622.1 MB/s | 642.5 MB/s | **1.0x** | 3299.7 MB/s | 3398.2 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 995.1 MB/s | 537.8 MB/s | **0.5x** | 1445.5 MB/s | 6620.6 MB/s | **4.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 894.6 MB/s | 525.0 MB/s | **0.6x** | 1772.7 MB/s | 1400.9 MB/s | **0.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 85.2 MB/s | 459.6 MB/s | **5.4x** | 1388.9 MB/s | 11290.0 MB/s | **8.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 88.4 MB/s | 474.1 MB/s | **5.4x** | 1980.4 MB/s | 1308.8 MB/s | **0.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 12514.4 MB/s | 1496.6 MB/s | **0.1x** | 5203.3 MB/s | 6752.8 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11128.4 MB/s | 1244.7 MB/s | **0.1x** | 5800.4 MB/s | 8902.2 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1831.2 MB/s | 526.2 MB/s | **0.3x** | 1351.9 MB/s | 2450.1 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1894.9 MB/s | 544.4 MB/s | **0.3x** | 1296.3 MB/s | 3006.4 MB/s | **2.3x** | - |
