# TTZip 完整研发路线图与功能规划 (DEVELOPMENT_PLAN.md)

本文档规划 TTZip 从立项、底层 POC 验证、SwiftUI 客户端开发、Finder 扩展到 Release 发布的完整路线图。

---

## 阶段一：基础架构与底层 C 驱动 (Current Stage - Milestone 1)

* [x] **项目物理立项**：创建 `/Users/kevintung/Documents/dev/TTZip` 目录，配置 `.gitignore`、`README.md` 与 Git 仓库初始化。
* [x] **C 语言扩展库依赖调研**：完成 Homebrew `libarchive`、`zstd` 与 `uchardet` 的依赖检测与编译库对齐。
* [ ] **C 语言适配层 (`CTTZipBridge`) 编写**：完成 `archive.h` 与 `uchardet.h` 的头文件桥接封装。
* [ ] **`TTZipCore` 核心 Swift 模块开发**：
  * 实现 `ArchiveReader` 类：支持流式读取 Zip/7z/Tar 归档文件列表。
  * 实现 `CharsetDetector` 类：封装 C 语言 `uchardet` 侦测接口，输出标准 Swift `String.Encoding`。
* [ ] **CLI 命令行测试工具 (`ttzip-cli`) 编写**：验证 CLI 下读取与显示归档文件列表、乱码转码效果。

---

## 阶段二：SwiftUI 原生客户端 UI 开发 (Milestone 2)

* [ ] **现代美学 UI 框架搭建**：
  * SwiftUI Window 容器（支持 macOS 玻璃拟态 Glassmorphism 材质效果）。
  * 归档文件树状卡片视图 (`ArchiveItemTreeView`)，支持文件类型图标自动匹配。
* [ ] **拖拽与交互能力**：
  * 支持拖拽任意 Zip/7z/RAR 文件至窗口或 App Dock 图标直接打开。
  * 支持从归档树中拖拽单文件至 Desktop / Finder 进行解压。
* [ ] **解压进度与状态面板**：
  * 多任务进度列表面板（显示实时 MB/s 吞吐速率、已完成百分比与剩余时间计算）。
  * 密码输入与 Keychain 自动匹配弹窗。

---

## 阶段三： QuickLook 与 Finder 系统集成 (Milestone 3)

* [ ] **Finder Sync Extension**：
  * Finder 右键快捷菜单：“用 TTZip 解压到当前文件夹”、“压缩为 ZIP / 7Z”。
  * 智能解压模式（单个文件解压时自动建立同名文件夹，多文件自动散落当前目录）。
* [ ] **QuickLook 归档预览插件 (`PreviewProvider`)**：
  * 在 Finder 中选中 `.zip` / `.7z` / `.tar.gz` 移动按下 `Space` 键，无需启动主 App 即可弹出归档内部文件列表预览。

---

## 阶段四：性能极限调优与 Release 发布 (Milestone 4)

* [ ] **M 系列芯片多核并行压缩调优**：测试 `zstd` 多线程压缩上限，确保压满多核心算力。
* [ ] **编码回归测试**：导入 Windows GBK / Big5 / EUC-KR 多国乱码样本包，进行 100% 自动还原测试。
* [ ] **打包与发布**：签名、Notarize (苹果公证) 并发布 `.dmg` / GitHub Release。
