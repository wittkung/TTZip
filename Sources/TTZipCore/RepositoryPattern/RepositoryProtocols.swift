import Foundation

/// 归档任务历史记录领域实体模型 (Domain Model)
public struct ArchiveTaskRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var commandName: String
    public var archivePath: String
    public var targetPath: String
    public var isSuccess: Bool
    public var timestamp: Date
    public var fileSizeByte: Int64
    
    public init(
        id: UUID = UUID(),
        commandName: String,
        archivePath: String,
        targetPath: String,
        isSuccess: Bool,
        timestamp: Date = Date(),
        fileSizeByte: Int64 = 0
    ) {
        self.id = id
        self.commandName = commandName
        self.archivePath = archivePath
        self.targetPath = targetPath
        self.isSuccess = isSuccess
        self.timestamp = timestamp
        self.fileSizeByte = fileSizeByte
    }
}

/// 密码库实体模型类型别名
public typealias VaultPasswordEntry = PasswordVaultEntry

/// 通用仓储泛型接口 Protocol (Generic Repository Pattern)
/// 规范化实体模型的 CRUD 数据存取流程，解耦领域实体与底层持久化介质
public protocol ArchiveRepositoryProtocol<DomainModel>: Sendable where DomainModel: Identifiable, DomainModel: Sendable {
    associatedtype DomainModel
    
    /// 根据 ID 检索单个实体模型
    func fetch(id: DomainModel.ID) throws -> DomainModel?
    
    /// 检索所有实体模型列表
    func fetchAll() throws -> [DomainModel]
    
    /// 保存或更新单个实体模型
    func save(_ entity: DomainModel) throws
    
    /// 根据 ID 删除单个实体模型
    func delete(id: DomainModel.ID) throws
    
    /// 删除所有实体模型
    func deleteAll() throws
}

/// 预设特化仓储协议 Protocol
public protocol ArchivePresetRepositoryProtocol: ArchiveRepositoryProtocol where DomainModel == CompressionPreset {
    /// 按预设名称精确或模糊匹配查找
    func fetchByName(_ name: String) throws -> CompressionPreset?
    
    /// 重置还原为系统默认预设方案
    func resetToDefaults() throws
    
    /// 基于原型模式克隆衍生全新预设方案
    func duplicate(id: UUID, newName: String?) throws -> CompressionPreset?
}

/// 密码库安全特化仓储协议 Protocol
public protocol PasswordVaultRepositoryProtocol: ArchiveRepositoryProtocol where DomainModel == PasswordVaultEntry {
    /// 按安全分类检索口令条目
    func search(category: String) throws -> [PasswordVaultEntry]
    
    /// 增加并更新口令使用频率与最近使用时间戳
    func recordUsage(id: UUID) throws
    
    /// 主口令当前解锁状态
    var isUnlocked: Bool { get }
    
    /// 使用主口令解锁密码库
    func unlock(masterPassword: String) throws -> Bool
    
    /// 锁定密码库（抹除内存高敏口令）
    func lock()
}

/// 归档历史记录特化仓储协议 Protocol
public protocol ArchiveHistoryRepositoryProtocol: ArchiveRepositoryProtocol where DomainModel == ArchiveTaskRecord {
    /// 获取按时间降序排列的前 N 条历史执行记录
    func fetchRecent(limit: Int) throws -> [ArchiveTaskRecord]
    
    /// 按执行成功/失败状态过滤历史记录
    func fetchByStatus(isSuccess: Bool) throws -> [ArchiveTaskRecord]
}
