// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
@testable import TTZipCore
@testable import TTZipApp
@testable import TTZipCLI

// MARK: - Mock

private protocol TestServiceProtocol: AnyObject, Sendable {
    func execute() -> String
}

private final class TestSingletonService: TestServiceProtocol, @unchecked Sendable {
    let uuid = UUID()
    func execute() -> String { "SingletonService-\(uuid.uuidString)" }
}

private final class TestTransientService: TestServiceProtocol, @unchecked Sendable {
    let uuid = UUID()
    func execute() -> String { "TransientService-\(uuid.uuidString)" }
}

private final class TestScopedService: TestServiceProtocol, @unchecked Sendable {
    let uuid = UUID()
    func execute() -> String { "ScopedService-\(uuid.uuidString)" }
}

private final class MockEngineFacade: TTZipEngineFacading, @unchecked Sendable {
    func quickCompress(
        inputs: [String],
        outputPath: String,
        format: ArchiveCompressionFormat,
        level: ArchiveCompressionLevel,
        password: String?,
        splitSize: Int64?,
        filterOptions: ArchiveFilterOptions,
        advancedOptions: ArchiveAdvancedOptions?,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ArchiveOperationResult {
        return ArchiveOperationResult(
            outputPath: outputPath,
            originalBytes: 500,
            compressedBytes: 100,
            durationSeconds: 0.1,
            throughputMBs: 1.0
        )
    }
    
    func quickExtract(
        archivePath: String,
        destinationDir: String,
        password: String?,
        autoVaultUnlock: Bool,
        progress: (@Sendable (ArchiveProgress) -> Void)?
    ) async throws -> ExtractResult {
        return ExtractResult(archivePath: archivePath, destinationDir: destinationDir, durationSeconds: 0.1)
    }
    
    func extractSingleEntry(archivePath: String, entryPath: String, destinationDir: String, password: String?) async throws {}
    
    func inspectArchive(archivePath: String, password: String?, autoVaultUnlock: Bool) async throws -> ArchiveInspectionResult {
        return ArchiveInspectionResult(
            archivePath: archivePath,
            entries: [],
            treeNode: ArchiveCompositeDirectory(name: "root", path: "/"),
            securityReport: SecurityReport(isSafe: true, suspiciousFileNames: [], hasZipSlipRisk: false, detailMessage: "OK", riskLevel: .safe)
        )
    }
    
    func verifyIntegrity(archivePath: String) async throws -> HashVerificationResult {
        return HashVerificationResult(filePath: archivePath, crc32: "12345678", sha256: "abcdef")
    }
    
    func repairArchive(damagedPath: String, outputPath: String) async throws -> Int { 0 }
    
    func recoverPassword(archivePath: String, dictionary: [String]) async throws -> PasswordRecoveryResult {
        return PasswordRecoveryResult(foundPassword: "MOCK_PASSWORD", totalAttempts: 1, durationSeconds: 0.01)
    }
    
    func recoverPassword(archivePath: String, dictionary: [String], stateMachine: ArchiveTaskStateMachine?) async throws -> PasswordRecoveryResult {
        return PasswordRecoveryResult(foundPassword: "MOCK_PASSWORD", totalAttempts: 1, durationSeconds: 0.01)
    }
    
    var historyManager: CommandHistoryManager { CommandHistoryManager.shared }
    var canUndoCommand: Bool { false }
    var canRedoCommand: Bool { false }
    func executeCommand(_ command: ArchiveCommandProtocol) async throws -> CommandResult { CommandResult(commandId: UUID().uuidString, success: true, message: "OK") }
    func undoCommand() async throws -> CommandResult? { nil }
    func redoCommand() async throws -> CommandResult? { nil }
    func undoLastCommand() async throws -> CommandResult? { nil }
    func redoLastCommand() async throws -> CommandResult? { nil }
    
    func createTaskStateMachine(taskName: String, totalBytes: Int64) -> ArchiveTaskStateMachine { ArchiveTaskStateMachine() }
    func getTaskStateMachine(id: UUID) -> ArchiveTaskStateMachine? { nil }
    func pauseTask(id: UUID) throws {}
    func resumeTask(id: UUID) throws {}
    func cancelTask(id: UUID) throws {}
    
    func performTemplateWorkflow(context: ArchiveTemplateContext) throws -> WorkflowResult { WorkflowResult(isSuccess: true) }
    func performTemplateWorkflowAsync(context: ArchiveTemplateContext) async throws -> WorkflowResult { WorkflowResult(isSuccess: true) }
    func getTemplateEngine(for format: ArchiveCompressionFormat) -> BaseArchiveEngineTemplate { ArchiveEngineTemplateRegistry.shared.template(for: format) }
    
    func operationAbstraction(for format: ArchiveCompressionFormat) -> ArchiveOperationAbstraction { ArchiveEngineFactory.makeOperationAbstraction(for: format) }
    func decoratedImplementor(
        for format: ArchiveCompressionFormat,
        password: String?,
        splitSize: Int64?,
        progressHandler: (@Sendable (ArchiveProgress) -> Void)?,
        enableChecksum: Bool,
        enableMetrics: Bool
    ) -> ArchiveEngineImplementorProtocol {
        ArchiveEngineFactory.makeDecoratedImplementor(for: format)
    }
}

// MARK: - DependencyInjectionPatternTests

final class DependencyInjectionPatternTests: XCTestCase {
    
    var testContainer: DependencyContainer!
    
    override func setUp() {
        super.setUp()
        testContainer = DependencyContainer()
    }
    
    override func tearDown() {
        testContainer.reset()
        testContainer = nil
        super.tearDown()
    }
    
    // 1. Singleton
    func testSingletonLifetimeResolution() {
        testContainer.register(TestServiceProtocol.self, lifetime: .singleton) { _ in
            TestSingletonService()
        }
        let s1 = testContainer.resolve(TestServiceProtocol.self)
        let s2 = testContainer.resolve(TestServiceProtocol.self)
        XCTAssertNotNil(s1)
        XCTAssertNotNil(s2)
        XCTAssertTrue(s1 === s2, "Singleton 应该多次 resolve 返回同一实例")
    }
    
    // 2. Transient
    func testTransientLifetimeResolution() {
        testContainer.register(TestServiceProtocol.self, lifetime: .transient) { _ in
            TestTransientService()
        }
        let s1 = testContainer.resolve(TestServiceProtocol.self)
        let s2 = testContainer.resolve(TestServiceProtocol.self)
        XCTAssertNotNil(s1)
        XCTAssertNotNil(s2)
        XCTAssertFalse(s1 === s2, "Transient 应该每次 resolve 创建全新实例")
    }
    
    // 3. Scoped
    func testScopedLifetimeResolution() {
        testContainer.register(TestServiceProtocol.self, lifetime: .scoped) { _ in
            TestScopedService()
        }
        let scopeA = testContainer.createScope()
        let scopeB = testContainer.createScope()
        
        let a1 = scopeA.resolve(TestServiceProtocol.self)
        let a2 = scopeA.resolve(TestServiceProtocol.self)
        let b1 = scopeB.resolve(TestServiceProtocol.self)
        
        XCTAssertTrue(a1 === a2, "同一 Scope 内应该复用同一个实例")
        XCTAssertFalse(a1 === b1, "不同 Scope 间应该相互隔离")
    }
    
    // 4. @Injected
    func testInjectedPropertyWrapper() {
        testContainer.register(TestServiceProtocol.self, lifetime: .singleton) { _ in
            TestSingletonService()
        }
        
        struct Component {
            @Injected var service: TestServiceProtocol
            init(container: DependencyContainer) {
                self._service = Injected(container: container)
            }
        }
        
        let comp = Component(container: testContainer)
        XCTAssertNotNil(comp.service)
        XCTAssertTrue(comp.service.execute().contains("SingletonService"))
    }
    
    // 5. @InjectedOptional
    func testInjectedOptionalPropertyWrapper() {
        struct Component {
            @InjectedOptional var service: TestServiceProtocol?
            init(container: DependencyContainer) {
                self._service = InjectedOptional(container: container)
            }
        }
        
        let comp1 = Component(container: testContainer)
        XCTAssertNil(comp1.service, "未注册时应当返回 nil")
        
        testContainer.register(TestServiceProtocol.self, lifetime: .singleton) { _ in TestSingletonService() }
        let comp2 = Component(container: testContainer)
        XCTAssertNotNil(comp2.service, "已注册时应当正确注入实例")
    }
    
    // 6. Mock
    func testMockOverrideInTestMode() {
        testContainer.register(TTZipEngineFacading.self, lifetime: .singleton) { _ in
            TTZipEngineFacade.shared
        }
        let realEngine = testContainer.resolveRequired(TTZipEngineFacading.self)
        XCTAssertTrue(realEngine is TTZipEngineFacade)
        
        // Mock
        testContainer.register(TTZipEngineFacading.self, lifetime: .singleton) { _ in
            MockEngineFacade()
        }
        let mockEngine = testContainer.resolveRequired(TTZipEngineFacading.self)
        XCTAssertTrue(mockEngine is MockEngineFacade)
    }
    
    // 7. unregister
    func testUnregisterService() {
        testContainer.register(TestServiceProtocol.self, lifetime: .singleton) { _ in TestSingletonService() }
        XCTAssertNotNil(testContainer.resolve(TestServiceProtocol.self))
        
        testContainer.unregister(TestServiceProtocol.self)
        XCTAssertNil(testContainer.resolve(TestServiceProtocol.self), "注销后应当无法 resolve")
    }
    
    // 8. reset
    func testResetContainer() {
        testContainer.register(TestServiceProtocol.self, lifetime: .singleton) { _ in TestSingletonService() }
        XCTAssertNotNil(testContainer.resolve(TestServiceProtocol.self))
        
        testContainer.reset()
        XCTAssertNil(testContainer.resolve(TestServiceProtocol.self), "重置后全量注册数据应当被清空")
    }
    
    // 9. resolveRequired
    func testResolveRequiredSuccess() {
        testContainer.register(TestServiceProtocol.self, lifetime: .singleton) { _ in TestSingletonService() }
        let s = testContainer.resolveRequired(TestServiceProtocol.self)
        XCTAssertNotNil(s)
    }
    
    // 10. 100+ resolve (Zero Deadlock & Zero Race)
    func testHighConcurrencyParallelResolvePressureTest() {
        testContainer.register(TestServiceProtocol.self, lifetime: .singleton) { _ in TestSingletonService() }
        
        let expectation = expectation(description: "ConcurrentResolve")
        let totalThreads = 150
        let group = DispatchGroup()
        
        let container = testContainer!
        for _ in 0..<totalThreads {
            group.enter()
            DispatchQueue.global().async {
                let s = container.resolve(TestServiceProtocol.self)
                XCTAssertNotNil(s)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // 11. (Zero Deadlock & Race)
    func testHighConcurrencyParallelRegisterAndResolve() {
        let expectation = expectation(description: "ConcurrentRegisterAndResolve")
        let totalCount = 100
        let group = DispatchGroup()
        let container = testContainer!
        
        for i in 0..<totalCount {
            group.enter()
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    container.register(TestServiceProtocol.self, lifetime: .transient) { _ in TestTransientService() }
                } else {
                    _ = container.resolve(TestServiceProtocol.self)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // 12. 20+
    func testRegisterAllServicesBootstrapping() {
        TTZipServiceRegistrar.registerAllServices(container: testContainer)
        
        XCTAssertNotNil(testContainer.resolve(TTZipEngineFacading.self))
        XCTAssertNotNil(testContainer.resolve((any ArchivePresetRepositoryProtocol).self))
        XCTAssertNotNil(testContainer.resolve(KeychainPasswordRepository.self))
        XCTAssertNotNil(testContainer.resolve((any ArchiveHistoryRepositoryProtocol).self))
        XCTAssertNotNil(testContainer.resolve(ArchiveMediatorProtocol.self))
        XCTAssertNotNil(testContainer.resolve(ArchiveEventCenterProtocol.self))
        XCTAssertNotNil(testContainer.resolve(ArchiveWorkerPool.self))
        XCTAssertNotNil(testContainer.resolve(ArchiveTaskDispatcher.self))
        XCTAssertNotNil(testContainer.resolve(ArchiveInspectionCacheProxy.self))
        XCTAssertNotNil(testContainer.resolve(SecurityProtectionProxy.self))
        XCTAssertNotNil(testContainer.resolve(CharsetDetectionStrategyContext.self))
        XCTAssertNotNil(testContainer.resolve(ArchiveTaskStateMachine.self))
        XCTAssertNotNil(testContainer.resolve(PresetEditorCaretaker.self))
        XCTAssertNotNil(testContainer.resolve(AppViewStateCaretaker.self))
        XCTAssertNotNil(testContainer.resolve(TaskCheckpointCaretaker.self))
        XCTAssertNotNil(testContainer.resolve(PresetManager.self))
        XCTAssertNotNil(testContainer.resolve(PasswordVaultManager.self))
        XCTAssertNotNil(testContainer.resolve(CommandHistoryManager.self))
        XCTAssertNotNil(testContainer.resolve(ArchiveBatchFacade.self))
        XCTAssertNotNil(testContainer.resolve(SmartLoggingProxy.self))
        XCTAssertNotNil(testContainer.resolve(LicenseManager.self))
    }
    
    // 13. TTZipEngineFacading
    func testEngineFacadeInjection() {
        TTZipServiceRegistrar.registerAllServices(container: testContainer)
        let facade = testContainer.resolveRequired(TTZipEngineFacading.self)
        XCTAssertTrue(facade is TTZipEngineFacade)
    }
    
    // 14. Repositories
    func testRepositoriesInjection() {
        TTZipServiceRegistrar.registerAllServices(container: testContainer)
        let presetRepo = testContainer.resolveRequired((any ArchivePresetRepositoryProtocol).self)
        let historyRepo = testContainer.resolveRequired((any ArchiveHistoryRepositoryProtocol).self)
        XCTAssertTrue(presetRepo is UserDefaultsPresetRepository)
        XCTAssertTrue(historyRepo is JSONFileArchiveHistoryRepository)
    }
    
    // 15. Mediator & EventCenter
    func testMediatorAndEventCenterInjection() {
        TTZipServiceRegistrar.registerAllServices(container: testContainer)
        let mediator = testContainer.resolveRequired(ArchiveMediatorProtocol.self)
        let eventCenter = testContainer.resolveRequired(ArchiveEventCenterProtocol.self)
        XCTAssertTrue(mediator is ArchiveAppMediator)
        XCTAssertTrue(eventCenter is ArchiveEventCenter)
    }
    
    // 16. Proxies & Strategy Context
    func testProxiesAndStrategyContextInjection() {
        TTZipServiceRegistrar.registerAllServices(container: testContainer)
        let cacheProxy = testContainer.resolveRequired(ArchiveInspectionCacheProxy.self)
        let secProxy = testContainer.resolveRequired(SecurityProtectionProxy.self)
        let charsetCtx = testContainer.resolveRequired(CharsetDetectionStrategyContext.self)
        
        XCTAssertTrue(cacheProxy === ArchiveInspectionCacheProxy.shared)
        XCTAssertTrue(secProxy === SecurityProtectionProxy.shared)
        XCTAssertTrue(charsetCtx === CharsetDetectionStrategyContext.shared)
    }
    
    // 17. Caretakers
    func testCaretakersInjection() {
        TTZipServiceRegistrar.registerAllServices(container: testContainer)
        let presetCaretaker = testContainer.resolveRequired(PresetEditorCaretaker.self)
        let appCaretaker = testContainer.resolveRequired(AppViewStateCaretaker.self)
        let checkpointCaretaker = testContainer.resolveRequired(TaskCheckpointCaretaker.self)
        
        XCTAssertNotNil(presetCaretaker)
        XCTAssertNotNil(appCaretaker)
        XCTAssertNotNil(checkpointCaretaker)
    }
    
    // 18. CLICommandRouter
    func testCLICommandRouterInjectionIntegration() {
        TTZipServiceRegistrar.registerAllServices(container: DependencyContainer.shared)
        
        struct RouterTester {
            @Injected var facade: TTZipEngineFacading
            @Injected var securityProxy: SecurityProtectionProxy
            @Injected var taskDispatcher: ArchiveTaskDispatcher
        }
        
        let tester = RouterTester()
        XCTAssertNotNil(tester.facade)
        XCTAssertNotNil(tester.securityProxy)
        XCTAssertNotNil(tester.taskDispatcher)
    }
    
    // 19. ViewModel
    @MainActor
    func testViewModelsInjectionIntegration() {
        TTZipServiceRegistrar.registerAllServices(container: DependencyContainer.shared)
        
        let presetVM = PresetWorkspaceViewModel()
        let vaultVM = PasswordVaultViewModel()
        
        XCTAssertNotNil(presetVM.manager)
        XCTAssertNotNil(presetVM.appMediator)
        XCTAssertNotNil(vaultVM.repository)
        XCTAssertNotNil(vaultVM.manager)
    }
}
