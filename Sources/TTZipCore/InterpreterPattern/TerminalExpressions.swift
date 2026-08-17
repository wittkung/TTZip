import Foundation

// MARK: - ComparisonOperator (比较运算符)

public enum ComparisonOperator: String, Sendable, Equatable {
    case greaterThan = ">"
    case lessThan = "<"
    case greaterThanOrEqual = ">="
    case lessThanOrEqual = "<="
    case equals = "="
    case notEquals = "!="
    
    public var symbol: String { rawValue }
}

// MARK: - MatchAllExpression (匹配任意终结符)

public struct MatchAllExpression: ArchiveFilterExpressionProtocol {
    public init() {}
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        return true
    }
    
    public var dslDescription: String {
        return "[MATCH_ALL]"
    }
}

// MARK: - MatchNoneExpression (无匹配终结符)

public struct MatchNoneExpression: ArchiveFilterExpressionProtocol {
    public init() {}
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        return false
    }
    
    public var dslDescription: String {
        return "[MATCH_NONE]"
    }
}

// MARK: - ExtensionExpression (后缀匹配终结符)

public struct ExtensionExpression: ArchiveFilterExpressionProtocol {
    public let extensions: Set<String>
    
    public init(extensions: [String]) {
        let cleaned = extensions.map { ext in
            let trimmed = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
        }.filter { !$0.isEmpty }
        self.extensions = Set(cleaned)
    }
    
    public init(extension single: String) {
        self.init(extensions: single.components(separatedBy: ","))
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        if extensions.isEmpty { return true }
        let entryExt = entry.extensionName.lowercased()
        if extensions.contains(entryExt) {
            return true
        }
        // 兜底检查: 如果 extensionName 为空，解析 pathExtension
        let pathExt = (entry.name as NSString).pathExtension.lowercased()
        return extensions.contains(pathExt)
    }
    
    public var dslDescription: String {
        let sortedExts = extensions.sorted().joined(separator: ",")
        return "ext:\(sortedExts)"
    }
}

// MARK: - FilenameGlobExpression (通配符文件名终结符)

public struct FilenameGlobExpression: ArchiveFilterExpressionProtocol {
    public let pattern: String
    private let regex: NSRegularExpression?
    
    public init(pattern: String) {
        self.pattern = pattern
        self.regex = Self.buildRegex(from: pattern)
    }
    
    private static func buildRegex(from globPattern: String) -> NSRegularExpression? {
        let escaped = NSRegularExpression.escapedPattern(for: globPattern)
        // 替换通配符 \* 和 \? 为正则模式
        var regexString = escaped
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        
        // 如果没有显式通配符，默认进行子串匹配
        if !globPattern.contains("*") && !globPattern.contains("?") {
            regexString = ".*" + regexString + ".*"
        } else {
            regexString = "^" + regexString + "$"
        }
        
        return try? NSRegularExpression(pattern: regexString, options: [.caseInsensitive])
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        guard let regex = regex else {
            return entry.name.localizedCaseInsensitiveContains(pattern) || entry.path.localizedCaseInsensitiveContains(pattern)
        }
        let nameRange = NSRange(entry.name.startIndex..<entry.name.endIndex, in: entry.name)
        if regex.firstMatch(in: entry.name, options: [], range: nameRange) != nil {
            return true
        }
        let pathRange = NSRange(entry.path.startIndex..<entry.path.endIndex, in: entry.path)
        return regex.firstMatch(in: entry.path, options: [], range: pathRange) != nil
    }
    
    public var dslDescription: String {
        return "name:\(pattern)"
    }
}

// MARK: - SizeExpression (尺寸比较终结符)

public struct SizeExpression: ArchiveFilterExpressionProtocol {
    public let targetBytes: Int64
    public let operatorType: ComparisonOperator
    
    public init(targetBytes: Int64, operatorType: ComparisonOperator = .greaterThan) {
        self.targetBytes = targetBytes
        self.operatorType = operatorType
    }
    
    public init?(sizeString: String, operatorType: ComparisonOperator = .greaterThan) {
        guard let bytes = Self.parseSizeString(sizeString) else { return nil }
        self.targetBytes = bytes
        self.operatorType = operatorType
    }
    
    public static func parseSizeString(_ raw: String) -> Int64? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.isEmpty { return nil }
        
        var numberPart = ""
        var unitPart = ""
        
        for char in trimmed {
            if char.isNumber || char == "." {
                numberPart.append(char)
            } else {
                unitPart.append(char)
            }
        }
        
        guard let value = Double(numberPart) else { return nil }
        
        let multiplier: Double
        switch unitPart {
        case "B", "": multiplier = 1
        case "KB", "K": multiplier = 1024
        case "MB", "M": multiplier = 1024 * 1024
        case "GB", "G": multiplier = 1024 * 1024 * 1024
        case "TB", "T": multiplier = 1024 * 1024 * 1024 * 1024
        default: return nil
        }
        
        return Int64(value * multiplier)
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        let size = entry.uncompressedSize
        switch operatorType {
        case .greaterThan: return size > targetBytes
        case .lessThan: return size < targetBytes
        case .greaterThanOrEqual: return size >= targetBytes
        case .lessThanOrEqual: return size <= targetBytes
        case .equals: return size == targetBytes
        case .notEquals: return size != targetBytes
        }
    }
    
    public var dslDescription: String {
        return "size:\(operatorType.symbol)\(targetBytes)"
    }
}

// MARK: - DateRangeExpression (修改时间范围终结符)

public struct DateRangeExpression: ArchiveFilterExpressionProtocol {
    public let targetDate: Date
    public let operatorType: ComparisonOperator
    public let rawDurationString: String?
    
    public init(targetDate: Date, operatorType: ComparisonOperator = .lessThan, rawDurationString: String? = nil) {
        self.targetDate = targetDate
        self.operatorType = operatorType
        self.rawDurationString = rawDurationString
    }
    
    public init?(dateSpec: String, operatorType: ComparisonOperator = .lessThan, referenceDate: Date = Date()) {
        guard let (parsedDate, effectiveOp) = Self.parseDateSpec(dateSpec, defaultOp: operatorType, referenceDate: referenceDate) else {
            return nil
        }
        self.targetDate = parsedDate
        self.operatorType = effectiveOp
        self.rawDurationString = dateSpec
    }
    
    public static func parseDateSpec(_ spec: String, defaultOp: ComparisonOperator = .lessThan, referenceDate: Date = Date()) -> (Date, ComparisonOperator)? {
        let trimmed = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        
        // 尝试解析相对时间 (例如 7d, 24h, 30m, 1y)
        var numberPart = ""
        var unitPart = ""
        
        for char in trimmed {
            if char.isNumber || char == "." {
                numberPart.append(char)
            } else {
                unitPart.append(char)
            }
        }
        
        if let val = Double(numberPart), !unitPart.isEmpty {
            let seconds: TimeInterval
            switch unitPart.lowercased() {
            case "s", "sec": seconds = val
            case "m", "min": seconds = val * 60
            case "h", "hr": seconds = val * 3600
            case "d", "day", "days": seconds = val * 86400
            case "w", "week", "weeks": seconds = val * 7 * 86400
            case "mth", "month", "months": seconds = val * 30 * 86400
            case "y", "yr", "years": seconds = val * 365 * 86400
            default: return nil
            }
            
            // modified:<7d  => 修改时间在 7 天内 => entry.date >= refDate - 7d (运算符映射: <7d 对应 >= (now - 7d))
            // modified:>30d => 修改时间在 30 天前 => entry.date <= refDate - 30d (运算符映射: >30d 对应 <= (now - 30d))
            let calculatedDate = referenceDate.addingTimeInterval(-seconds)
            let mappedOp: ComparisonOperator
            switch defaultOp {
            case .lessThan, .lessThanOrEqual:
                mappedOp = .greaterThanOrEqual
            case .greaterThan, .greaterThanOrEqual:
                mappedOp = .lessThanOrEqual
            case .equals:
                mappedOp = .equals
            case .notEquals:
                mappedOp = .notEquals
            }
            return (calculatedDate, mappedOp)
        }
        
        // 尝试 ISO8601 日期解析
        let formatter = ISO8601DateFormatter()
        if let isoDate = formatter.date(from: trimmed) {
            return (isoDate, defaultOp)
        }
        
        // 尝试 yyyy-MM-dd 日期解析
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let date = df.date(from: trimmed) {
            return (date, defaultOp)
        }
        
        return nil
    }
    
    public func evaluate(entry: ArchiveEntry) -> Bool {
        guard let entryDate = entry.modificationDate else {
            return false
        }
        switch operatorType {
        case .greaterThan: return entryDate > targetDate
        case .lessThan: return entryDate < targetDate
        case .greaterThanOrEqual: return entryDate >= targetDate
        case .lessThanOrEqual: return entryDate <= targetDate
        case .equals: return abs(entryDate.timeIntervalSince(targetDate)) < 1.0
        case .notEquals: return abs(entryDate.timeIntervalSince(targetDate)) >= 1.0
        }
    }
    
    public var dslDescription: String {
        if let spec = rawDurationString {
            return "modified:\(spec)"
        }
        return "modified:\(operatorType.symbol)\(targetDate.timeIntervalSince1970)"
    }
}
