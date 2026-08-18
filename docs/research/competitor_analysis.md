# TTZip vs. 7-Zip / Bandizip / WinRAR 深度技术与功能对比调研报告

本文档立足于 CTO 研发视角，深度剖析行业标杆解压缩软件（7-Zip、Bandizip、WinRAR）在底层算法、操作系统融合、格式独占性与工具链生态上的优势，客观梳理 TTZip 当前的差距与未来演进策略。

---

## 一、 标杆软件的核心优势与差距剖析

### 1. 7-Zip 的核心优势与 TTZip 的差距

| 优势维度 | 7-Zip 标杆技术实现 | TTZip 当前状态 | 差距与影响分析 |
| :--- | :--- | :--- | :--- |
| **7Z 固实压缩比 (Solid Archiving)** | 7-Zip 作为 `.7z` 格式原作者，其 **LZMA2 固实压缩**能将数万个同类文本/代码文件合并为单一连续数据流，压缩率比常规 Zip 高 **20%~40%**。 | 依赖 `libarchive` 进行常规多格式流式打解压，尚未接入 LZMA2 固实算法（Solid Block）。 | 处理海量小文件/代码库时，纯压缩率略低于 7-Zip。 |
| **可执行文件预过滤器 (BCJ/BCJ2)** | 内置 x86/ARM/PPC 二进制可执行文件地址预转换过滤器 (BCJ)，在压缩前平滑跳转指令地址，大幅提升二进制文件压缩率。 | 采用标准通用压缩流，未加入二进制跳转地址变换过滤器。 | 压缩可执行二进制应用（如 `.app` 或二进制 Bin）时压缩比有提升空间。 |
| **极简零依赖与微型体积** | 纯 C/C++ 汇编精简编写，无第三方库依赖，编译产物体积小于 1.5MB。 | 基于 Swift 6 + C-FFI (libarchive + uchardet)，运行依赖 Apple 运行时。 | 体积略大于 7-Zip，但换取了现代化 SwiftUI 界面与 Swift 6 线程安全。 |

---

### 2. Bandizip 的核心优势与 TTZip 的差距

| 优势维度 | Bandizip 标杆技术实现 | TTZip 当前状态 | 差距与影响分析 |
| :--- | :--- | :--- | :--- |
| **操作系统 Shell 级深度融合** | 深度开发 Windows Explorer 右键扩展 DLL，支持右键直接图片缩略图预览、无需打开窗口的快捷解压/打包。 | 提供了原生的 SwiftUI 拖拽 DropZone 工作区与 QuickLook 预览，但尚未打包 macOS `FinderSync` 右键扩展。 | 用户在 macOS 访达中右键点击文件时，尚需打开 TTZip 主界面进行操作。 |
| **无解压增量编辑与文档感知** | 双击压缩包内 Office (Word/Excel) 或文本文件可直接编辑，关闭编辑器后自动感知文件变更并增量刷回压缩包。 | 支持解压后编辑，暂未支持双击内部文档后修改自动增量写回 Zip 包。 | 频繁修改压缩包内小文档的办公体验存在微小差距。 |
| **高并发多核密码破解引擎** | 专业版内置基于 SIMD 指令调优的密码恢复工具，ZIP Deflate 破解速度达 **每秒 3 亿次口令尝试**。 | 提供了 AES-256 口令加密与密码库管理，但未内置多核字典/暴力密码恢复工具。 | 对于遗忘口令的坏包无法进行自动化字典破解。 |

---

### 3. WinRAR 的核心优势与 TTZip 的差距

| 优势维度 | WinRAR 标杆技术实现 | TTZip 当前状态 | 差距与影响分析 |
| :--- | :--- | :--- | :--- |
| **独占 RAR/RAR5 写入与纠错码 (RR)** | 拥有 `.rar/.rar5` 格式完全写权限，并在归档包中注入 Reed-Solomon 恢复记录 (Recovery Record)，坏道损坏可物理自愈。 | 拥有 RAR/RAR5 格式的**完全解压与读取权限**，但受商业专利限制无法写入 `.rar`。 | 无法创建原生 `.rar` 格式（行业普遍采用 ZIP / 7Z 替代）。 |

---

## 二、 TTZip 的差异化独家优势 (Our Unique Edge)

虽然传统软件在特定历史积淀领域拥有壁垒，但 TTZip 在现代化计算架构与特定体验上建立了独特的竞争优势：

1. **Apple Silicon (M1~M5) 硬件拓扑极速适配**：
   * 独家开发 `AppleSiliconTuner`，自动感知 M5 Max 18 核心拓扑（12 P-Cores + 6 E-Cores），配合 `posix_memalign` 16KB 物理页内存对齐与 4MB 页缓冲区，在 Mac 平台吞吐吞吐大幅超越运行在 Rosetta 2 模拟器下的传统 x86 压缩工具。
2. **独家常用压缩预设系统 (`PresetManager`)**：
   * 率先解决用户繁琐配置痛点，原生支持 **“7z 20G 仅存储分卷 + 固定解压口令”** 一键快捷套用与持久化方案。
3. **现代 SwiftUI 玻璃拟态 UX 与无损 QuickLook 预览**：
   * 界面远胜 7-Zip 的 1990 年代风格，支持在不解压的情况下按 `Space` 键调起 macOS QuickLook 原生预览。
4. **Swift 6 严格并发与防 Zip Slip 清洗**：
   * 全架构通过 `Sendable` 与 `@MainActor` 隔离，内建内存级 AMSI 恶意扩展名扫描与绝对路径逃逸清洗，安全性远超经典共享软件。

---

## 三、 TTZip 追赶与超越的 Strategic Roadmap

为了全面赶超 7-Zip 与 Bandizip，规划以下 3 个阶段的演进路线：

1. **Phase 1: macOS 访达右键扩展 (`FinderSync Extension`)**：
   - 增加 `FinderSync` Target，实现在 Finder 右键菜单中直接显示“压缩为 TTZip 包”、“解压至当前文件夹”与缩略图预览。
2. **Phase 2: 接入 7-Zip C++ 原生 LZMA2 固实算法库 (Solid Block)**：
   - 引入 7-Zip SDK 源码编译，补充 `.7z` 固实打包能力，将代码库与文本库压缩率提升 30%。
3. **Phase 3: 文件修改感知与无解压增量写回 (File Watcher)**：
   - 使用 macOS `FSEvents` 或 `DispatchSourceFileSystemObject` 监听临时编辑文件的保存动作，自动将修改后的文件增量刷回压缩包。
