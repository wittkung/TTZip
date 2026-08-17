import Foundation

/// 统一原型拷贝协议 (Prototype Pattern Protocol)
/// 强制实现该协议的类型提供高效、深拷贝且逻辑隔离的 clone() 方法
public protocol PrototypeCopyable {
    /// 创建并返回当前对象或结构的独立克隆副本
    func clone() -> Self
}
