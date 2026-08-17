import Foundation

/// 线程安全的全局 DateFormatter 缓存，避免高频创建 DateFormatter 造成的性能损耗
public final class DateFormatterCache: @unchecked Sendable {
    public static let shared = DateFormatterCache()
    
    private var formatters: [String: DateFormatter] = [:]
    private let lock = NSLock()
    
    private let shortDateTimeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt
    }()
    
    private init() {}
    
    public func string(fromShortDateTime date: Date) -> String {
        lock.lock()
        defer { lock.unlock() }
        return shortDateTimeFormatter.string(from: date)
    }
    
    public func string(from date: Date, format: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        let formatter = getFormatter(for: format)
        return formatter.string(from: date)
    }
    
    public func date(from string: String, format: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let formatter = getFormatter(for: format)
        return formatter.date(from: string)
    }
    
    public func formatter(for format: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        return getFormatter(for: format)
    }
    
    private func getFormatter(for format: String) -> DateFormatter {
        if let existing = formatters[format] {
            return existing
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }
}
