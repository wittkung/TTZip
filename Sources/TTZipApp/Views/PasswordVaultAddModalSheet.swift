import SwiftUI
import TTZipCore

public struct PasswordVaultAddModalSheet: View {
    @Binding public var isPresented: Bool
    @State private var newLabel: String = ""
    @State private var newCategory: String = "通用"
    @State private var newPassword: String = ""
    
    public let onSave: (String, String, String) -> Void
    
    public init(isPresented: Binding<Bool>, onSave: @escaping (String, String, String) -> Void) {
        self._isPresented = isPresented
        self.onSave = onSave
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("添加密码至安全宝库")
                .font(.system(size: 14, weight: .bold, design: .serif))
            
            VStack(alignment: .leading, spacing: 10) {
                TextField("口令描述 (例如: 商业财务加密资料口令)", text: $newLabel)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(8)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                
                TextField("分类 (例如: 常用 / 工作 / 个人)", text: $newCategory)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(8)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                
                HStack(spacing: 8) {
                    TextField("解压口令明文", text: $newPassword)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(8)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8))
                    
                    Button("生成强密码") {
                        newPassword = PasswordVaultManager.shared.generateRandomPassword()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .buttonStyle(.plain)
                
                Button("保存至本地加密库") {
                    let pwd = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !pwd.isEmpty else { return }
                    let lbl = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    let labelToUse = lbl.isEmpty ? "解压口令" : lbl
                    let catToUse = newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "通用" : newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(labelToUse, pwd, catToUse)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(TTZipTheme.bambooGreen)
                .disabled(newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
