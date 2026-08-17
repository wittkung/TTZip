import Foundation

/// 遵循 Darwin / BSD POSIX <sysexits.h> 规范的 CLI 强类型退出代码
public enum CLIExitCode: Int32, Sendable {
    /// 成功执行 (EX_OK)
    case ok = 0
    
    /// 命令行语法或参数使用错误 (EX_USAGE)
    case usage = 64
    
    /// 归档数据格式损坏、Magic 魔数不匹配、CRC 校验失败或密码错误 (EX_DATAERR)
    case dataError = 65
    
    /// 输入文件或目录不存在、不可读 (EX_NOINPUT)
    case noInput = 66
    
    /// 格式引擎或硬件加速不可用 (EX_UNAVAILABLE)
    case unavailable = 69
    
    /// 内部软件断言失败或未处理异常 (EX_SOFTWARE)
    case software = 70
    
    /// 无法创建输出文件或目录 (EX_CANTCREAT)
    case cantCreate = 73
    
    /// 物理输入/输出故障或管道断裂 EPIPE (EX_IOERR)
    case ioError = 74
    
    /// 目标路径权限拒绝 (EX_NOPERM)
    case noPermission = 77
    
    /// 用户按下 Ctrl+C (SIGINT = 128 + 2)
    case sigint = 130
    
    /// 终止当前进程并返回标准状态码
    public func exit() -> Never {
        Darwin.exit(self.rawValue)
    }
}
