# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 22:02:33 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 851.5 MB/s | 1479.9 MB/s | **1.7x** | 709.0 MB/s | 1461.8 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 854.4 MB/s | 1646.7 MB/s | **1.9x** | 531.4 MB/s | 1464.8 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 286.7 MB/s | 569.2 MB/s | **2.0x** | 594.0 MB/s | 1372.4 MB/s | **2.3x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 287.6 MB/s | 609.9 MB/s | **2.1x** | 473.0 MB/s | 1341.3 MB/s | **2.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 443.7 MB/s | 1197.0 MB/s | **2.7x** | 576.0 MB/s | 1903.1 MB/s | **3.3x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 408.6 MB/s | 913.3 MB/s | **2.2x** | 293.9 MB/s | 1907.2 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 368.7 MB/s | 1204.0 MB/s | **3.3x** | 573.6 MB/s | 2180.4 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 341.0 MB/s | 922.6 MB/s | **2.7x** | 291.6 MB/s | 1900.5 MB/s | **6.5x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 267.0 MB/s | 973.0 MB/s | **3.6x** | 266.3 MB/s | 1020.5 MB/s | **3.8x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 279.0 MB/s | 1094.6 MB/s | **3.9x** | 280.8 MB/s | 1020.0 MB/s | **3.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1016.7 MB/s | 1849.8 MB/s | **1.8x** | 1370.1 MB/s | 4711.4 MB/s | **3.4x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 932.3 MB/s | 1794.9 MB/s | **1.9x** | 830.1 MB/s | 4647.2 MB/s | **5.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 284.6 MB/s | 567.5 MB/s | **2.0x** | 965.4 MB/s | 3684.7 MB/s | **3.8x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 281.1 MB/s | 564.4 MB/s | **2.0x** | 663.4 MB/s | 3786.9 MB/s | **5.7x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 655.4 MB/s | 1770.9 MB/s | **2.7x** | 941.1 MB/s | 5815.9 MB/s | **6.2x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 624.7 MB/s | 1617.1 MB/s | **2.6x** | 1020.8 MB/s | 4634.4 MB/s | **4.5x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 76.9 MB/s | 1244.6 MB/s | **16.2x** | 938.4 MB/s | 6403.1 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 77.8 MB/s | 1180.9 MB/s | **15.2x** | 1000.9 MB/s | 4822.5 MB/s | **4.8x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1550.1 MB/s | 8761.4 MB/s | **5.7x** | 1635.5 MB/s | 4909.8 MB/s | **3.0x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1253.6 MB/s | 6207.2 MB/s | **5.0x** | 1544.8 MB/s | 5063.5 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 748.0 MB/s | 5190.3 MB/s | **6.9x** | 901.8 MB/s | 5507.5 MB/s | **6.1x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 788.3 MB/s | 5344.8 MB/s | **6.8x** | 930.5 MB/s | 5170.7 MB/s | **5.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 215.0 MB/s | 5590.7 MB/s | **26.0x** | 3932.3 MB/s | 6738.3 MB/s | **1.7x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 206.9 MB/s | 1401.1 MB/s | **6.8x** | 3259.1 MB/s | 7992.1 MB/s | **2.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 142.2 MB/s | 5614.8 MB/s | **39.5x** | 1681.4 MB/s | 6856.6 MB/s | **4.1x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 139.6 MB/s | 1404.8 MB/s | **10.1x** | 1412.6 MB/s | 8047.6 MB/s | **5.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 85.7 MB/s | 188.6 MB/s | **2.2x** | 3719.9 MB/s | 9799.2 MB/s | **2.6x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 80.5 MB/s | 177.6 MB/s | **2.2x** | 1812.3 MB/s | 2343.9 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 74.6 MB/s | 147.8 MB/s | **2.0x** | 3708.5 MB/s | 10072.9 MB/s | **2.7x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.5 MB/s | 141.1 MB/s | **2.0x** | 1808.7 MB/s | 2341.3 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5676.2 MB/s | 5262.7 MB/s | **0.9x** | 6912.9 MB/s | 4340.2 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 5887.7 MB/s | 5320.9 MB/s | **0.9x** | 7089.8 MB/s | 4279.8 MB/s | **0.6x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 1008.8 MB/s | 1785.7 MB/s | **1.8x** | 1649.7 MB/s | 4681.5 MB/s | **2.8x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 973.9 MB/s | 1787.7 MB/s | **1.8x** | 1626.4 MB/s | 5034.1 MB/s | **3.1x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5254.7 MB/s | 5361.8 MB/s | **1.0x** | 5475.7 MB/s | 9104.8 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.08 MB (0.0%) | 5138.3 MB/s | 5396.2 MB/s | **1.1x** | 5090.7 MB/s | 9078.8 MB/s | **1.8x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 663.0 MB/s | 4968.5 MB/s | **7.5x** | 3648.2 MB/s | 8883.5 MB/s | **2.4x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 672.5 MB/s | 4916.9 MB/s | **7.3x** | 3504.1 MB/s | 8890.8 MB/s | **2.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1022.6 MB/s | 1854.8 MB/s | **1.8x** | 1747.6 MB/s | 10150.4 MB/s | **5.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 1017.0 MB/s | 1842.1 MB/s | **1.8x** | 2075.4 MB/s | 10426.2 MB/s | **5.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.7 MB/s | 1253.7 MB/s | **13.1x** | 1746.9 MB/s | 12069.9 MB/s | **6.9x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 95.7 MB/s | 1259.2 MB/s | **13.2x** | 2065.6 MB/s | 11738.1 MB/s | **5.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 14881.4 MB/s | 20807.8 MB/s | **1.4x** | 5528.3 MB/s | 5184.3 MB/s | **0.9x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 10380.9 MB/s | 22099.8 MB/s | **2.1x** | 6253.1 MB/s | 6056.0 MB/s | **1.0x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2254.7 MB/s | 10436.7 MB/s | **4.6x** | 1942.8 MB/s | 3190.7 MB/s | **1.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 2044.4 MB/s | 10252.6 MB/s | **5.0x** | 2028.0 MB/s | 3241.5 MB/s | **1.6x** | - |
