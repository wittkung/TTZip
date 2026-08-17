import Foundation
import Combine

#if MAS_BUILD
/// Mac App Store (MAS) 沙盒构建：更新由 App Store 系统托管，禁用 Sparkle
@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()
    
    @Published public var canCheckForUpdates: Bool = false
    
    private init() {}
    
    public func checkForUpdates() {
        // MAS 构建版由 Mac App Store 统一管理升级
    }
}
#else
/// Direct 独立分发渠道：集成 Sparkle 2.0 自动更新框架
import Sparkle

@MainActor
public final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    public static let shared = UpdateManager()
    
    @Published public var canCheckForUpdates: Bool = false
    
    private var updaterController: SPUStandardUpdaterController?
    
    private override init() {
        super.init()
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        self.updaterController = controller
        self.canCheckForUpdates = controller.updater.canCheckForUpdates
    }
    
    public func checkForUpdates() {
        updaterController?.checkForUpdates(self)
    }
}
#endif
