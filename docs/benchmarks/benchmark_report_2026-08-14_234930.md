# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 15:49:30 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 827.6 MB/s | 817.9 MB/s | **1.0x** | 657.3 MB/s | 871.2 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 792.0 MB/s | 612.1 MB/s | **0.8x** | 531.8 MB/s | 781.5 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 293.3 MB/s | 387.3 MB/s | **1.3x** | 597.2 MB/s | 1114.2 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.2 MB/s | 328.9 MB/s | **1.1x** | 466.2 MB/s | 696.1 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 445.1 MB/s | 1209.9 MB/s | **2.7x** | 564.1 MB/s | 1839.6 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 359.6 MB/s | 864.4 MB/s | **2.4x** | 269.5 MB/s | 1779.9 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 375.7 MB/s | 1160.5 MB/s | **3.1x** | 542.9 MB/s | 2017.4 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 348.3 MB/s | 868.8 MB/s | **2.5x** | 288.3 MB/s | 1825.0 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 250.4 MB/s | 891.8 MB/s | **3.6x** | 265.1 MB/s | 1013.7 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 259.6 MB/s | 1002.0 MB/s | **3.9x** | 264.8 MB/s | 984.5 MB/s | **3.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 1008.2 MB/s | 2540.2 MB/s | **2.5x** | 1287.5 MB/s | 5215.8 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 899.5 MB/s | 1021.8 MB/s | **1.1x** | 789.7 MB/s | 1275.6 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 296.9 MB/s | 491.8 MB/s | **1.7x** | 900.3 MB/s | 3609.4 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.8 MB/s | 401.0 MB/s | **1.4x** | 633.3 MB/s | 1130.9 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 647.4 MB/s | 1664.1 MB/s | **2.6x** | 906.9 MB/s | 5810.7 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 618.4 MB/s | 1487.1 MB/s | **2.4x** | 958.1 MB/s | 4605.2 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.9 MB/s | 1198.9 MB/s | **16.0x** | 880.3 MB/s | 7063.3 MB/s | **8.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.4 MB/s | 1106.6 MB/s | **14.9x** | 973.8 MB/s | 4846.5 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1151.4 MB/s | 4007.9 MB/s | **3.5x** | 1483.2 MB/s | 4503.5 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1200.1 MB/s | 4336.3 MB/s | **3.6x** | 1433.8 MB/s | 4468.8 MB/s | **3.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 706.2 MB/s | 4752.0 MB/s | **6.7x** | 853.6 MB/s | 4244.2 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 711.8 MB/s | 4696.9 MB/s | **6.6x** | 845.9 MB/s | 4771.6 MB/s | **5.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 198.4 MB/s | 4286.3 MB/s | **21.6x** | 4035.6 MB/s | 5757.6 MB/s | **1.4x** | 2_SolidBuf_IO_and_CRC32 (89.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 197.5 MB/s | 4130.4 MB/s | **20.9x** | 3191.2 MB/s | 6461.4 MB/s | **2.0x** | 2_SolidBuf_IO_and_CRC32 (90.1%) |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 127.6 MB/s | 4003.2 MB/s | **31.4x** | 1510.0 MB/s | 6805.9 MB/s | **4.5x** | 2_SolidBuf_IO_and_CRC32 (89.1%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 134.5 MB/s | 4080.7 MB/s | **30.3x** | 1436.3 MB/s | 7067.6 MB/s | **4.9x** | 2_SolidBuf_IO_and_CRC32 (89.8%) |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 88.1 MB/s | 181.2 MB/s | **2.1x** | 3795.2 MB/s | 11162.3 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 82.6 MB/s | 171.4 MB/s | **2.1x** | 1764.8 MB/s | 2296.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.4 MB/s | 144.0 MB/s | **1.9x** | 3530.9 MB/s | 10482.3 MB/s | **3.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.3 MB/s | 138.6 MB/s | **2.0x** | 1762.9 MB/s | 2307.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5835.5 MB/s | 7913.1 MB/s | **1.4x** | 6733.3 MB/s | 6175.9 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5708.9 MB/s | 8127.9 MB/s | **1.4x** | 6979.7 MB/s | 6408.4 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 940.6 MB/s | 1650.9 MB/s | **1.8x** | 1600.7 MB/s | 5279.9 MB/s | **3.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 913.9 MB/s | 1588.2 MB/s | **1.7x** | 1542.7 MB/s | 5212.1 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.14 MB (0.0%) | 5346.5 MB/s | 2691.1 MB/s | **0.5x** | 5584.5 MB/s | 6879.9 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.14 MB (0.0%) | 5514.1 MB/s | 4452.0 MB/s | **0.8x** | 5196.9 MB/s | 8511.0 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 653.2 MB/s | 4338.1 MB/s | **6.6x** | 3514.7 MB/s | 9052.0 MB/s | **2.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 647.0 MB/s | 4241.0 MB/s | **6.6x** | 3407.6 MB/s | 8096.5 MB/s | **2.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1023.0 MB/s | 1832.0 MB/s | **1.8x** | 1692.0 MB/s | 10745.7 MB/s | **6.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1020.6 MB/s | 1829.1 MB/s | **1.8x** | 2033.0 MB/s | 10484.3 MB/s | **5.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.6 MB/s | 1242.6 MB/s | **13.3x** | 1704.3 MB/s | 12400.4 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.7 MB/s | 1240.6 MB/s | **13.2x** | 2020.2 MB/s | 11804.5 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15272.3 MB/s | 11515.5 MB/s | **0.8x** | 5684.6 MB/s | 6267.2 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10583.2 MB/s | 13439.7 MB/s | **1.3x** | 6383.7 MB/s | 6579.5 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1995.8 MB/s | 10604.5 MB/s | **5.3x** | 1898.0 MB/s | 3152.7 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1913.5 MB/s | 10211.5 MB/s | **5.3x** | 1947.6 MB/s | 3148.5 MB/s | **1.6x** | - |
