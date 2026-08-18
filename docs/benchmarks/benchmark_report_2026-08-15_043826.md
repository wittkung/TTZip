# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 20:38:26 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 743.2 MB/s | 744.3 MB/s | **1.0x** | 689.9 MB/s | 990.6 MB/s | **1.4x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 735.9 MB/s | 814.4 MB/s | **1.1x** | 511.8 MB/s | 1440.6 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 279.2 MB/s | 395.5 MB/s | **1.4x** | 548.1 MB/s | 1268.4 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 257.5 MB/s | 392.6 MB/s | **1.5x** | 440.9 MB/s | 1184.7 MB/s | **2.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 420.3 MB/s | 1182.8 MB/s | **2.8x** | 559.4 MB/s | 2093.1 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 418.2 MB/s | 885.4 MB/s | **2.1x** | 291.8 MB/s | 1929.3 MB/s | **6.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 361.5 MB/s | 1186.8 MB/s | **3.3x** | 589.4 MB/s | 2152.3 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 351.8 MB/s | 888.6 MB/s | **2.5x** | 295.7 MB/s | 1903.5 MB/s | **6.4x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 277.6 MB/s | 1023.8 MB/s | **3.7x** | 277.5 MB/s | 1082.1 MB/s | **3.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 290.6 MB/s | 1045.7 MB/s | **3.6x** | 290.7 MB/s | 1093.7 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1051.4 MB/s | 2485.9 MB/s | **2.4x** | 1318.6 MB/s | 5266.6 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 905.2 MB/s | 3017.8 MB/s | **3.3x** | 811.3 MB/s | 5304.4 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 297.1 MB/s | 541.0 MB/s | **1.8x** | 944.9 MB/s | 3744.0 MB/s | **4.0x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 292.7 MB/s | 549.8 MB/s | **1.9x** | 663.0 MB/s | 3902.9 MB/s | **5.9x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 650.0 MB/s | 1755.5 MB/s | **2.7x** | 949.8 MB/s | 6213.6 MB/s | **6.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 612.6 MB/s | 1618.1 MB/s | **2.6x** | 956.4 MB/s | 4837.5 MB/s | **5.1x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.8 MB/s | 1239.0 MB/s | **16.1x** | 930.5 MB/s | 7094.4 MB/s | **7.6x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.1 MB/s | 1162.0 MB/s | **15.3x** | 992.1 MB/s | 5144.4 MB/s | **5.2x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1558.2 MB/s | 8408.4 MB/s | **5.4x** | 1584.6 MB/s | 4437.1 MB/s | **2.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1225.0 MB/s | 5812.3 MB/s | **4.7x** | 1526.2 MB/s | 4967.5 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 773.5 MB/s | 5256.7 MB/s | **6.8x** | 944.5 MB/s | 5402.2 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 719.3 MB/s | 4221.4 MB/s | **5.9x** | 865.1 MB/s | 5157.6 MB/s | **6.0x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 206.1 MB/s | 5384.6 MB/s | **26.1x** | 3879.8 MB/s | 6618.8 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 164.3 MB/s | 1288.7 MB/s | **7.8x** | 3036.9 MB/s | 7399.9 MB/s | **2.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 131.8 MB/s | 5416.4 MB/s | **41.1x** | 1600.4 MB/s | 6656.3 MB/s | **4.2x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 135.2 MB/s | 1354.2 MB/s | **10.0x** | 1404.1 MB/s | 7903.1 MB/s | **5.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 62.6 MB/s | 175.9 MB/s | **2.8x** | 2113.6 MB/s | 7730.6 MB/s | **3.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 75.0 MB/s | 163.2 MB/s | **2.2x** | 1001.9 MB/s | 1836.2 MB/s | **1.8x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 55.8 MB/s | 139.9 MB/s | **2.5x** | 2213.3 MB/s | 9704.3 MB/s | **4.4x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 53.8 MB/s | 133.5 MB/s | **2.5x** | 1044.3 MB/s | 2205.9 MB/s | **2.1x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 2162.8 MB/s | 1939.3 MB/s | **0.9x** | 2402.1 MB/s | 2271.9 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 2836.7 MB/s | 2588.3 MB/s | **0.9x** | 1861.1 MB/s | 2487.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 516.9 MB/s | 971.0 MB/s | **1.9x** | 440.8 MB/s | 1899.9 MB/s | **4.3x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 601.3 MB/s | 1052.1 MB/s | **1.7x** | 663.0 MB/s | 3202.4 MB/s | **4.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.09 MB (0.0%) | 3632.8 MB/s | 4226.2 MB/s | **1.2x** | 3060.1 MB/s | 5819.8 MB/s | **1.9x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.09 MB (0.0%) | 4927.8 MB/s | 4149.2 MB/s | **0.8x** | 3575.4 MB/s | 5286.1 MB/s | **1.5x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 597.6 MB/s | 3805.6 MB/s | **6.4x** | 1869.2 MB/s | 8214.2 MB/s | **4.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 585.6 MB/s | 3288.6 MB/s | **5.6x** | 2619.5 MB/s | 2822.2 MB/s | **1.1x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 994.6 MB/s | 1777.2 MB/s | **1.8x** | 686.2 MB/s | 9206.9 MB/s | **13.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 982.4 MB/s | 1806.1 MB/s | **1.8x** | 936.6 MB/s | 4200.6 MB/s | **4.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 90.7 MB/s | 1244.4 MB/s | **13.7x** | 1603.9 MB/s | 6409.7 MB/s | **4.0x** | - |
