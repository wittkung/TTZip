import SwiftUI
import TTZipCore

/// 主页与资源解压面板容器
public struct HomeExplorerContainerView: View {
    @ObservedObject public var viewModel: AppViewState
    public let isRightSidebarVisible: Bool
    
    public init(viewModel: AppViewState, isRightSidebarVisible: Bool) {
        self.viewModel = viewModel
        self.isRightSidebarVisible = isRightSidebarVisible
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header 栏 - 顶部对齐高度 52pt
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("EXPLORER")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("资源文件浏览器")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // 根目录授权按钮
                Button(action: {
                    RootFolderAccessManager.shared.requestRootAccess(for: RootFolderAccessManager.shared.highestRootURL(for: viewModel.currentDirectory))
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("根目录授权")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(TTZipTheme.kintsugiGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(TTZipTheme.kintsugiGold.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("一次性授权最上层根目录，此后上下层目录无缝切换无需重复授权")
                
                // 路径 Breadcrumb 动态标牌
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text(viewModel.currentDirectory.lastPathComponent.isEmpty ? "/" : viewModel.currentDirectory.lastPathComponent)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            // 统一置顶分割线 (金缮金强调线对齐)
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            DiskDirectoryBrowserView(
                rootDirectory: viewModel.currentDirectory,
                onSelectArchive: { archivePath in
                    let u = URL(fileURLWithPath: archivePath)
                    viewModel.openArchiveAsFolder(url: u)
                },
                onCompressPath: { folderPath in
                    viewModel.openCompressWorkspace(paths: [folderPath])
                },
                onPreviewFile: { _ in },
                onSelectItem: { item in
                    viewModel.selectedDiskItem = item
                }
            )
        }
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .padding(.top, 38)
        .padding(.leading, 0)
        .padding(.trailing, (isRightSidebarVisible && viewModel.selectedDiskItem != nil) ? 4 : TTZipTheme.Spacing.md)
        .padding(.bottom, TTZipTheme.Spacing.md)
    }
}
