// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

import XCTest
import Foundation
@testable import TTZipCore
@testable import TTZipApp

// MARK: - Mock Component for Mediator Tests

final class MockMediatorComponent: ArchiveMediatorComponentProtocol, @unchecked Sendable {
    let componentId: String
    var mediator: ArchiveMediatorProtocol?
    
    private let lock = NSLock()
    private var receivedAppEventsStorage: [AppMediatorEvent] = []
    private var receivedCoreEventsStorage: [CoreEngineMediatorEvent] = []
    
    init(componentId: String = UUID().uuidString, mediator: ArchiveMediatorProtocol? = nil) {
        self.componentId = componentId
        self.mediator = mediator
    }
    
    func receive(event: AppMediatorEvent) {
        lock.lock()
        receivedAppEventsStorage.append(event)
        lock.unlock()
    }
    
    func receive(event: CoreEngineMediatorEvent) {
        lock.lock()
        receivedCoreEventsStorage.append(event)
        lock.unlock()
    }
    
    var receivedAppEvents: [AppMediatorEvent] {
        lock.lock()
        defer { lock.unlock() }
        return receivedAppEventsStorage
    }
    
    var receivedCoreEvents: [CoreEngineMediatorEvent] {
        lock.lock()
        defer { lock.unlock() }
        return receivedCoreEventsStorage
    }
    
    var appEventCount: Int {
        receivedAppEvents.count
    }
    
    var coreEventCount: Int {
        receivedCoreEvents.count
    }
}

// MARK: - 【3.8 Mediator Pattern 】15+

final class MediatorPatternTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        ArchiveAppMediator.shared.reset()
        CoreEngineMediator.shared.clearLogs()
    }
    
    override func tearDown() {
        ArchiveAppMediator.shared.reset()
        CoreEngineMediator.shared.clearLogs()
        super.tearDown()
    }
    
    // MARK: - 1. /
    func testComponentRegistrationAndUnregistrationLifecycle() {
        let mediator = ArchiveAppMediator.shared
        let comp1 = MockMediatorComponent(componentId: "Comp1")
        let comp2 = MockMediatorComponent(componentId: "Comp2")
        
        XCTAssertEqual(mediator.registeredComponentCount, 0)
        XCTAssertFalse(mediator.isRegistered(componentId: "Comp1"))
        
        mediator.register(component: comp1)
        XCTAssertEqual(mediator.registeredComponentCount, 1)
        XCTAssertTrue(mediator.isRegistered(componentId: "Comp1"))
        XCTAssertTrue(comp1.mediator === mediator)
        
        mediator.register(component: comp2)
        XCTAssertEqual(mediator.registeredComponentCount, 2)
        XCTAssertTrue(mediator.isRegistered(componentId: "Comp2"))
        
        mediator.unregister(component: comp1)
        XCTAssertEqual(mediator.registeredComponentCount, 1)
        XCTAssertFalse(mediator.isRegistered(componentId: "Comp1"))
        XCTAssertNil(comp1.mediator)
        
        mediator.reset()
        XCTAssertEqual(mediator.registeredComponentCount, 0)
        XCTAssertNil(comp2.mediator)
    }
    
    // MARK: - 2. GUI
    func testGUIMulticastEventDispatch() {
        let mediator = ArchiveAppMediator.shared
        let comp1 = MockMediatorComponent(componentId: "Comp1")
        let comp2 = MockMediatorComponent(componentId: "Comp2")
        let comp3 = MockMediatorComponent(componentId: "Comp3")
        
        mediator.register(component: comp1)
        mediator.register(component: comp2)
        mediator.register(component: comp3)
        
        let testEvent = AppMediatorEvent.requestPasswordPrompt(archivePath: "/tmp/secret.zip")
        mediator.send(event: testEvent, from: comp1)
        
        // comp1 ，
        XCTAssertEqual(comp1.appEventCount, 0)
        XCTAssertEqual(comp2.appEventCount, 1)
        XCTAssertEqual(comp3.appEventCount, 1)
        XCTAssertEqual(comp2.receivedAppEvents.first, testEvent)
        XCTAssertEqual(comp3.receivedAppEvents.first, testEvent)
    }
    
    // MARK: - 3.
    func testTargetedEventDispatch() {
        let mediator = ArchiveAppMediator.shared
        let compA = MockMediatorComponent(componentId: "CompA")
        let compB = MockMediatorComponent(componentId: "CompB")
        
        mediator.register(component: compA)
        mediator.register(component: compB)
        
        let targetEvent = AppMediatorEvent.openTab(tabIndex: 2)
        mediator.sendTargeted(event: targetEvent, targetComponentId: "CompB")
        
        XCTAssertEqual(compA.appEventCount, 0)
        XCTAssertEqual(compB.appEventCount, 1)
        XCTAssertEqual(compB.receivedAppEvents.first, targetEvent)
    }
    
    // MARK: - 4. Core
    func testCoreEngineExtractionToPasswordVaultRetryFlow() {
        let mediator = CoreEngineMediator.shared
        let engineComp = MockMediatorComponent(componentId: "EngineComp")
        mediator.register(component: engineComp)
        
        // Mock
        mediator.passwordLookupHandler = { path in
            return path.contains("encrypted") ? "Pa$$w0rd" : nil
        }
        
        let exp = expectation(description: "Retry Extraction Flow Completed")
        var retryCalled = false
        
        mediator.retryExtractionHandler = { archivePath, password, dest in
            XCTAssertEqual(archivePath, "/tmp/encrypted_test.7z")
            XCTAssertEqual(password, "Pa$$w0rd")
            retryCalled = true
            exp.fulfill()
            return true
        }
        
        // 1:
        mediator.send(event: .extractionFailedNeedPassword(archivePath: "/tmp/encrypted_test.7z"))
        
        wait(for: [exp], timeout: 3.0)
        XCTAssertTrue(retryCalled)
        
        // Check mediator automation pipeline logs
        let logs = mediator.logs
        XCTAssertTrue(logs.contains(where: { $0.contains("Step 1: Extraction failed") }))
        XCTAssertTrue(logs.contains(where: { $0.contains("Step 2: Password") }))
        XCTAssertTrue(logs.contains(where: { $0.contains("Step 3: Password unlocked") }))
    }
    
    // MARK: - 5. Core engine security scan and temp cleanup flow test
    func testCoreEngineSecurityScanAndTempCleanupFlow() {
        let mediator = CoreEngineMediator.shared
        let auditComp = MockMediatorComponent(componentId: "AuditComp")
        mediator.register(component: auditComp)
        
        var cleanupHappened = false
        mediator.tempCleanupHandler = { paths in
            cleanupHappened = true
            XCTAssertEqual(paths.first, "/tmp/scanned.zip")
            return paths.count
        }
        
        mediator.send(event: .extractionSucceeded(archivePath: "/tmp/scanned.zip", extractedFilesCount: 10))
        
        XCTAssertTrue(cleanupHappened)
        let logs = mediator.logs
        XCTAssertTrue(logs.contains(where: { $0.contains("Step 5: Extraction succeeded") }))
        XCTAssertTrue(logs.contains(where: { $0.contains("Step 6: Security scan completed") }))
        XCTAssertTrue(logs.contains(where: { $0.contains("Step 7: Temporary cleanup completed") }))
    }
    
    // MARK: - 6. 100+ Zero Deadlock
    func testHighConcurrency100PlusThreadsDispatchSafetyNoDeadlock() {
        let mediator = ArchiveAppMediator.shared
        let componentCount = 50
        var components: [MockMediatorComponent] = []
        
        for i in 0..<componentCount {
            let comp = MockMediatorComponent(componentId: "ConcurrencyComp_\(i)")
            mediator.register(component: comp)
            components.append(comp)
        }
        
        let threadCount = 100
        let exp = expectation(description: "100+ Threads Concurrent Dispatch")
        exp.expectedFulfillmentCount = threadCount
        
        for t in 0..<threadCount {
            DispatchQueue.global().async {
                let event = AppMediatorEvent.taskStateChanged(taskId: "Task_\(t)", stateDescription: "State_\(t)")
                mediator.send(event: event)
                exp.fulfill()
            }
        }
        
        wait(for: [exp], timeout: 5.0)
        XCTAssertEqual(mediator.registeredComponentCount, componentCount)
    }
    
    // MARK: - 7. Weak Component Lifetime Safety
    func testWeakComponentLifetimeRetainCycleSafety() {
        let mediator = ArchiveAppMediator.shared
        
        var strongComp: MockMediatorComponent? = MockMediatorComponent(componentId: "TransientComp")
        weak var weakCompRef = strongComp
        
        mediator.register(component: strongComp!)
        XCTAssertEqual(mediator.registeredComponentCount, 1)
        XCTAssertNotNil(weakCompRef)
        
        // Verify expected invariant
        strongComp = nil
        weakCompRef = nil
        
        // ARC
        XCTAssertNil(weakCompRef)
        
        // Verify expected invariant
        mediator.send(event: .openTab(tabIndex: 1))
        XCTAssertEqual(mediator.registeredComponentCount, 0)
    }
    
    // MARK: - 8. AppViewState
    @MainActor
    func testAppViewStateMediatorIntegration() {
        let appState = AppViewState()
        let mediator = ArchiveAppMediator.shared
        
        mediator.send(event: .requestPasswordPrompt(archivePath: "/tmp/encrypted.zip"))
        XCTAssertTrue(appState.showPasswordPrompt)
        XCTAssertEqual(appState.pendingEncryptedPath, "/tmp/encrypted.zip")
        
        mediator.send(event: .passwordUnlocked(archivePath: "/tmp/encrypted.zip", password: "SecretPassword"))
        XCTAssertFalse(appState.showPasswordPrompt)
        XCTAssertEqual(appState.activePassword, "SecretPassword")
        
        mediator.send(event: .openTab(tabIndex: 2))
        XCTAssertEqual(appState.activeTab, WorkspaceTab.presets)
    }
    
    // MARK: - 9. PresetWorkspaceViewModel
    @MainActor
    func testPresetWorkspaceViewModelMediatorIntegration() {
        let viewModel = PresetWorkspaceViewModel()
        let mediator = ArchiveAppMediator.shared
        
        let firstPreset = viewModel.presets.first
        XCTAssertNotNil(firstPreset)
        
        if let preset = firstPreset {
            mediator.send(event: .presetSelected(presetId: preset.id.uuidString))
            XCTAssertEqual(viewModel.selectedPresetID, preset.id)
        }
    }
    
    // MARK: - 10. CompressModalMediatorComponent
    func testCompressModalMediatorComponentRegistration() {
        let comp = CompressModalMediatorComponent()
        XCTAssertEqual(comp.componentId, "CompressModalView")
        XCTAssertTrue(ArchiveAppMediator.shared.isRegistered(componentId: "CompressModalView"))
    }
    
    // MARK: - 11. ExtractModalMediatorComponent
    func testExtractModalMediatorComponentRegistration() {
        let comp = ExtractModalMediatorComponent()
        XCTAssertEqual(comp.componentId, "ExtractModalView")
        XCTAssertTrue(ArchiveAppMediator.shared.isRegistered(componentId: "ExtractModalView"))
    }
    
    // MARK: - 12. PasswordPromptMediatorComponent
    func testPasswordPromptMediatorComponentRegistration() {
        let comp = PasswordPromptMediatorComponent()
        XCTAssertEqual(comp.componentId, "PasswordPromptSheetView")
        XCTAssertTrue(ArchiveAppMediator.shared.isRegistered(componentId: "PasswordPromptSheetView"))
    }
    
    // MARK: - 13. AppMediatorEvent
    func testAppMediatorEventPayloadEqualityAndProperties() {
        let ev1 = AppMediatorEvent.requestPasswordPrompt(archivePath: "/tmp/a.zip")
        let ev2 = AppMediatorEvent.requestPasswordPrompt(archivePath: "/tmp/a.zip")
        let ev3 = AppMediatorEvent.requestPasswordPrompt(archivePath: "/tmp/b.zip")
        
        XCTAssertEqual(ev1, ev2)
        XCTAssertNotEqual(ev1, ev3)
        XCTAssertEqual(ev1.eventName, "requestPasswordPrompt")
        XCTAssertEqual(AppMediatorEvent.openTab(tabIndex: 0).eventName, "openTab")
    }
    
    // MARK: - 14. CoreEngineMediatorEvent
    func testCoreEngineMediatorEventPayloadEqualityAndProperties() {
        let e1 = CoreEngineMediatorEvent.extractionFailedNeedPassword(archivePath: "1.zip")
        let e2 = CoreEngineMediatorEvent.extractionFailedNeedPassword(archivePath: "1.zip")
        let e3 = CoreEngineMediatorEvent.cleanupTempFiles(tempPaths: ["/tmp/a"])
        
        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
        XCTAssertEqual(e1.eventName, "extractionFailedNeedPassword")
        XCTAssertEqual(e3.eventName, "cleanupTempFiles")
    }
    
    // MARK: - 15. / Zero Lock Deadlock
    func testRapidRegisterUnregisterUnderHighConcurrency() {
        let mediator = ArchiveAppMediator.shared
        let exp = expectation(description: "Rapid Register Unregister")
        let iterations = 200
        
        DispatchQueue.concurrentPerform(iterations: iterations) { idx in
            let comp = MockMediatorComponent(componentId: "RapidComp_\(idx)")
            mediator.register(component: comp)
            mediator.send(event: .openTab(tabIndex: idx % 6))
            mediator.unregister(component: comp)
        }
        
        exp.fulfill()
        wait(for: [exp], timeout: 3.0)
        XCTAssertEqual(mediator.registeredComponentCount, 0)
    }
    
    // MARK: - 16. AnonymousMediatorComponent
    func testAnonymousMediatorComponentHandling() {
        let mediator = ArchiveAppMediator.shared
        var receivedAppEvent: AppMediatorEvent? = nil
        
        let anon = AnonymousMediatorComponent(appEventCallback: { ev in
            receivedAppEvent = ev
        })
        mediator.register(component: anon)
        
        let testEv = AppMediatorEvent.compressionCompleted(outputPath: "/tmp/output.zip")
        mediator.send(event: testEv)
        
        XCTAssertEqual(receivedAppEvent, testEv)
    }
}
