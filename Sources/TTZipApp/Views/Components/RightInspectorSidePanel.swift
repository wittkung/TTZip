import SwiftUI
import TTZipCore

/// 右侧上下文 Inspector 侧栏面板 (支持 Home 与 Compress 模式)
public struct RightInspectorSidePanel: View {
    @ObservedObject public var viewModel: AppViewState
    @Binding public var rightVerticalTopHeight: CGFloat
    
    public init(viewModel: AppViewState, rightVerticalTopHeight: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._rightVerticalTopHeight = rightVerticalTopHeight
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header 栏 - 顶部对齐高度 52pt
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("INSPECTOR")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                        .tracking(2)
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text(viewModel.selectedDiskItem?.isDirectory == true ? "目录全息画板" : "文件属性与预览")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                if viewModel.selectedDiskItem != nil {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            viewModel.selectedDiskItem = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            // 统一置顶分割线 (金缮金强调线对齐)
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.activeTab == .compressWorkspace {
                    // 1. 新建压缩包 Tab 下: 第三栏上下拆分为 2 份，支持用户手势上下拖拽调节比例
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
                    .frame(height: rightVerticalTopHeight)
                    .clipped()
                    
                    // 可上下拖拽垂直分栏 Handle
                    ResizableHorizontalDividerHandle(
                        height: $rightVerticalTopHeight,
                        minHeight: 120,
                        maxHeight: 650
                    )
                    .padding(.vertical, 2)
                    
                    // 下半部分: 媒体预览与属性信息 (InspectorColumnView)
                    if let item = viewModel.selectedDiskItem {
                        InspectorColumnView(
                            item: item,
                            onSelectArchive: { archivePath in
                                Task { await viewModel.loadArchive(path: archivePath) }
                            },
                            onCompressPath: { folderPath in
                                viewModel.openCompressWorkspace(paths: [folderPath])
                            },
                            onPreviewFile: { _ in }
                        )
                        .id(item.path)
                        .frame(maxHeight: .infinity)
                        .clipped()
                    } else {
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text("点击上方项查看媒体属性与画板")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.primary.opacity(0.015))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                } else {
                    // 2. 主页与解压 (.home) 等其它 Tab 下: 右侧专注呈现“媒体浏览与细节 Inspector”
                    if let item = viewModel.selectedDiskItem {
                        InspectorColumnView(
                            item: item,
                            onSelectArchive: { archivePath in
                                Task { await viewModel.loadArchive(path: archivePath) }
                            },
                            onCompressPath: { folderPath in
                                viewModel.openCompressWorkspace(paths: [folderPath])
                            },
                            onPreviewFile: { _ in }
                        )
                        .id(item.path)
                        .frame(maxHeight: .infinity)
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("在中央选择文件或文件夹")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("选中文件可直接预览与查看属性")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}
