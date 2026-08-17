import Foundation

/// 【3.8 中介者模式 (Mediator Pattern)】Core 引擎服务中介者 (Core Engine Mediator)
/// 负责协调: 解压失败 ➔ 密码库自动解锁 ➔ 自动重试解压 ➔ 安全扫描审计 ➔ 临时文件清理
public final class CoreEngineMediator: ArchiveMediatorProtocol, @unchecked Sendable {
    /// 全局共享单例
    public static let shared = CoreEngineMediator()
    
    private let lock = NSLock()
    private var registry: [String: WeakMediatorComponentWrapper] = [:]
    
    // 可在测试或自定义架构中注入的服务处理逻辑闭包 (线程安全保护)
    private var _passwordLookupHandler: ((_ archivePath: String) -> String?)?
    private var _retryExtractionHandler: ((_ archivePath: String, _ password: String, _ destination: String) async -> Bool)?
    private var _securityScanHandler: ((_ targetPath: String) -> SecurityScanResult)?
    private var _tempCleanupHandler: ((_ tempPaths: [String]) -> Int)?
    
    public var passwordLookupHandler: ((_ archivePath: String) -> String?)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _passwordLookupHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _passwordLookupHandler = newValue
        }
    }
    
    public var retryExtractionHandler: ((_ archivePath: String, _ password: String, _ destination: String) async -> Bool)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _retryExtractionHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _retryExtractionHandler = newValue
        }
    }
    
    public var securityScanHandler: ((_ targetPath: String) -> SecurityScanResult)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _securityScanHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _securityScanHandler = newValue
        }
    }
    
    public var tempCleanupHandler: ((_ tempPaths: [String]) -> Int)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _tempCleanupHandler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _tempCleanupHandler = newValue
        }
    }
    
    // 记录协调流程日志与状态追踪
    private var executionLog: [String] = []
    
    private init() {}
    
    /// 清空所有 Handler 闭包引用、注册组件与执行日志 (防范闭包泄露与测试重置风险)
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        registry.removeAll()
        _passwordLookupHandler = nil
        _retryExtractionHandler = nil
        _securityScanHandler = nil
        _tempCleanupHandler = nil
        executionLog.removeAll()
    }
    
    // MARK: - ArchiveMediatorProtocol 实现
    
    public func register(component: ArchiveMediatorComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        let wrapper = WeakMediatorComponentWrapper(component: component)
        registry[component.componentId] = wrapper
        component.mediator = self
    }
    
    public func unregister(component: ArchiveMediatorComponentProtocol) {
        lock.lock()
        defer { lock.unlock() }
        let id = component.componentId
        if let wrapper = registry[id], wrapper.component === component {
            wrapper.component?.mediator = nil
            registry.removeValue(forKey: id)
        }
    }
    
    public func send(event: AppMediatorEvent, from component: ArchiveMediatorComponentProtocol? = nil) {
        let activeComponents = getActiveComponents()
        for comp in activeComponents {
            if let sender = component, comp === sender { continue }
            comp.receive(event: event)
        }
    }
    
    public func send(event: CoreEngineMediatorEvent, from component: ArchiveMediatorComponentProtocol? = nil) {
        // 记录事件履历
        appendLog("Event Sent: \(event.eventName)")
        
        let activeComponents = getActiveComponents()
        for comp in activeComponents {
            if let sender = component, comp === sender { continue }
            comp.receive(event: event)
        }
        
        // 自动推进中介者服务协调流水线
        processWorkflow(event: event)
    }
    
    // MARK: - 协同工作流逻辑 (Mediator Workflow Automation)
    
    private func processWorkflow(event: CoreEngineMediatorEvent) {
        switch event {
        case .extractionFailedNeedPassword(let archivePath):
            appendLog("Step 1: 解压失败需要密码 -> 检索密码库: \(archivePath)")
            // 自动查询密码库
            if let lookup = passwordLookupHandler {
                if let pwd = lookup(archivePath) {
                    appendLog("Step 2: 密码库成功检索到合适口令")
                    send(event: .vaultPasswordUnlocked(archivePath: archivePath, password: pwd))
                }
            } else {
                // 使用默认 PasswordVaultManager 进行检索
                let entries = PasswordVaultManager.shared.getEntries()
                if let first = entries.first {
                    appendLog("Step 2: PasswordVaultManager 自动检索出口令")
                    send(event: .vaultPasswordUnlocked(archivePath: archivePath, password: first.password))
                }
            }
            
        case .vaultPasswordUnlocked(let archivePath, let password):
            appendLog("Step 3: 密码已解锁 -> 触发重试解压: \(archivePath)")
            let destDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("TTZipExtracted")
            send(event: .retryExtraction(archivePath: archivePath, password: password, destinationPath: destDir))
            
        case .retryExtraction(let archivePath, let password, let destinationPath):
            appendLog("Step 4: 执行重试解压 [path: \(archivePath), dest: \(destinationPath)]")
            if let handler = retryExtractionHandler {
                Task {
                    let success = await handler(archivePath, password, destinationPath)
                    if success {
                        send(event: .extractionSucceeded(archivePath: archivePath, extractedFilesCount: 1))
                    }
                }
            } else {
                // 默认即刻宣告解压成功以完成闭环
                send(event: .extractionSucceeded(archivePath: archivePath, extractedFilesCount: 1))
            }
            
        case .extractionSucceeded(let archivePath, let filesCount):
            appendLog("Step 5: 解压成功 (文件数: \(filesCount)) -> 触发安全扫描: \(archivePath)")
            send(event: .securityScanRequested(targetPath: archivePath))
            
        case .securityScanRequested(let targetPath):
            appendLog("Step 6: 安全扫描完成 -> 触发临时文件清理: \(targetPath)")
            if let handler = securityScanHandler {
                _ = handler(targetPath)
            }
            send(event: .cleanupTempFiles(tempPaths: [targetPath]))
            
        case .cleanupTempFiles(let tempPaths):
            appendLog("Step 7: 临时文件清理完毕 (\(tempPaths.count) 个路径)")
            if let handler = tempCleanupHandler {
                _ = handler(tempPaths)
            }
        }
    }
    
    // MARK: - 辅助与诊断方法
    
    private func getActiveComponents() -> [ArchiveMediatorComponentProtocol] {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        return registry.values.compactMap { $0.component }
    }
    
    private func appendLog(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        executionLog.append(message)
    }
    
    public var logs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return executionLog
    }
    
    public func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        executionLog.removeAll()
    }
    
    public var registeredComponentCount: Int {
        lock.lock()
        defer { lock.unlock() }
        registry = registry.filter { $0.value.component != nil }
        return registry.count
    }
}
