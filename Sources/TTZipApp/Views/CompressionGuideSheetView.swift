import SwiftUI
import TTZipCore

/// 压缩算法、封装格式与高级参数百科指南 View
public struct CompressionGuideSheetView: View {
    @Binding var isPresented: Bool
    @State private var selectedTab = 0
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏 Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages.fill")
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        Text("COMPRESSION ENCYCLOPEDIA")
                            .font(.system(size: 9, weight: .bold, design: .serif))
                            .tracking(2)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                    }
                    Text("压缩算法、格式与高级配置指南")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.025))
            
            Divider()
            
            // Tab 切换按钮组
            HStack(spacing: 6) {
                tabButton(title: "📦 封装格式", index: 0)
                tabButton(title: "⚡ 压缩算法", index: 1)
                tabButton(title: "🎛 高级参数", index: 2)
                tabButton(title: "🔒 加密与分卷", index: 3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.015))
            
            Divider()
            
            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0: formatsGuideSection
                    case 1: algorithmsGuideSection
                    case 2: advancedParamsSection
                    case 3: securityAndSplitSection
                    default: EmptyView()
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // 底部 Close 按钮栏
            HStack {
                Text("TTZip 官方算法白皮书 & HIG 视觉指南")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("了解并关闭") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(TTZipTheme.bambooGreen)
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 660, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        return Button(action: { selectedTab = index }) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? TTZipTheme.bambooGreen : Color.primary.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 1. 封装格式百科
    private var formatsGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "archivebox.fill",
                title: ".7z (7-Zip 高压缩格式)",
                badge: "高压缩比首选",
                content: "由 Igor Pavlov 开发的开放架构格式。支持 LZMA2 高并发算法、固实归档 (Solid Archive)、文件名头部加密 (-mhe=on) 以及高达 512MB 的词典空间。适合存放软件源码、大容量文档与对压缩率有极高要求的场景。"
            )
            
            guideCard(
                icon: "doc.zipper",
                title: ".zip (ZIP 跨平台通用规范)",
                badge: "全球兼容性最强",
                content: "历史最悠久、兼容性最好的归档格式。几乎内置于所有 macOS、Windows、Linux、iOS 和 Android 系统中。支持 Deflate 算法与现代 AES-256 加密，开启 UTF-8 (-mcu=on) 标记可彻底消除 Windows 繁/简中文环境解压乱码。"
            )
            
            guideCard(
                icon: "bolt.horizontal.fill",
                title: ".tar.zst / .zst (Zstandard 极速归档)",
                badge: "并发吞吐极速",
                content: "由 Meta (Facebook) 开发的下一代高吞吐算法。配合 POSIX 打包，拥有极其惊人的解压与压缩吞吐率（吞吐量可达 600~900 MB/s），特别适合大型数据集、游戏资源包与极速备份场景。"
            )
            
            guideCard(
                icon: "terminal.fill",
                title: ".tar.gz / .tar.bz2 / .tar.xz (Unix 打包流)",
                badge: "POSIX 标准",
                content: "Linux / macOS 系统标准的“归档打包 + 压缩流”组合。先将多个文件保持 UNIX 文件权限与时间戳合并为 TAR 包，再通过 Gzip、Bzip2 或 XZ 流进行二段压缩。"
            )
        }
    }
    
    // MARK: - 2. 压缩算法详解
    private var algorithmsGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "cpu",
                title: "LZMA2 (最高压缩比，多核并发)",
                badge: "7z 默认引擎",
                content: "改进版 LZMA 算法。完美解决了多核 CPU 并发压缩瓶颈，支持高达 512MB 的字典大小，在绝大多数文档、可执行文件与项目代码上拥有业界顶级的压缩率。"
            )
            
            guideCard(
                icon: "doc.text.fill",
                title: "PPMd (纯文本 / 代码极高压缩比)",
                badge: "文本与电子书神技",
                content: "基于 Dmitry Shkarin 开发的局部预测 Markov 链算法。专门针对无损纯文本、HTML/JSON、电子书 (EPUB/TXT) 与项目源码提供远超 LZMA 的极致压缩效果。"
            )
            
            guideCard(
                icon: "square.stack.3d.down.right.fill",
                title: "Deflate / Deflate64 (最通用算法)",
                badge: "ZIP / GZIP 核心",
                content: "结合 LZ77 匹配与 Huffman 编码的经典算法。虽然压缩比略逊于 LZMA2，但拥有天花板级别的硬件解压速度与全平台开箱即用兼容性。"
            )
            
            guideCard(
                icon: "bolt.fill",
                title: "Zstd / Zstandard (极速并发，吞吐极高)",
                badge: "现代高性能",
                content: "采用 FSE (Finite State Entropy) 熵编码。在接近 Deflate 甚至超越 Deflate 压缩率的同时，提供 3~5 倍以上的超高速解压吞吐。"
            )
            
            guideCard(
                icon: "shippingbox.fill",
                title: "Copy / Store (仅打包不压缩，0 延迟)",
                badge: "视频/音视频推荐",
                content: "完全跳过计算密集型的压缩匹配，仅将文件顺序组装为归档包。适合已压缩的 MP4 视频、JPG 图片、MP3 音频与安装包，避免无意义的 CPU 浪费。"
            )
        }
    }
    
    // MARK: - 3. 高级配置参数
    private var advancedParamsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "memorychip",
                title: "词典大小 (Dictionary Size)",
                badge: "匹配滑窗内存",
                content: "算法在内存中用于搜寻重复数据的“记忆滑窗”。字典越大（如 64MB、128MB），越能跨越很远的重复段落进行压缩，显著减小体积；但压缩和解压时会占用对应的 RAM 内存。"
            )
            
            guideCard(
                icon: "cube.transparent.fill",
                title: "固实压缩包 (Solid Archive)",
                badge: "7z 核心特性",
                content: "将压缩包内的多个文件连结为一个整体数据流进行统一字典匹配。优势：包含大量同类小文件或代码文件时压缩率提升 20%~50%；注意：单独解压包内部某个末尾文件时需要解译前面的流。"
            )
            
            guideCard(
                icon: "arrow.triangle.2.circlepath",
                title: "LDM 长距离匹配 (--long=27)",
                badge: "Zstd 专有技术",
                content: "Zstandard 的 Long Distance Matching 技术。扩展窗口至 128MB 以上，专门抓取跨大文件间的相同数据块（如不同日志或重复副本），极大地提升压缩效率。"
            )
        }
    }
    
    // MARK: - 4. 加密与分卷
    private var securityAndSplitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            guideCard(
                icon: "lock.shield.fill",
                title: "AES-256 加密 vs ZipCrypto",
                badge: "高强度防破解",
                content: "AES-256 采用工业级 256 位对称密钥加密，无法通过传统暴力字典破译；ZipCrypto 是 90 年代的旧式加密算法，虽然老系统兼容性好但安全性较低。"
            )
            
            guideCard(
                icon: "eye.slash.fill",
                title: "加密文件名 (Header Encryption `-mhe=on`)",
                badge: "7z 专属防护",
                content: "开启后，归档包的目录索引和文件名列表均被加密。未输入正确密码前，双击打开压缩包也无法窥探内部有任何文件名或目录结构。"
            )
            
            guideCard(
                icon: "square.split.2x2.fill",
                title: "分卷切割规格 (Volume Splitting)",
                badge: "大文件切割传输",
                content: "将大的归档文件切分为指定规格（如 25MB 邮件上限、4GB FAT32 移动硬盘限制或 20GB 网盘分卷）的碎片文件 (.001, .002...)。提取时只需选中主卷即可全自动顺序合并解压。"
            )
        }
    }
    
    private func guideCard(icon: String, title: String, badge: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TTZipTheme.bambooGreen)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(badge)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(TTZipTheme.kintsugiGold.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text(content)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(12)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }
}
