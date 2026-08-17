import XCTest
@testable import TTZipApp
@testable import TTZipCore

@MainActor
final class AppViewStateSubStateTests: XCTestCase {
    
    func testAppViewStateSubStateIsolationAndForwarding() {
        let navState = NavigationState()
        let explorerState = ArchiveExplorerState()
        let taskState = TaskExecutionState()
        let overlayState = OverlayState()
        
        let coordinator = AppViewState(
            navigationState: navState,
            explorerState: explorerState,
            taskState: taskState,
            overlayState: overlayState
        )
        
        // 1. 验证 NavigationState 变更
        navState.activeTab = .compressWorkspace
        XCTAssertEqual(coordinator.activeTab, .compressWorkspace)
        
        coordinator.activeTab = .vault
        XCTAssertEqual(navState.activeTab, .vault)
        
        // 2. 验证 ArchiveExplorerState 变更
        explorerState.currentArchivePath = "/tmp/test.zip"
        XCTAssertEqual(coordinator.currentArchivePath, "/tmp/test.zip")
        
        coordinator.currentArchivePath = "/tmp/new.7z"
        XCTAssertEqual(explorerState.currentArchivePath, "/tmp/new.7z")
        
        // 3. 验证 TaskExecutionState 变更
        taskState.statusMessage = "正在解压..."
        XCTAssertEqual(coordinator.statusMessage, "正在解压...")
        
        coordinator.statusMessage = "完成"
        XCTAssertEqual(taskState.statusMessage, "完成")
        
        // 4. 验证 OverlayState 变更
        overlayState.showCompressModal = true
        XCTAssertTrue(coordinator.showCompressModal)
        
        coordinator.showCompressModal = false
        XCTAssertFalse(overlayState.showCompressModal)
    }
}
