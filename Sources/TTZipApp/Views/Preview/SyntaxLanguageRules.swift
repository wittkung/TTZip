// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import Foundation

public struct SyntaxLanguageRules {
    public static func rules(forExtension ext: String) -> (
        keywords: Set<String>,
        types: Set<String>,
        commentPattern: String,
        caseSensitive: Bool
    ) {
        switch ext.lowercased() {
        case "swift":
            return (
                keywords: ["func", "let", "var", "class", "struct", "enum", "protocol", "extension", "typealias", "import", "public", "private", "fileprivate", "internal", "open", "static", "override", "final", "mutating", "nonmutating", "convenience", "required", "lazy", "weak", "unowned", "actor", "indirect", "rethrows", "throws", "throw", "try", "catch", "do", "if", "else", "guard", "for", "in", "while", "repeat", "switch", "case", "default", "break", "continue", "fallthrough", "return", "async", "await", "some", "any", "nil", "true", "false", "self", "Self", "super", "init", "deinit", "subscript", "where", "is", "as"],
                types: ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "View", "State", "Binding", "ObservableObject", "Void", "Any", "Object", "URL", "Data", "Task", "MainActor"],
                commentPattern: "//.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: true
            )
            
        case "c", "h", "cpp", "hpp", "cc", "cxx", "m", "mm":
            return (
                keywords: ["auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while", "class", "constexpr", "const_cast", "delete", "dynamic_cast", "explicit", "export", "friend", "mutable", "namespace", "new", "noexcept", "nullptr", "operator", "private", "protected", "public", "reinterpret_cast", "static_cast", "template", "this", "throw", "try", "typename", "using", "virtual"],
                types: ["int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "size_t", "uintptr_t", "std", "string", "vector", "map", "set", "unique_ptr", "shared_ptr"],
                commentPattern: "//.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: true
            )
            
        case "java":
            return (
                keywords: ["abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue", "default", "do", "double", "else", "enum", "extends", "final", "finally", "float", "for", "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "package", "private", "protected", "public", "return", "short", "static", "strictfp", "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "void", "volatile", "while", "record", "sealed", "non-sealed", "permits", "var", "yield", "true", "false", "null"],
                types: ["String", "Integer", "Long", "Boolean", "Double", "Float", "Object", "List", "Map", "Set", "ArrayList", "HashMap", "System", "Thread"],
                commentPattern: "//.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: true
            )
            
        case "py":
            return (
                keywords: ["and", "as", "assert", "async", "await", "break", "class", "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield", "True", "False", "None", "self", "cls"],
                types: ["int", "str", "float", "list", "dict", "set", "tuple", "bool", "bytes", "object", "type"],
                commentPattern: "#.*|'''[\\s\\S]*?'''|\"\"\"[\\s\\S]*?\"\"\"",
                caseSensitive: true
            )
            
        case "js", "jsx", "ts", "tsx":
            return (
                keywords: ["async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete", "do", "else", "export", "extends", "false", "finally", "for", "function", "if", "import", "in", "instanceof", "new", "null", "return", "super", "switch", "this", "throw", "true", "try", "typeof", "var", "void", "while", "with", "yield", "let", "static", "enum", "implements", "interface", "package", "private", "protected", "public", "type", "declare", "abstract", "as", "is", "keyof", "readonly", "never", "unknown", "any"],
                types: ["Promise", "Array", "Object", "String", "Number", "Boolean", "Function", "Symbol", "Record", "Partial", "Required"],
                commentPattern: "//.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: true
            )
            
        case "rs":
            return (
                keywords: ["as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while", "Ok", "Err", "Some", "None"],
                types: ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64", "bool", "char", "str", "String", "Vec", "Option", "Result"],
                commentPattern: "//.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: true
            )
            
        case "go":
            return (
                keywords: ["break", "default", "func", "interface", "select", "case", "defer", "go", "map", "struct", "chan", "else", "goto", "package", "switch", "const", "fallthrough", "if", "range", "type", "continue", "for", "import", "return", "var", "nil", "true", "false"],
                types: ["string", "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr", "byte", "rune", "float32", "float64", "complex64", "complex128", "bool", "error"],
                commentPattern: "//.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: true
            )
            
        case "sql":
            return (
                keywords: ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "ASC", "DESC", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "AND", "OR", "NOT", "NULL", "IS", "AS", "LIKE", "IN", "EXISTS", "BETWEEN", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "DEFAULT", "CHECK", "CONSTRAINT", "CASE", "WHEN", "THEN", "ELSE", "END"],
                types: ["INT", "INTEGER", "VARCHAR", "TEXT", "CHAR", "BOOLEAN", "DATE", "TIMESTAMP", "DECIMAL", "FLOAT", "BLOB"],
                commentPattern: "--.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: false
            )
            
        case "kt", "kts":
            return (
                keywords: ["abstract", "actual", "annotation", "companion", "crossinline", "data", "enum", "expect", "external", "final", "infix", "inline", "inner", "internal", "lateinit", "noinline", "open", "operator", "out", "override", "private", "protected", "public", "reified", "sealed", "tailrec", "vararg", "val", "var", "fun", "class", "object", "interface", "typealias", "this", "super", "is", "as", "when", "if", "else", "try", "catch", "finally", "for", "while", "do", "return", "break", "continue", "throw", "import", "package", "null", "true", "false"],
                types: ["String", "Int", "Double", "Float", "Boolean", "Long", "Short", "Byte", "Char", "Array", "List", "Map", "Set"],
                commentPattern: "//.*|/\\*[\\s\\S]*?\\*/",
                caseSensitive: true
            )
            
        case "sh", "bash", "zsh":
            return (
                keywords: ["if", "then", "elif", "else", "fi", "for", "in", "do", "done", "while", "until", "case", "esac", "function", "return", "exit", "set", "export", "unset", "alias", "local", "echo", "cd", "mkdir", "rm", "cp", "mv", "grep", "sed", "awk", "sudo"],
                types: [],
                commentPattern: "#.*",
                caseSensitive: true
            )
            
        default:
            return (
                keywords: ["func", "let", "var", "class", "def", "return", "if", "else", "for", "while", "import", "try", "catch", "async", "await"],
                types: ["String", "Int", "Boolean"],
                commentPattern: "//.*|#.*",
                caseSensitive: true
            )
        }
    }
}
