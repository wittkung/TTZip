// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit

/// AppKit-backed custom text field for Omnibar navigation with zero IME interference.
public struct OmnibarTextField: NSViewRepresentable {
    @Binding public var text: String
    public var placeholder: String
    public var isFocused: Bool
    public var onCommit: () -> Void
    public var onCancel: () -> Void
    public var onTab: () -> Bool
    public var onMoveDown: () -> Bool
    public var onMoveUp: () -> Bool
    public var onTextChange: (String) -> Void
    
    public init(
        text: Binding<String>,
        placeholder: String = "Enter path or search...",
        isFocused: Bool = false,
        onCommit: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onTab: @escaping () -> Bool = { false },
        onMoveDown: @escaping () -> Bool = { false },
        onMoveUp: @escaping () -> Bool = { false },
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isFocused = isFocused
        self.onCommit = onCommit
        self.onCancel = onCancel
        self.onTab = onTab
        self.onMoveDown = onMoveDown
        self.onMoveUp = onMoveUp
        self.onTextChange = onTextChange
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> CustomNSTextField {
        let textField = CustomNSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)
        textField.textColor = NSColor.labelColor
        textField.placeholderString = placeholder
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.stringValue = text
        textField.coordinator = context.coordinator
        return textField
    }
    
    public func updateNSView(_ nsView: CustomNSTextField, context: Context) {
        context.coordinator.parent = self
        
        let hasMarked = (nsView.currentEditor() as? NSTextView)?.hasMarkedText() ?? false
        if nsView.stringValue != text && !hasMarked {
            nsView.stringValue = text
        }
        
        if isFocused && nsView.window?.firstResponder != nsView.currentEditor() {
            DispatchQueue.main.async {
                if let window = nsView.window {
                    window.makeFirstResponder(nsView)
                    nsView.selectText(nil)
                }
            }
        }
    }
    
    public final class CustomNSTextField: NSTextField {
        weak var coordinator: Coordinator?
        
        public override func performKeyEquivalent(with event: NSEvent) -> Bool {
            // Let Tab and Escape be processed by coordinator commands
            if event.keyCode == 48 || event.keyCode == 53 { // 48 is Tab, 53 is Esc
                return false
            }
            return super.performKeyEquivalent(with: event)
        }
    }
    
    public final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: OmnibarTextField
        
        init(_ parent: OmnibarTextField) {
            self.parent = parent
        }
        
        public func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            let newValue = textField.stringValue
            if parent.text != newValue {
                parent.text = newValue
                parent.onTextChange(newValue)
            }
        }
        
        public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // CRITICAL: IME / TSM Immunity - if marked text exists, let macOS input method handle candidate selection
            if textView.hasMarkedText() {
                return false
            }
            
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.onCommit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            case #selector(NSResponder.insertTab(_:)):
                if parent.onTab() {
                    return true
                }
                return false
            case #selector(NSResponder.moveDown(_:)):
                if parent.onMoveDown() {
                    return true
                }
                return false
            case #selector(NSResponder.moveUp(_:)):
                if parent.onMoveUp() {
                    return true
                }
                return false
            default:
                return false
            }
        }
    }
}
