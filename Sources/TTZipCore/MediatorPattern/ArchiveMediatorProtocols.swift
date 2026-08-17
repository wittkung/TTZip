import Foundation

// MARK: - 【3.8 中介者模式 (Mediator Pattern)】事件类型与数据载荷定义

/// GUI UI 组件交互事件枚举
public enum AppMediatorEvent: Sendable, Equatable {
    case requestPasswordPrompt(archivePath: String)
    case passwordUnlocked(archivePath: String, password: String)
    case requestCompression(inputPaths: [String], outputPath: String)
    case compressionCompleted(outputPath: String)
    case requestExtraction(archivePath: String, destinationPath: String)
    case extractionFailed(archivePath: String, error: String)
    case presetSelected(presetId: String)
    case securityThreatDetected(threatPath: String, reason: String)
    case taskStateChanged(taskId: String, stateDescription: String)
    case openTab(tabIndex: Int)

    /// 事件描述或分类
    public var eventName: String {
        switch self {
        case .requestPasswordPrompt: return "requestPasswordPrompt"
        case .passwordUnlocked: return "passwordUnlocked"
        case .requestCompression: return "requestCompression"
        case .compressionCompleted: return "compressionCompleted"
        case .requestExtraction: return "requestExtraction"
        case .extractionFailed: return "extractionFailed"
        case .presetSelected: return "presetSelected"
        case .securityThreatDetected: return "securityThreatDetected"
        case .taskStateChanged: return "taskStateChanged"
        case .openTab: return "openTab"
        }
    }
}

/// Core 引擎服务协同事件枚举
public enum CoreEngineMediatorEvent: Sendable, Equatable {
    case extractionFailedNeedPassword(archivePath: String)
    case vaultPasswordUnlocked(archivePath: String, password: String)
    case retryExtraction(archivePath: String, password: String, destinationPath: String)
    case extractionSucceeded(archivePath: String, extractedFilesCount: Int)
    case securityScanRequested(targetPath: String)
    case cleanupTempFiles(tempPaths: [String])

    /// 事件描述或分类
    public var eventName: String {
        switch self {
        case .extractionFailedNeedPassword: return "extractionFailedNeedPassword"
        case .vaultPasswordUnlocked: return "vaultPasswordUnlocked"
        case .retryExtraction: return "retryExtraction"
        case .extractionSucceeded: return "extractionSucceeded"
        case .securityScanRequested: return "securityScanRequested"
        case .cleanupTempFiles: return "cleanupTempFiles"
        }
    }
}

// MARK: - 中介者与组件核心协议定义

/// 中介者协议定义 (Mediator Protocol)
public protocol ArchiveMediatorProtocol: AnyObject, Sendable {
    /// 注册组件到中介者
    func register(component: ArchiveMediatorComponentProtocol)
    
    /// 从中介者注销组件
    func unregister(component: ArchiveMediatorComponentProtocol)
    
    /// 发送 GUI 应用事件
    func send(event: AppMediatorEvent, from component: ArchiveMediatorComponentProtocol?)
    
    /// 发送 Core 引擎服务协同事件
    func send(event: CoreEngineMediatorEvent, from component: ArchiveMediatorComponentProtocol?)
}

/// 协同组件协议定义 (Mediator Component Protocol)
public protocol ArchiveMediatorComponentProtocol: AnyObject, Sendable {
    /// 组件唯一标识符
    var componentId: String { get }
    
    /// 所属中介者弱引用 (或可设置句柄)
    var mediator: ArchiveMediatorProtocol? { get set }
    
    /// 接收 GUI UI 组件事件通知
    func receive(event: AppMediatorEvent)
    
    /// 接收 Core 引擎服务协同事件通知
    func receive(event: CoreEngineMediatorEvent)
}

// MARK: - 协议默认实现 (Default Implementations)

extension ArchiveMediatorComponentProtocol {
    public var componentId: String {
        String(reflecting: type(of: self))
    }

    public func receive(event: AppMediatorEvent) {}
    public func receive(event: CoreEngineMediatorEvent) {}
}
