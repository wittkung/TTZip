# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 09:10:40 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 913.4 MB/s | 780.7 MB/s | **0.9x** | 480.2 MB/s | 469.3 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 806.1 MB/s | 536.8 MB/s | **0.7x** | 488.6 MB/s | 494.6 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 296.5 MB/s | 375.6 MB/s | **1.3x** | 524.9 MB/s | 634.0 MB/s | **1.2x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 289.7 MB/s | 242.9 MB/s | **0.8x** | 431.5 MB/s | 441.1 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 491.0 MB/s | 1226.6 MB/s | **2.5x** | 520.1 MB/s | 2120.8 MB/s | **4.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 468.1 MB/s | 861.6 MB/s | **1.8x** | 285.9 MB/s | 1803.7 MB/s | **6.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 386.8 MB/s | 1167.0 MB/s | **3.0x** | 530.1 MB/s | 2240.8 MB/s | **4.2x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 381.4 MB/s | 688.4 MB/s | **1.8x** | 281.7 MB/s | 1644.4 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 226.6 MB/s | 1010.1 MB/s | **4.5x** | 260.0 MB/s | 964.2 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 237.8 MB/s | 1047.0 MB/s | **4.4x** | 273.2 MB/s | 927.1 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 715.1 MB/s | 1103.0 MB/s | **1.5x** | 849.3 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 912.2 MB/s | 868.0 MB/s | **1.0x** | 799.7 MB/s | 765.4 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 294.8 MB/s | 542.9 MB/s | **1.8x** | 977.4 MB/s | 1596.6 MB/s | **1.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.8 MB/s | 290.0 MB/s | **1.0x** | 651.9 MB/s | 633.8 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 637.7 MB/s | 1525.6 MB/s | **2.4x** | 972.4 MB/s | 5138.4 MB/s | **5.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 619.5 MB/s | 1512.0 MB/s | **2.4x** | 1062.5 MB/s | 4594.4 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.3 MB/s | 1193.5 MB/s | **16.1x** | 937.3 MB/s | 6849.2 MB/s | **7.3x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.0 MB/s | 1098.5 MB/s | **14.8x** | 1001.4 MB/s | 4474.8 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1410.7 MB/s | 4395.9 MB/s | **3.1x** | 1524.4 MB/s | 4624.2 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1259.6 MB/s | 3715.3 MB/s | **2.9x** | 1432.8 MB/s | 4804.5 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 784.2 MB/s | 4175.6 MB/s | **5.3x** | 918.9 MB/s | 5901.7 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 739.9 MB/s | 3921.2 MB/s | **5.3x** | 914.1 MB/s | 5254.7 MB/s | **5.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 199.4 MB/s | 2861.3 MB/s | **14.3x** | 3803.7 MB/s | 5629.7 MB/s | **1.5x** | 2_SolidBuf_IO_and_CRC32 (98.6%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 188.2 MB/s | 183.7 MB/s | **1.0x** | 3055.9 MB/s | 3032.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 136.8 MB/s | 4050.2 MB/s | **29.6x** | 1628.9 MB/s | 5977.4 MB/s | **3.7x** | 2_SolidBuf_IO_and_CRC32 (91.3%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 133.5 MB/s | 124.5 MB/s | **0.9x** | 1440.5 MB/s | 1463.5 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.1 MB/s | 183.3 MB/s | **2.1x** | 3383.6 MB/s | 7107.4 MB/s | **2.1x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.1 MB/s | 169.4 MB/s | **2.1x** | 1718.6 MB/s | 2157.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.9 MB/s | 148.1 MB/s | **2.0x** | 3554.6 MB/s | 8238.6 MB/s | **2.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.8 MB/s | 140.7 MB/s | **2.0x** | 1734.0 MB/s | 2232.6 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 10.09 MB (10.1%) | 5172.9 MB/s | 7368.3 MB/s | **1.4x** | 6282.4 MB/s | 5126.5 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 10.09 MB (10.1%) | 5555.2 MB/s | 6940.6 MB/s | **1.2x** | 6685.5 MB/s | 5592.3 MB/s | **0.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 934.6 MB/s | 1592.6 MB/s | **1.7x** | 1342.7 MB/s | 3957.2 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 878.4 MB/s | 1655.7 MB/s | **1.9x** | 1319.3 MB/s | 4679.0 MB/s | **3.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 4788.2 MB/s | 2694.3 MB/s | **0.6x** | 5139.9 MB/s | 1408.4 MB/s | **0.3x** | 2_SolidBuf_IO_and_CRC32 (98.7%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 4758.6 MB/s | 4743.1 MB/s | **1.0x** | 4355.5 MB/s | 4678.2 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 642.9 MB/s | 4182.1 MB/s | **6.5x** | 3431.3 MB/s | 2048.5 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 582.6 MB/s | 626.3 MB/s | **1.1x** | 3143.4 MB/s | 3005.1 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 966.4 MB/s | 1502.7 MB/s | **1.6x** | 1530.7 MB/s | 7879.5 MB/s | **5.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1007.0 MB/s | 1737.5 MB/s | **1.7x** | 2019.0 MB/s | 8703.4 MB/s | **4.3x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 87.6 MB/s | 1213.9 MB/s | **13.9x** | 1614.3 MB/s | 11613.3 MB/s | **7.2x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.0 MB/s | 1196.7 MB/s | **13.0x** | 1611.2 MB/s | 11822.6 MB/s | **7.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13754.3 MB/s | 10337.8 MB/s | **0.8x** | 5384.5 MB/s | 6238.7 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 9626.2 MB/s | 11848.7 MB/s | **1.2x** | 5976.3 MB/s | 6761.6 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 1844.3 MB/s | 7506.5 MB/s | **4.1x** | 1617.5 MB/s | 2756.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1757.0 MB/s | 7942.5 MB/s | **4.5x** | 1653.3 MB/s | 2608.5 MB/s | **1.6x** | - |
