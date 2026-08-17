import SwiftUI

/// TTZip 统一 Kintsugi 金/竹绿风格的 TextField 修饰器
public struct TTZipTextFieldModifier: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 8) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
    }
}

extension View {
    public func ttzipTextFieldStyle(cornerRadius: CGFloat = 8) -> some View {
        self.modifier(TTZipTextFieldModifier(cornerRadius: cornerRadius))
    }
}
