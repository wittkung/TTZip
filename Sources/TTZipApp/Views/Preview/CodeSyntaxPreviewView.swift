// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import SwiftUI
import AppKit
import TTZipCore

public struct CodeTextEditorContainerView: View {
    public let initialText: String
    public let fileURL: URL?
    public let fileName: String
    
    @State private var editedText: String = ""
    @State private var isEdited: Bool = false
    @State private var isSavedToastPresented: Bool = false
    @State private var saveErrorMessage: String? = nil
    
    public init(initialText: String, fileURL: URL?, fileName: String) {
        self.initialText = initialText
        self.fileURL = fileURL
        self.fileName = fileName
        self._editedText = State(initialValue: initialText)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TTZipTheme.bambooGreen)
                    Text(languageName)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(TTZipTheme.bambooGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                if isEdited {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Unsaved")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                if isSavedToastPresented {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Saved to disk")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(TTZipTheme.bambooGreen)
                    .transition(.opacity)
                }
                
                if let url = fileURL, url.isFileURL {
                    Button(action: { saveFile() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Save (⌘S)")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(isEdited ? Color.white : TTZipTheme.bambooGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isEdited ? TTZipTheme.bambooGreen : TTZipTheme.bambooGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("s", modifiers: [.command])
                    .help("Save changes to local file (⌘S)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))
            
            Divider()
            
            CodeHighlightingEditorNSView(
                text: $editedText,
                fileName: fileName,
                onTextChange: { newText in
                    if newText != initialText {
                        isEdited = true
                    }
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: initialText) {
            editedText = initialText
            isEdited = false
        }
    }
    
    private var languageName: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "Swift Code"
        case "kt", "kts": return "Kotlin Code"
        case "java": return "Java Source"
        case "py": return "Python Script"
        case "js", "jsx": return "JavaScript"
        case "ts", "tsx": return "TypeScript"
        case "c", "h": return "C Source"
        case "cpp", "hpp", "cc", "cxx": return "C++ Source"
        case "rs": return "Rust Source"
        case "go": return "Go Source"
        case "sh", "bash", "zsh": return "Shell Script"
        case "html", "htm": return "HTML Document"
        case "css", "scss", "less": return "CSS Stylesheet"
        case "json", "json5": return "JSON File"
        case "xml", "plist": return "XML / Plist"
        case "yaml", "yml": return "YAML Config"
        case "md", "markdown": return "Markdown Document"
        case "sql": return "SQL Script"
        default: return ext.isEmpty ? "Plain Text" : "\(ext.uppercased()) Text"
        }
    }
    
    private func saveFile() {
        guard let url = fileURL, url.isFileURL else { return }
        do {
            try editedText.write(to: url, atomically: true, encoding: .utf8)
            withAnimation {
                isEdited = false
                isSavedToastPresented = true
            }
            NotificationCenter.default.post(name: NSNotification.Name("TTZipArchiveUnlockedRefresh"), object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isSavedToastPresented = false
                }
            }
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

public struct CodeHighlightingEditorNSView: NSViewRepresentable {
    @Binding public var text: String
    public let fileName: String
    public var onTextChange: ((String) -> Void)? = nil
    
    public init(text: Binding<String>, fileName: String, onTextChange: ((String) -> Void)? = nil) {
        self._text = text
        self.fileName = fileName
        self.onTextChange = onTextChange
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.highlightSyntax(in: textView, fileName: fileName)
        
        scrollView.documentView = textView
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.highlightSyntax(in: textView, fileName: fileName)
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeHighlightingEditorNSView
        
        init(_ parent: CodeHighlightingEditorNSView) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            parent.text = newText
            parent.onTextChange?(newText)
            highlightSyntax(in: textView, fileName: parent.fileName)
        }
        
        @MainActor
        public func highlightSyntax(in textView: NSTextView, fileName: String) {
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 && fullRange.length < 300_000 else { return }
            
            storage.beginEditing()
            
            let defaultFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
            let defaultColor = NSColor.labelColor
            storage.setAttributes([
                .font: defaultFont,
                .foregroundColor: defaultColor
            ], range: fullRange)
            
            let ext = (fileName as NSString).pathExtension.lowercased()
            let rules = SyntaxLanguageRules.rules(forExtension: ext)
            
            let commentColor = NSColor(red: 0.45, green: 0.60, blue: 0.40, alpha: 1.0)
            let stringColor = NSColor(red: 0.85, green: 0.55, blue: 0.40, alpha: 1.0)
            let keywordColor = NSColor(red: 0.35, green: 0.65, blue: 0.90, alpha: 1.0)
            let numberColor = NSColor(red: 0.70, green: 0.80, blue: 0.60, alpha: 1.0)
            let typeColor = NSColor(red: 0.30, green: 0.80, blue: 0.70, alpha: 1.0)
            let attributeColor = NSColor(red: 0.90, green: 0.45, blue: 0.70, alpha: 1.0)
            
            if let commentRegex = try? NSRegularExpression(pattern: rules.commentPattern, options: []) {
                let matches = commentRegex.matches(in: storage.string, options: [], range: fullRange)
                for match in matches {
                    storage.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                }
            }
            
            let stringPattern = "\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'"
            if let stringRegex = try? NSRegularExpression(pattern: stringPattern, options: []) {
                let matches = stringRegex.matches(in: storage.string, options: [], range: fullRange)
                for match in matches {
                    storage.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                }
            }
            
            if !rules.keywords.isEmpty {
                let sortedKeywords = rules.keywords.sorted { $0.count > $1.count }.joined(separator: "|")
                let regexOptions: NSRegularExpression.Options = rules.caseSensitive ? [] : [.caseInsensitive]
                let keywordPattern = "\\b(\(sortedKeywords))\\b"
                if let keywordRegex = try? NSRegularExpression(pattern: keywordPattern, options: regexOptions) {
                    let matches = keywordRegex.matches(in: storage.string, options: [], range: fullRange)
                    for match in matches {
                        storage.addAttribute(.foregroundColor, value: keywordColor, range: match.range)
                        storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .semibold), range: match.range)
                    }
                }
            }
            
            let numberPattern = "\\b\\d+(\\.\\d+)?\\b|0x[0-9a-fA-F]+\\b"
            if let numberRegex = try? NSRegularExpression(pattern: numberPattern, options: []) {
                let matches = numberRegex.matches(in: storage.string, options: [], range: fullRange)
                for match in matches {
                    storage.addAttribute(.foregroundColor, value: numberColor, range: match.range)
                }
            }
            
            if !rules.types.isEmpty {
                let sortedTypes = rules.types.sorted { $0.count > $1.count }.joined(separator: "|")
                let typePattern = "\\b(\(sortedTypes))\\b|@[a-zA-Z0-9_]+"
                if let typeRegex = try? NSRegularExpression(pattern: typePattern, options: []) {
                    let matches = typeRegex.matches(in: storage.string, options: [], range: fullRange)
                    for match in matches {
                        storage.addAttribute(.foregroundColor, value: ext == "swift" ? attributeColor : typeColor, range: match.range)
                    }
                }
            }
            
            storage.endEditing()
        }
    }
}
