# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 04:46:23 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.06 MB (0.5%) | 962.4 MB/s | 736.5 MB/s | **0.8x** | 738.0 MB/s | 0.0 MB/s | **0.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 894.8 MB/s | 565.3 MB/s | **0.6x** | 577.3 MB/s | 568.5 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.4 MB/s | 413.8 MB/s | **1.4x** | 585.7 MB/s | 760.8 MB/s | **1.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.4 MB/s | 245.3 MB/s | **0.8x** | 497.9 MB/s | 483.7 MB/s | **1.0x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 513.7 MB/s | 1289.7 MB/s | **2.5x** | 603.8 MB/s | 1889.2 MB/s | **3.1x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 473.5 MB/s | 904.5 MB/s | **1.9x** | 304.0 MB/s | 2000.6 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 409.5 MB/s | 1284.9 MB/s | **3.1x** | 600.8 MB/s | 2010.0 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 389.9 MB/s | 957.9 MB/s | **2.5x** | 307.3 MB/s | 1861.2 MB/s | **6.1x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 251.8 MB/s | 1108.8 MB/s | **4.4x** | 273.4 MB/s | 1006.6 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 270.5 MB/s | 1058.3 MB/s | **3.9x** | 277.4 MB/s | 916.5 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.03 MB (0.2%) | 1105.0 MB/s | 6167.9 MB/s | **5.6x** | 1460.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 976.0 MB/s | 934.9 MB/s | **1.0x** | 876.9 MB/s | 836.4 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.7 MB/s | 544.1 MB/s | **1.9x** | 1026.9 MB/s | 1885.8 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 293.6 MB/s | 289.8 MB/s | **1.0x** | 694.9 MB/s | 679.8 MB/s | **1.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 681.8 MB/s | 1840.4 MB/s | **2.7x** | 974.9 MB/s | 5628.8 MB/s | **5.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 693.2 MB/s | 1533.2 MB/s | **2.2x** | 1089.4 MB/s | 4232.3 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 80.5 MB/s | 1296.4 MB/s | **16.1x** | 1000.9 MB/s | 6388.6 MB/s | **6.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 73.5 MB/s | 1234.0 MB/s | **16.8x** | 1062.4 MB/s | 5286.4 MB/s | **5.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1711.6 MB/s | 5036.0 MB/s | **2.9x** | 1759.3 MB/s | 5237.4 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1316.5 MB/s | 5084.9 MB/s | **3.9x** | 1696.1 MB/s | 5120.2 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 781.0 MB/s | 4631.8 MB/s | **5.9x** | 962.7 MB/s | 5440.4 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 783.7 MB/s | 4523.7 MB/s | **5.8x** | 945.1 MB/s | 5956.5 MB/s | **6.3x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 235.7 MB/s | 4890.7 MB/s | **20.8x** | 4435.2 MB/s | 7692.5 MB/s | **1.7x** | 2_SolidBuf_IO_and_CRC32 (93.9%) |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.01 MB (100.0%) | 232.5 MB/s | 227.9 MB/s | **1.0x** | 3447.2 MB/s | 3414.4 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 148.7 MB/s | 4575.2 MB/s | **30.8x** | 1766.8 MB/s | 7602.9 MB/s | **4.3x** | 2_SolidBuf_IO_and_CRC32 (93.2%) |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 148.8 MB/s | 148.1 MB/s | **1.0x** | 1588.2 MB/s | 1581.6 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 92.4 MB/s | 184.1 MB/s | **2.0x** | 3939.1 MB/s | 11334.2 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.6 MB/s | 171.0 MB/s | **2.0x** | 1952.7 MB/s | 2394.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 77.4 MB/s | 152.6 MB/s | **2.0x** | 3959.0 MB/s | 11418.3 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 73.2 MB/s | 146.2 MB/s | **2.0x** | 1923.4 MB/s | 2437.5 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 1.02 MB (1.0%) | 6546.3 MB/s | 6758.5 MB/s | **1.0x** | 7009.5 MB/s | 6981.9 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.02 MB (1.0%) | 6257.8 MB/s | 6756.9 MB/s | **1.1x** | 7438.9 MB/s | 7343.5 MB/s | **1.0x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1044.1 MB/s | 1830.6 MB/s | **1.8x** | 1673.0 MB/s | 5973.7 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1010.7 MB/s | 1826.8 MB/s | **1.8x** | 1665.6 MB/s | 5594.3 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 500.00 MB (100.0%) | 5620.5 MB/s | 5045.4 MB/s | **0.9x** | 5779.5 MB/s | 8306.6 MB/s | **1.4x** | 2_SolidBuf_IO_and_CRC32 (92.5%) |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.11 MB (0.0%) | 5718.7 MB/s | 5550.8 MB/s | **1.0x** | 5456.8 MB/s | 5217.7 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 692.5 MB/s | 4818.3 MB/s | **7.0x** | 3687.8 MB/s | 2140.2 MB/s | **0.6x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 689.1 MB/s | 680.4 MB/s | **1.0x** | 3803.3 MB/s | 3497.7 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1069.6 MB/s | 1898.3 MB/s | **1.8x** | 1821.7 MB/s | 7249.3 MB/s | **4.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1072.0 MB/s | 1881.3 MB/s | **1.8x** | 2140.6 MB/s | 7666.6 MB/s | **3.6x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.6 MB/s | 1285.4 MB/s | **12.9x** | 1824.4 MB/s | 12477.2 MB/s | **6.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 99.6 MB/s | 1290.4 MB/s | **13.0x** | 2194.3 MB/s | 11582.7 MB/s | **5.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15880.6 MB/s | 4774.8 MB/s | **0.3x** | 6069.4 MB/s | 7210.1 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11285.7 MB/s | 4639.4 MB/s | **0.4x** | 6527.4 MB/s | 7111.6 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2195.2 MB/s | 9581.7 MB/s | **4.4x** | 1984.4 MB/s | 3288.6 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2085.6 MB/s | 9803.1 MB/s | **4.7x** | 2006.0 MB/s | 3375.0 MB/s | **1.7x** | - |
