import Foundation

// MARK: - ArchiveFilterDSLLexer (词法分析器)

public final class ArchiveFilterDSLLexer: Sendable {
    private let input: String
    
    public init(input: String) {
        self.input = input
    }
    
    public func tokenize() throws -> [DSLToken] {
        var tokens: [DSLToken] = []
        let chars = Array(input)
        let length = chars.count
        var index = 0
        
        while index < length {
            let char = chars[index]
            
            // 1. 跳过空白字符
            if char.isWhitespace {
                index += 1
                continue
            }
            
            // 2. 括号与标点符号
            if char == "(" {
                tokens.append(.leftParen)
                index += 1
                continue
            }
            if char == ")" {
                tokens.append(.rightParen)
                index += 1
                continue
            }
            if char == ":" {
                tokens.append(.colon)
                index += 1
                continue
            }
            if char == "," {
                tokens.append(.comma)
                index += 1
                continue
            }
            
            // 3. 比较运算符
            if char == ">" {
                if index + 1 < length && chars[index + 1] == "=" {
                    tokens.append(.greaterThanOrEqual)
                    index += 2
                } else {
                    tokens.append(.greaterThan)
                    index += 1
                }
                continue
            }
            if char == "<" {
                if index + 1 < length && chars[index + 1] == "=" {
                    tokens.append(.lessThanOrEqual)
                    index += 2
                } else {
                    tokens.append(.lessThan)
                    index += 1
                }
                continue
            }
            if char == "=" {
                if index + 1 < length && chars[index + 1] == "=" {
                    tokens.append(.equals)
                    index += 2
                } else {
                    tokens.append(.equals)
                    index += 1
                }
                continue
            }
            if char == "!" {
                if index + 1 < length && chars[index + 1] == "=" {
                    // != 运算符处理
                    tokens.append(.identifier("!="))
                    index += 2
                } else {
                    tokens.append(.not)
                    index += 1
                }
                continue
            }
            
            // 4. 双字符逻辑运算符 && 和 ||
            if char == "&" {
                if index + 1 < length && chars[index + 1] == "&" {
                    tokens.append(.and)
                    index += 2
                    continue
                }
            }
            if char == "|" {
                if index + 1 < length && chars[index + 1] == "|" {
                    tokens.append(.or)
                    index += 2
                    continue
                }
            }
            
            // 5. 字符串字面量 ("..." 或 '...')
            if char == "\"" || char == "'" {
                let quote = char
                index += 1
                var literal = ""
                var escaped = false
                var closed = false
                
                while index < length {
                    let current = chars[index]
                    if escaped {
                        literal.append(current)
                        escaped = false
                    } else if current == "\\" {
                        escaped = true
                    } else if current == quote {
                        closed = true
                        index += 1
                        break
                    } else {
                        literal.append(current)
                    }
                    index += 1
                }
                
                if !closed {
                    throw DSLParseError.invalidSyntax(message: "Unterminated string literal", position: index)
                }
                tokens.append(.stringLiteral(literal))
                continue
            }
            
            // 6. 标识符 / 关键字 / 纯数字 / 包含通配符的单词
            var valueStr = ""
            let startPos = index
            while index < length {
                let c = chars[index]
                if c.isWhitespace || c == "(" || c == ")" || c == ":" || c == "," || c == ">" || c == "<" || c == "=" || c == "\"" || c == "'" {
                    break
                }
                // 处理逻辑运算符中断
                if c == "&" && index + 1 < length && chars[index + 1] == "&" { break }
                if c == "|" && index + 1 < length && chars[index + 1] == "|" { break }
                
                valueStr.append(c)
                index += 1
            }
            
            if valueStr.isEmpty {
                throw DSLParseError.invalidSyntax(message: "Unexpected character '\(char)'", position: startPos)
            }
            
            // 检查逻辑关键字 (大小写不敏感)
            let upper = valueStr.uppercased()
            if upper == "AND" {
                tokens.append(.and)
            } else if upper == "OR" {
                tokens.append(.or)
            } else if upper == "NOT" {
                tokens.append(.not)
            } else if let num = Int64(valueStr) {
                tokens.append(.numberLiteral(num))
            } else {
                tokens.append(.identifier(valueStr))
            }
        }
        
        return tokens
    }
}

// MARK: - ArchiveFilterDSLParser (递归下降语法解析器)

public final class ArchiveFilterDSLParser: Sendable {
    private let tokens: [DSLToken]
    
    public init(tokens: [DSLToken] = []) {
        self.tokens = tokens
    }
    
    public func parse() throws -> any ArchiveFilterExpressionProtocol {
        if tokens.isEmpty {
            return MatchAllExpression()
        }
        var index = 0
        let expr = try parseOrExpression(tokens: tokens, index: &index)
        if index < tokens.count {
            let trailingToken = tokens[index]
            throw DSLParseError.unexpectedToken(token: trailingToken, expected: "end of expression")
        }
        return expr
    }
    
    public func parseOrFallback(query: String) -> any ArchiveFilterExpressionProtocol {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return MatchAllExpression()
        }
        
        do {
            let lexer = ArchiveFilterDSLLexer(input: trimmed)
            let parsedTokens = try lexer.tokenize()
            let parser = ArchiveFilterDSLParser(tokens: parsedTokens)
            return try parser.parse()
        } catch {
            // 容错降级逻辑: 无法作为复杂 DSL 解析时，自动降级为文件名通配模糊查询
            return FilenameGlobExpression(pattern: trimmed)
        }
    }
    
    // MARK: - 递归下降算符优先级处理
    
    // 优先级 1: OR 表达式 (最低优先级)
    private func parseOrExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var left = try parseAndExpression(tokens: tokens, index: &index)
        
        while index < tokens.count {
            if tokens[index] == .or {
                index += 1 // 消费 OR
                let right = try parseAndExpression(tokens: tokens, index: &index)
                left = OrExpression(left: left, right: right)
            } else {
                break
            }
        }
        return left
    }
    
    // 优先级 2: AND 表达式 (及隐式 AND 连接)
    private func parseAndExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        var left = try parseNotExpression(tokens: tokens, index: &index)
        
        while index < tokens.count {
            if tokens[index] == .and {
                index += 1 // 消费 AND
                let right = try parseNotExpression(tokens: tokens, index: &index)
                left = AndExpression(left: left, right: right)
            } else if canStartPrimaryExpression(at: index, tokens: tokens) {
                // 隐式 AND 拼接: 例如 ext:pdf size:>10MB
                let right = try parseNotExpression(tokens: tokens, index: &index)
                left = AndExpression(left: left, right: right)
            } else {
                break
            }
        }
        return left
    }
    
    // 优先级 3: NOT 单目表达式
    private func parseNotExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        if index < tokens.count && tokens[index] == .not {
            index += 1 // 消费 NOT
            let operand = try parseNotExpression(tokens: tokens, index: &index)
            return NotExpression(operand: operand)
        }
        return try parsePrimaryExpression(tokens: tokens, index: &index)
    }
    
    // 优先级 4: 基本表达元 (Primary Expression)
    private func parsePrimaryExpression(tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        guard index < tokens.count else {
            throw DSLParseError.unexpectedToken(token: nil, expected: "expression")
        }
        
        let currentToken = tokens[index]
        
        // A. 括号表达式 (...)
        if currentToken == .leftParen {
            index += 1 // 消费 '('
            let innerExpr = try parseOrExpression(tokens: tokens, index: &index)
            guard index < tokens.count && tokens[index] == .rightParen else {
                throw DSLParseError.unexpectedToken(token: index < tokens.count ? tokens[index] : nil, expected: ")")
            }
            index += 1 // 消费 ')'
            return innerExpr
        }
        
        // B. Key:Value 结构 (例如 ext:pdf, size:>50MB, modified:<7d, name:*draft*)
        if case .identifier(let fieldName) = currentToken {
            let lowerField = fieldName.lowercased()
            if index + 1 < tokens.count && tokens[index + 1] == .colon {
                // 这是一个 Key:Value 结构
                index += 2 // 消费 fieldName 与 ':'
                return try parseKeyValueExpression(field: lowerField, tokens: tokens, index: &index)
            }
        }
        
        // C. 普通文本 / 模糊通配符匹配 (无 key 前缀)
        switch currentToken {
        case .identifier(let val):
            index += 1
            return FilenameGlobExpression(pattern: val)
        case .stringLiteral(let val):
            index += 1
            return FilenameGlobExpression(pattern: val)
        case .numberLiteral(let num):
            index += 1
            return FilenameGlobExpression(pattern: String(num))
        default:
            throw DSLParseError.unexpectedToken(token: currentToken, expected: "identifier, string literal or key:value filter")
        }
    }
    
    // 解析 Key:Value 语法结构
    private func parseKeyValueExpression(field: String, tokens: [DSLToken], index: inout Int) throws -> any ArchiveFilterExpressionProtocol {
        // 提取可选的运算符 (如 >, <, >=, <=, =)
        var op: ComparisonOperator = .greaterThan
        var hasExplicitOp = false
        
        if index < tokens.count {
            switch tokens[index] {
            case .greaterThan:
                op = .greaterThan
                hasExplicitOp = true
                index += 1
            case .lessThan:
                op = .lessThan
                hasExplicitOp = true
                index += 1
            case .greaterThanOrEqual:
                op = .greaterThanOrEqual
                hasExplicitOp = true
                index += 1
            case .lessThanOrEqual:
                op = .lessThanOrEqual
                hasExplicitOp = true
                index += 1
            case .equals:
                op = .equals
                hasExplicitOp = true
                index += 1
            default:
                break
            }
        }
        
        // 提取 Field 对应的值字符串 (支持逗号分隔列表，如 ext:jpg,png)
        var rawValueParts: [String] = []
        while index < tokens.count {
            switch tokens[index] {
            case .identifier(let val):
                rawValueParts.append(val)
                index += 1
            case .stringLiteral(let val):
                rawValueParts.append(val)
                index += 1
            case .numberLiteral(let num):
                rawValueParts.append(String(num))
                index += 1
            default:
                break
            }
            
            // 如果紧接着是逗号，消费逗号并继续收集下一个值段
            if index < tokens.count && tokens[index] == .comma {
                index += 1
            } else {
                break
            }
        }
        
        guard !rawValueParts.isEmpty else {
            throw DSLParseError.unexpectedToken(token: index < tokens.count ? tokens[index] : nil, expected: "field value")
        }
        
        let rawValue = rawValueParts.joined(separator: ",")
        
        // 根据 field 分派终结符类型
        switch field {
        case "ext", "extension", "type":
            let exts = rawValue.components(separatedBy: ",")
            return ExtensionExpression(extensions: exts)
            
        case "name", "filename", "path":
            return FilenameGlobExpression(pattern: rawValue)
            
        case "size":
            let effectiveOp = hasExplicitOp ? op : .greaterThan
            guard let expr = SizeExpression(sizeString: rawValue, operatorType: effectiveOp) else {
                throw DSLParseError.invalidSizeFormat(rawValue)
            }
            return expr
            
        case "modified", "date", "mtime":
            let effectiveOp = hasExplicitOp ? op : .lessThan
            guard let expr = DateRangeExpression(dateSpec: rawValue, operatorType: effectiveOp) else {
                throw DSLParseError.invalidDateFormat(rawValue)
            }
            return expr
            
        default:
            // 未知 Key 时降级为 FilenameGlobExpression
            return FilenameGlobExpression(pattern: "\(field):\(rawValue)")
        }
    }
    
    // 判断 index 处的 token 是否能作为 Primary Expression 的起始符号
    private func canStartPrimaryExpression(at index: Int, tokens: [DSLToken]) -> Bool {
        guard index < tokens.count else { return false }
        switch tokens[index] {
        case .leftParen, .identifier, .stringLiteral, .numberLiteral:
            return true
        default:
            return false
        }
    }
}
