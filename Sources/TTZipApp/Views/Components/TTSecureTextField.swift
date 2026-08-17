import SwiftUI

/// 兼容 macOS TSM (中文输入法) 的非阻塞密码输入框
/// 彻底规避原生 `SecureField` 在 Popover/Sheet 中导致的 TSM 死锁问题
public struct TTSecureTextField: View {
    public let title: String
    @Binding public var text: String
    @State private var isRevealed: Bool = false
    
    public init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            if isRevealed {
                TextField(title, text: $text)
                    .textFieldStyle(.plain)
            } else {
                TextField(title, text: Binding(
                    get: {
                        String(repeating: "•", count: text.count)
                    },
                    set: { newValue in
                        if newValue.count < text.count {
                            text = String(text.prefix(newValue.count))
                        }
                    }
                ))
                .textFieldStyle(.plain)
                .overlay(
                    // 真实接收按键事件与粘贴的透明层
                    TextField(title, text: $text)
                        .textFieldStyle(.plain)
                        .opacity(0.011)
                )
            }
            
            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(isRevealed ? "隐藏密码" : "显示密码")
        }
    }
}
