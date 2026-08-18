# TTZip vs 竞品全维度性能对比测试报告 (Exhaustive Competitor Benchmark Report)

> **测试时间**: 2026-08-14 18:54:45 +0000
> **测试环境**: Apple Silicon (18 核 [P:6 / E:12]) | macOS 版本26.6（版号25G72）
> **竞品包含**: Apple ditto (Native macOS), 7-Zip 7zz CLI (ARM64), System tar, Zstandard zstd CLI, Parallel pigz, Info-ZIP, pbzip2, pixz, plzip, lz4, brotli, lrzip, aa, snappy, wimlib-imagex, hdiutil
> **基准策略**: 竞品工具全开硬件与并发极限 (`-mmt=on`, `-T0`, `-p max`, `-n max`)，TTZip 走 16MB mmap / NEON SIMD / C 原生架构

| 数据集维度 | 归档格式 | 压缩等级 | 加密 | 竞品工具 | 竞品压缩体积 (压缩率) | TTZip 压缩体积 (压缩率) | 竞品打包吞吐 | TTZip 打包吞吐 | 打包领先 | 竞品解压吞吐 | TTZip 解压吞吐 | 解压领先 | AOP 核心瓶颈阶段 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 海量小文件 (10MB/100文件) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 764.0 MB/s | 852.5 MB/s | **1.1x** | 607.5 MB/s | 1255.5 MB/s | **2.1x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 757.2 MB/s | 757.9 MB/s | **1.0x** | 486.6 MB/s | 742.6 MB/s | **1.5x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 279.5 MB/s | 367.9 MB/s | **1.3x** | 568.6 MB/s | 1064.5 MB/s | **1.9x** | - |
| 海量小文件 (10MB/100文件) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.01 MB (0.1%) | 276.0 MB/s | 367.8 MB/s | **1.3x** | 429.7 MB/s | 673.1 MB/s | **1.6x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 388.7 MB/s | 922.3 MB/s | **2.4x** | 540.2 MB/s | 1588.5 MB/s | **2.9x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 394.3 MB/s | 818.3 MB/s | **2.1x** | 276.3 MB/s | 1613.8 MB/s | **5.8x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.05 MB (0.5%) | 323.0 MB/s | 1115.3 MB/s | **3.5x** | 533.2 MB/s | 1889.3 MB/s | **3.5x** | - |
| 海量小文件 (10MB/100文件) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.06 MB (0.5%) | 0.06 MB (0.5%) | 309.1 MB/s | 763.2 MB/s | **2.5x** | 279.8 MB/s | 1642.3 MB/s | **5.9x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.12 MB (1.0%) | 0.04 MB (0.4%) | 233.7 MB/s | 896.4 MB/s | **3.8x** | 243.1 MB/s | 897.9 MB/s | **3.7x** | - |
| 海量小文件 (10MB/100文件) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.07 MB (0.6%) | 0.04 MB (0.4%) | 234.3 MB/s | 944.3 MB/s | **4.0x** | 185.6 MB/s | 847.5 MB/s | **4.6x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 970.5 MB/s | 2504.6 MB/s | **2.6x** | 1268.8 MB/s | 5211.2 MB/s | **4.1x** | - |
| 拟真日志文本 (10MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 881.4 MB/s | 1537.7 MB/s | **1.7x** | 770.4 MB/s | 1305.5 MB/s | **1.7x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 277.8 MB/s | 472.0 MB/s | **1.7x** | 890.2 MB/s | 3479.3 MB/s | **3.9x** | - |
| 拟真日志文本 (10MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 275.4 MB/s | 481.6 MB/s | **1.7x** | 605.1 MB/s | 1111.7 MB/s | **1.8x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 609.9 MB/s | 1486.8 MB/s | **2.4x** | 850.0 MB/s | 4616.1 MB/s | **5.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 610.7 MB/s | 1448.5 MB/s | **2.4x** | 889.1 MB/s | 3952.5 MB/s | **4.4x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 72.9 MB/s | 1155.1 MB/s | **15.8x** | 851.9 MB/s | 5133.7 MB/s | **6.0x** | - |
| 拟真日志文本 (10MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.04 MB (0.4%) | 0.04 MB (0.3%) | 74.4 MB/s | 1064.5 MB/s | **14.3x** | 937.9 MB/s | 4064.7 MB/s | **4.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1431.1 MB/s | 6576.9 MB/s | **4.6x** | 1367.0 MB/s | 4537.1 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.00 MB (0.0%) | 0.00 MB (0.0%) | 1174.8 MB/s | 3485.2 MB/s | **3.0x** | 1353.7 MB/s | 4462.5 MB/s | **3.3x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 0.08 MB (0.7%) | 0.04 MB (0.4%) | 709.9 MB/s | 4199.9 MB/s | **5.9x** | 714.7 MB/s | 4887.4 MB/s | **6.8x** | - |
| 拟真日志文本 (10MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.04 MB (0.4%) | 0.04 MB (0.4%) | 720.7 MB/s | 4285.4 MB/s | **5.9x** | 778.7 MB/s | 4229.6 MB/s | **5.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 157.0 MB/s | 3785.6 MB/s | **24.1x** | 3783.0 MB/s | 5795.0 MB/s | **1.5x** | - |
| 高熵物理Payload (100MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 100.01 MB (100.0%) | 100.00 MB (100.0%) | 126.2 MB/s | 1168.2 MB/s | **9.3x** | 3085.0 MB/s | 4302.7 MB/s | **1.4x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 129.4 MB/s | 4952.6 MB/s | **38.3x** | 1448.5 MB/s | 5243.7 MB/s | **3.6x** | - |
| 高熵物理Payload (100MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 1.02 MB (1.0%) | 100.00 MB (100.0%) | 127.3 MB/s | 1217.8 MB/s | **9.6x** | 1395.6 MB/s | 4927.4 MB/s | **3.5x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 86.5 MB/s | 180.7 MB/s | **2.1x** | 3329.5 MB/s | 9520.8 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 72.4 MB/s | 161.7 MB/s | **2.2x** | 1614.0 MB/s | 1922.9 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 70.2 MB/s | 138.8 MB/s | **2.0x** | 3092.7 MB/s | 8959.4 MB/s | **2.9x** | - |
| 高熵物理Payload (100MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 64.9 MB/s | 132.0 MB/s | **2.0x** | 1681.4 MB/s | 2127.0 MB/s | **1.3x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 100.00 MB (100.0%) | 100.00 MB (100.0%) | 5107.3 MB/s | 4430.0 MB/s | **0.9x** | 6086.0 MB/s | 5204.1 MB/s | **0.9x** | - |
| 高熵物理Payload (100MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 10.01 MB (10.0%) | 100.00 MB (100.0%) | 4384.5 MB/s | 4643.3 MB/s | **1.1x** | 4783.8 MB/s | 5526.7 MB/s | **1.2x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 692.4 MB/s | 1272.0 MB/s | **1.8x** | 1358.9 MB/s | 4569.0 MB/s | **3.4x** | - |
| 高熵物理Payload (100MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 100.03 MB (100.0%) | 100.01 MB (100.0%) | 776.4 MB/s | 1422.2 MB/s | **1.8x** | 1542.6 MB/s | 4112.1 MB/s | **2.7x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | 无 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5161.2 MB/s | 18417.6 MB/s | **3.6x** | 5146.7 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 1 | AES-256 | 7-Zip 7zz CLI | 0.11 MB (0.0%) | 0.10 MB (0.0%) | 5117.3 MB/s | 20115.5 MB/s | **3.9x** | 4843.9 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | 无 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 635.7 MB/s | 17764.9 MB/s | **27.9x** | 3233.2 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | 7Z | 6 | AES-256 | 7-Zip 7zz CLI | 0.07 MB (0.0%) | 0.08 MB (0.0%) | 637.6 MB/s | 18273.9 MB/s | **28.7x** | 3234.1 MB/s | 0.0 MB/s | **0.0x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 827.9 MB/s | 1799.2 MB/s | **2.2x** | 1689.6 MB/s | 6355.9 MB/s | **3.8x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 1 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.58 MB (0.1%) | 989.0 MB/s | 1761.6 MB/s | **1.8x** | 1912.3 MB/s | 6567.4 MB/s | **3.4x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | 无 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 92.7 MB/s | 1249.5 MB/s | **13.5x** | 1738.1 MB/s | 11241.9 MB/s | **6.5x** | - |
| 500MB 大文件数据块 (500MB) | ZIP | 6 | AES-256 | 7-Zip 7zz (Max Multithread) | 0.59 MB (0.1%) | 0.51 MB (0.1%) | 94.9 MB/s | 1260.3 MB/s | **13.3x** | 1967.4 MB/s | 11073.4 MB/s | **5.6x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 1 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 15303.5 MB/s | 13945.0 MB/s | **0.9x** | 6126.6 MB/s | 7464.7 MB/s | **1.2x** | - |
| 500MB 大文件数据块 (500MB) | TAR.ZST | 6 | 无 | Zstandard zstd (Thread=0) | 0.02 MB (0.0%) | 0.02 MB (0.0%) | 11504.0 MB/s | 15979.3 MB/s | **1.4x** | 6440.6 MB/s | 8430.5 MB/s | **1.3x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 1 | 无 | Parallel pigz (All Cores) | 2.25 MB (0.5%) | 0.52 MB (0.1%) | 2057.0 MB/s | 9860.3 MB/s | **4.8x** | 1761.9 MB/s | 3069.4 MB/s | **1.7x** | - |
| 500MB 大文件数据块 (500MB) | TAR.GZ | 6 | 无 | Parallel pigz (All Cores) | 0.55 MB (0.1%) | 0.52 MB (0.1%) | 1871.5 MB/s | 10882.4 MB/s | **5.8x** | 1826.7 MB/s | 2799.5 MB/s | **1.5x** | - |
