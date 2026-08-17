import SwiftUI
import TTZipCore

@MainActor
private final class ExtractModalEventObserver: ObservableObject, ArchiveEventObserverProtocol {
    @Published var vaultUpdateTrigger: Int = 0
    
    init() {
        ArchiveEventCenter.shared.addObserver(self, dispatchQueue: .main)
    }
    
    deinit {
        ArchiveEventCenter.shared.removeObserver(self)
    }
    
    nonisolated func onArchiveEvent(_ event: ArchiveEvent) {
        if case .passwordVaultUnlocked = event {
            Task { @MainActor in
                self.vaultUpdateTrigger += 1
            }
        }
    }
}

struct ExtractModalView: View {
    let archivePath: String
    @Binding var isPresented: Bool
    
    @State private var destinationDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "/tmp"
    @State private var autoOpenFolder = true
    @State private var password = ""
    @State private var isExtracting = false
    @State private var statusMessage = ""
    @StateObject private var eventObserver = ExtractModalEventObserver()
    
    private var vaultEntries: [PasswordVaultEntry] {
        _ = eventObserver.vaultUpdateTrigger
        return PasswordVaultManager.shared.getEntries()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header 栏 - 顶部对齐高度 52pt
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TTZipTheme.kintsugiGold)
                    Text("解压提取归档包")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 10))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text((archivePath as NSString).lastPathComponent)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(Capsule())
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            
            // 统一置顶分割线 (金缮金强调线对齐)
            Rectangle()
                .fill(TTZipTheme.kintsugiGold)
                .frame(height: 1.5)
            
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("解压输出目标路径")
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .tracking(1)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        HStack(spacing: 8) {
                            TextField("解压路径", text: $destinationDir)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                                )
                            
                            Button("选择路径...") {
                                pickDirectory()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(TTZipTheme.bambooGreen.opacity(0.12))
                            .foregroundStyle(TTZipTheme.bambooGreen)
                            .clipShape(Capsule())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("解压口令 (如已加密)")
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .tracking(1)
                            .foregroundStyle(TTZipTheme.kintsugiGold)
                        HStack(spacing: 8) {
                            TTSecureTextField("无口令请留空", text: $password)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.035))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                                )
                            
                            Menu {
                                ForEach(vaultEntries) { entry in
                                    Button("\(entry.label) (\(entry.category))") {
                                        password = entry.password
                                        PasswordVaultManager.shared.recordUsage(id: entry.id)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 10))
                                    Text("密码库")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(TTZipTheme.bambooGreen.opacity(0.12))
                                .foregroundStyle(TTZipTheme.bambooGreen)
                                .clipShape(Capsule())
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    
                    Toggle("解压完成后自动在 Finder 中高亮查看", isOn: $autoOpenFolder)
                        .font(.system(size: 12, weight: .medium))
                        .toggleStyle(.checkbox)
                }
                .padding(16)
                .background(Color.primary.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
                )
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                }
                
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button("取消") { isPresented = false }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                    
                    Button(action: startExtraction) {
                        HStack(spacing: 6) {
                            if isExtracting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isExtracting ? "正在提取..." : "开始提取解压")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(isExtracting ? Color.secondary.opacity(0.2) : TTZipTheme.bambooGreen)
                        .foregroundStyle(isExtracting ? Color.secondary : Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isExtracting)
                }
            }
            .padding(20)
        }
        .frame(width: 520)
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func pickDirectory() {
        if let path = SystemDialogHelper.pickDirectory(prompt: "选择解压目标文件夹", defaultPath: destinationDir) {
            destinationDir = path
        }
    }
    
    private func startExtraction() {
        let valCtx = ArchiveValidationContext.forExtract(
            archivePath: archivePath,
            destinationDir: destinationDir,
            password: password.isEmpty ? nil : password
        )
        let valResult = (try? ArchiveValidationPipeline.buildDefaultExtractPipeline().validate(context: valCtx)) ?? .success
        if case .failure(let err) = valResult {
            self.statusMessage = err.localizedDescription
            return
        }
        
        isExtracting = true
        statusMessage = "正在解压提取文件..."
        ArchiveAppMediator.shared.send(event: .requestExtraction(archivePath: archivePath, destinationPath: destinationDir))
        
        Task {
            do {
                let cmdResult = try await TTZipEngineFacade.shared.extractWithCommand(
                    archivePath: archivePath,
                    destinationDir: destinationDir,
                    password: password.isEmpty ? nil : password,
                    engineFacade: SecurityProtectionProxy.shared
                )
                await MainActor.run {
                    self.statusMessage = String(format: "✅ 解压完成! (耗时 %.2fs)", cmdResult.executionDuration)
                    self.isExtracting = false
                    
                    if self.autoOpenFolder {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: self.destinationDir)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isPresented = false
                    }
                }
            } catch {
                ArchiveAppMediator.shared.send(event: .extractionFailed(archivePath: archivePath, error: error.localizedDescription))
                await MainActor.run {
                    self.statusMessage = "解压失败: \(error.localizedDescription)"
                    self.isExtracting = false
                }
            }
        }
    }
}
