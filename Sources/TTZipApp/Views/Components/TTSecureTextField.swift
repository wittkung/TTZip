// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI

/// Non-blocking password text field compatible with macOS Text Service Manager (TSM).
/// Avoids native `SecureField` IME deadlock in Popovers/Sheets.
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
            .help(isRevealed ? "Hide password" : "Show password")
        }
    }
}
