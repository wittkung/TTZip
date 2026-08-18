# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-10 09:38:11 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 883.0 MB/s | 288.5 MB/s | **0.3x** | 710.2 MB/s | 608.4 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 834.9 MB/s | 285.8 MB/s | **0.3x** | 525.4 MB/s | 467.2 MB/s | **0.9x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 290.5 MB/s | 280.2 MB/s | **1.0x** | 611.0 MB/s | 627.5 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 288.4 MB/s | 284.6 MB/s | **1.0x** | 481.7 MB/s | 471.7 MB/s | **1.0x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 408.4 MB/s | 5895.6 MB/s | **14.4x** | 609.7 MB/s | 2054.5 MB/s | **3.4x** |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 376.2 MB/s | 2092.8 MB/s | **5.6x** | 288.6 MB/s | 1895.0 MB/s | **6.6x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 337.6 MB/s | 5397.2 MB/s | **16.0x** | 589.2 MB/s | 2153.6 MB/s | **3.7x** |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 319.6 MB/s | 2231.8 MB/s | **7.0x** | 295.6 MB/s | 2029.8 MB/s | **6.9x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.07 MB (0.6%) | 281.5 MB/s | 229.6 MB/s | **0.8x** | 253.6 MB/s | 270.2 MB/s | **1.1x** |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.07 MB (0.6%) | 296.8 MB/s | 220.1 MB/s | **0.7x** | 250.6 MB/s | 315.2 MB/s | **1.3x** |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 996.8 MB/s | 282.7 MB/s | **0.3x** | 1222.2 MB/s | 857.5 MB/s | **0.7x** |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 777.2 MB/s | 283.0 MB/s | **0.4x** | 691.6 MB/s | 565.5 MB/s | **0.8x** |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 291.7 MB/s | 285.5 MB/s | **1.0x** | 892.8 MB/s | 876.2 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 286.0 MB/s | 282.8 MB/s | **1.0x** | 578.3 MB/s | 567.7 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 653.4 MB/s | 1650.1 MB/s | **2.5x** | 923.8 MB/s | 5378.9 MB/s | **5.8x** |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.4%) | 626.6 MB/s | 1471.8 MB/s | **2.3x** | 970.4 MB/s | 4451.5 MB/s | **4.6x** |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 82.9 MB/s | 1184.9 MB/s | **14.3x** | 863.5 MB/s | 6900.2 MB/s | **8.0x** |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 81.7 MB/s | 1112.3 MB/s | **13.6x** | 910.1 MB/s | 4695.1 MB/s | **5.2x** |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1443.7 MB/s | 985.3 MB/s | **0.7x** | 1493.1 MB/s | 1305.5 MB/s | **0.9x** |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1082.7 MB/s | 844.2 MB/s | **0.8x** | 1286.5 MB/s | 1334.0 MB/s | **1.0x** |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.7%) | 0.03 MB (0.3%) | 721.3 MB/s | 469.6 MB/s | **0.7x** | 860.2 MB/s | 1950.7 MB/s | **2.3x** |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.03 MB (0.4%) | 0.03 MB (0.3%) | 691.5 MB/s | 466.6 MB/s | **0.7x** | 822.6 MB/s | 2146.9 MB/s | **2.6x** |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 210.5 MB/s | 177.1 MB/s | **0.8x** | 3921.5 MB/s | 1560.6 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 1.02 MB (1.0%) | 211.5 MB/s | 182.1 MB/s | **0.9x** | 3171.0 MB/s | 1415.1 MB/s | **0.4x** |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 139.3 MB/s | 181.7 MB/s | **1.3x** | 1604.4 MB/s | 1607.7 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 1.02 MB (1.0%) | 138.7 MB/s | 183.5 MB/s | **1.3x** | 1457.2 MB/s | 1459.7 MB/s | **1.0x** |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 87.5 MB/s | 197.0 MB/s | **2.3x** | 3509.9 MB/s | 7606.9 MB/s | **2.2x** |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 81.7 MB/s | 181.7 MB/s | **2.2x** | 1711.8 MB/s | 2198.2 MB/s | **1.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.3 MB/s | 154.5 MB/s | **2.1x** | 3488.0 MB/s | 8070.6 MB/s | **2.3x** |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 69.4 MB/s | 146.4 MB/s | **2.1x** | 1716.0 MB/s | 2131.7 MB/s | **1.2x** |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5565.8 MB/s | 1291.1 MB/s | **0.2x** | 6767.8 MB/s | 1724.3 MB/s | **0.3x** |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 1.01 MB (1.0%) | 5699.1 MB/s | 1406.5 MB/s | **0.2x** | 7084.1 MB/s | 4311.0 MB/s | **0.6x** |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 937.7 MB/s | 77.4 MB/s | **0.1x** | 1455.8 MB/s | 4112.3 MB/s | **2.8x** |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.03 MB (100.0%) | 904.0 MB/s | 77.4 MB/s | **0.1x** | 1579.7 MB/s | 3991.5 MB/s | **2.5x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5220.9 MB/s | 650.8 MB/s | **0.1x** | 5450.6 MB/s | 3449.2 MB/s | **0.6x** |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.07 MB (0.0%) | 5253.5 MB/s | 656.7 MB/s | **0.1x** | 5320.7 MB/s | 3578.6 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 662.3 MB/s | 651.5 MB/s | **1.0x** | 3552.0 MB/s | 3557.1 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.07 MB (0.0%) | 652.3 MB/s | 584.8 MB/s | **0.9x** | 3347.5 MB/s | 2458.7 MB/s | **0.7x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1020.0 MB/s | 1635.1 MB/s | **1.6x** | 1736.4 MB/s | 6260.0 MB/s | **3.6x** |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1003.3 MB/s | 1621.4 MB/s | **1.6x** | 1897.2 MB/s | 6597.6 MB/s | **3.5x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.6 MB/s | 1147.2 MB/s | **12.3x** | 1662.9 MB/s | 10204.5 MB/s | **6.1x** |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 93.1 MB/s | 1078.3 MB/s | **11.6x** | 1959.2 MB/s | 10427.1 MB/s | **5.3x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 13342.2 MB/s | 1750.0 MB/s | **0.1x** | 5394.7 MB/s | 5268.0 MB/s | **1.0x** |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 7690.9 MB/s | 1148.1 MB/s | **0.1x** | 4955.1 MB/s | 4523.1 MB/s | **0.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.49 MB (0.1%) | 1614.2 MB/s | 548.3 MB/s | **0.3x** | 1473.4 MB/s | 2828.8 MB/s | **1.9x** |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.49 MB (0.1%) | 1777.5 MB/s | 568.1 MB/s | **0.3x** | 1695.2 MB/s | 3341.1 MB/s | **2.0x** |
