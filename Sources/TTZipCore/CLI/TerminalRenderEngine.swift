import Foundation

/// 终端色彩模式
public enum TerminalColorMode: Sendable {
    case disabled
    case ansi16
    case ansi256
    case trueColor
}

/// 终端自适应渲染引擎 (TTY Adaptive & 60Hz Throttled Render Engine)
public final class TerminalRenderEngine: @unchecked Sendable {
    public static let shared = TerminalRenderEngine()
    
    private let lock = NSLock()
    public let isInteractiveTTY: Bool
    public let colorMode: TerminalColorMode
    
    private var lastRenderNanos: UInt64 = 0
    private let minRenderIntervalNanos: UInt64 = 16_666_666 // ~60Hz (16.6ms)
    
    private init() {
        let isTTY = (isatty(STDOUT_FILENO) != 0)
        self.isInteractiveTTY = isTTY
        
        // 检查 NO_COLOR 与色彩支持
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil || !isTTY {
            self.colorMode = .disabled
        } else if let colorTerm = ProcessInfo.processInfo.environment["COLORTERM"],
                  colorTerm == "truecolor" || colorTerm == "24bit" {
            self.colorMode = .trueColor
        } else if ProcessInfo.processInfo.environment["TERM"] == "dumb" {
            self.colorMode = .disabled
        } else {
            self.colorMode = .ansi256
        }
    }
    
    /// 获取终端列宽
    public var terminalColumns: Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        if let colStr = ProcessInfo.processInfo.environment["COLUMNS"], let cols = Int(colStr), cols > 0 {
            return cols
        }
        return 80
    }
    
    /// 渲染平滑自适应进度条 (带 60Hz 单调时钟节流)
    public func renderProgress(
        fraction: Double,
        bytesProcessed: Int64,
        totalBytes: Int64,
        speedMBs: Double,
        currentFile: String,
        operation: String = "Processing",
        force: Bool = false
    ) {
        guard isInteractiveTTY else { return }
        
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        if !force && (now - lastRenderNanos < minRenderIntervalNanos) {
            lock.unlock()
            return
        }
        lastRenderNanos = now
        lock.unlock()
        
        let cols = terminalColumns
        let clampedFraction = min(max(fraction, 0.0), 1.0)
        let percent = Int(clampedFraction * 100)
        
        let speedStr = ThroughputFormatter.format(mbPerSec: speedMBs, language: TTZipLocalizationManager.shared.currentLanguage)
        let processedStr = ByteSizeFormatter.format(bytes: bytesProcessed, style: .metricSI, language: TTZipLocalizationManager.shared.currentLanguage)
        let totalStr = ByteSizeFormatter.format(bytes: totalBytes, style: .metricSI, language: TTZipLocalizationManager.shared.currentLanguage)
        
        // 构建进度信息文本
        let prefix = "[\(operation)] \(percent)%"
        let stats = "(\(processedStr)/\(totalStr) | \(speedStr))"
        
        // 计算可用进度条宽度
        let reserved = prefix.count + stats.count + 4
        let barWidth = min(max(cols - reserved, 10), 40)
        
        let filledCount = Int(Double(barWidth) * clampedFraction)
        let emptyCount = max(barWidth - filledCount, 0)
        
        let filledBar = String(repeating: "━", count: filledCount)
        let emptyBar = String(repeating: "─", count: emptyCount)
        
        let bar = "\(filledBar)\(emptyBar)"
        let output = "\r\u{001B}[2K\(prefix) [\(bar)] \(stats)"
        
        fputs(output, stdout)
        fflush(stdout)
    }
    
    /// 完成进度渲染并换行
    public func completeProgress(message: String? = nil) {
        if isInteractiveTTY {
            fputs("\r\u{001B}[2K", stdout)
            if let msg = message {
                fputs("\(msg)\n", stdout)
            }
            fflush(stdout)
        }
    }
    
    /// 输出 NDJSON 机器可读事件行 (向 stdout 发射)
    public func emitNDJSON(event: String, payload: [String: Any]) {
        var dict: [String: Any] = [
            "event": event,
            "timestamp": Date().timeIntervalSince1970
        ]
        dict[event] = payload
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let str = String(data: data, encoding: .utf8) {
            fputs("\(str)\n", stdout)
            fflush(stdout)
        }
    }
    
    /// 向 stderr 输出人类可读日志或警告 (不污染 stdout 管道)
    public func logError(_ message: String) {
        fputs("\(message)\n", stderr)
        fflush(stderr)
    }
}
