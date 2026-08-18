# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 17:09:15 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 835.1 MB/s | 563.5 MB/s | **0.7x** | 360.3 MB/s | 498.6 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 835.1 MB/s | 451.1 MB/s | **0.5x** | 493.8 MB/s | 513.9 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 289.2 MB/s | 398.6 MB/s | **1.4x** | 515.6 MB/s | 751.2 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 283.1 MB/s | 325.2 MB/s | **1.1x** | 442.6 MB/s | 628.5 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 408.7 MB/s | 1062.2 MB/s | **2.6x** | 537.1 MB/s | 1679.0 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 358.2 MB/s | 792.9 MB/s | **2.2x** | 247.0 MB/s | 1392.9 MB/s | **5.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 329.6 MB/s | 1018.9 MB/s | **3.1x** | 419.2 MB/s | 1476.8 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 325.4 MB/s | 807.9 MB/s | **2.5x** | 273.4 MB/s | 1475.2 MB/s | **5.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 218.7 MB/s | 843.7 MB/s | **3.9x** | 255.8 MB/s | 720.1 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 218.5 MB/s | 1021.4 MB/s | **4.7x** | 197.9 MB/s | 807.3 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 333.5 MB/s | 917.7 MB/s | **2.8x** | 1309.1 MB/s | 3279.2 MB/s | **2.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 719.4 MB/s | 604.6 MB/s | **0.8x** | 732.8 MB/s | 931.6 MB/s | **1.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.5 MB/s | 542.2 MB/s | **1.8x** | 938.7 MB/s | 3324.3 MB/s | **3.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.5 MB/s | 418.4 MB/s | **1.4x** | 639.9 MB/s | 439.2 MB/s | **0.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 656.8 MB/s | 1726.2 MB/s | **2.6x** | 937.9 MB/s | 5449.9 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 635.6 MB/s | 1539.1 MB/s | **2.4x** | 981.1 MB/s | 4518.7 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.9 MB/s | 1200.2 MB/s | **15.8x** | 931.9 MB/s | 6437.6 MB/s | **6.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 75.9 MB/s | 1141.0 MB/s | **15.0x** | 998.2 MB/s | 4499.5 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 751.8 MB/s | 5685.7 MB/s | **7.6x** | 1200.9 MB/s | 5582.0 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1268.8 MB/s | 3573.1 MB/s | **2.8x** | 1499.4 MB/s | 2436.1 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 744.0 MB/s | 4552.5 MB/s | **6.1x** | 875.1 MB/s | 2390.7 MB/s | **2.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 758.0 MB/s | 4902.2 MB/s | **6.5x** | 881.1 MB/s | 3456.5 MB/s | **3.9x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 201.7 MB/s | 2816.4 MB/s | **14.0x** | 4119.2 MB/s | 5631.0 MB/s | **1.4x** | 2_SolidBuf_IO_and_CRC32 (97.3%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 216.5 MB/s | 4226.9 MB/s | **19.5x** | 3306.4 MB/s | 7017.2 MB/s | **2.1x** | 2_SolidBuf_IO_and_CRC32 (90.7%) |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 141.0 MB/s | 4300.0 MB/s | **30.5x** | 1599.1 MB/s | 7362.1 MB/s | **4.6x** | 2_SolidBuf_IO_and_CRC32 (90.0%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 140.1 MB/s | 4292.2 MB/s | **30.6x** | 1406.9 MB/s | 6019.8 MB/s | **4.3x** | 2_SolidBuf_IO_and_CRC32 (90.3%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.4 MB/s | 182.0 MB/s | **2.1x** | 3444.6 MB/s | 10908.1 MB/s | **3.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.4 MB/s | 172.8 MB/s | **2.1x** | 1796.2 MB/s | 2287.7 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.7 MB/s | 148.6 MB/s | **2.0x** | 3712.0 MB/s | 10405.4 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.2 MB/s | 139.1 MB/s | **2.0x** | 1792.5 MB/s | 2274.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 4440.4 MB/s | 3454.6 MB/s | **0.8x** | 5902.3 MB/s | 5089.7 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 12.63 MB (12.6%) | 5683.6 MB/s | 8535.9 MB/s | **1.5x** | 6971.7 MB/s | 7555.9 MB/s | **1.1x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 860.4 MB/s | 1597.5 MB/s | **1.9x** | 1520.8 MB/s | 5753.6 MB/s | **3.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 855.6 MB/s | 1581.8 MB/s | **1.8x** | 1458.1 MB/s | 5634.2 MB/s | **3.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5538.0 MB/s | 3930.9 MB/s | **0.7x** | 5583.5 MB/s | 6330.1 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5439.3 MB/s | 4451.6 MB/s | **0.8x** | 5196.0 MB/s | 8268.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 675.2 MB/s | 4521.9 MB/s | **6.7x** | 3616.2 MB/s | 9648.1 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 683.5 MB/s | 4290.2 MB/s | **6.3x** | 3574.7 MB/s | 8498.1 MB/s | **2.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1032.8 MB/s | 1773.1 MB/s | **1.7x** | 1748.8 MB/s | 10443.3 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1026.5 MB/s | 1838.9 MB/s | **1.8x** | 2031.9 MB/s | 10558.3 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.0 MB/s | 1247.3 MB/s | **13.3x** | 1704.7 MB/s | 11507.3 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 91.6 MB/s | 1240.6 MB/s | **13.6x** | 1984.6 MB/s | 11965.0 MB/s | **6.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15634.4 MB/s | 13798.2 MB/s | **0.9x** | 6335.8 MB/s | 6671.5 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9757.6 MB/s | 13302.6 MB/s | **1.4x** | 6126.7 MB/s | 8638.9 MB/s | **1.4x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2110.9 MB/s | 9740.3 MB/s | **4.6x** | 1960.9 MB/s | 3076.6 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1936.5 MB/s | 9821.4 MB/s | **5.1x** | 1592.2 MB/s | 2951.7 MB/s | **1.9x** | - |
