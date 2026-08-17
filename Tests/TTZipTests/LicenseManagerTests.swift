import XCTest
@testable import TTZipCore

final class LicenseManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        LicenseManager.simulateFreeTierInTests = true
        LicenseManager.shared.deactivate()
    }
    
    override func tearDown() {
        LicenseManager.simulateFreeTierInTests = false
        _ = LicenseManager.shared.activate(key: "AURA-PRO1-KEY8-2026")
        super.tearDown()
    }
    
    func testDefaultLicenseIsFree() {
        XCTAssertEqual(LicenseManager.shared.currentType, .free)
        XCTAssertFalse(LicenseManager.shared.isPro)
        XCTAssertTrue(LicenseManager.shared.canUseFeature(.basicExtract))
        XCTAssertFalse(LicenseManager.shared.canUseFeature(.aes256Encryption))
        XCTAssertFalse(LicenseManager.shared.canUseFeature(.ultraCompression))
    }
    
    func testValidProActivation() {
        LicenseManager.simulateFreeTierInTests = false
        let validKey = "AURA-PRO1-KEY8-2026"
        let success = LicenseManager.shared.activate(key: validKey, registeredTo: "Test User")
        
        XCTAssertTrue(success)
        XCTAssertTrue(LicenseManager.shared.isPro)
        XCTAssertEqual(LicenseManager.shared.currentType, .proPersonal)
        XCTAssertTrue(LicenseManager.shared.canUseFeature(.aes256Encryption))
        XCTAssertTrue(LicenseManager.shared.canUseFeature(.ultraCompression))
    }
    
    func testInvalidKeyRejection() {
        let invalidKey = "INVALID-KEY-123"
        let success = LicenseManager.shared.activate(key: invalidKey)
        
        XCTAssertFalse(success)
        XCTAssertFalse(LicenseManager.shared.isPro)
        XCTAssertEqual(LicenseManager.shared.currentType, .free)
    }
    
    func testDeactivation() {
        LicenseManager.simulateFreeTierInTests = false
        _ = LicenseManager.shared.activate(key: "AURA-PRO1-KEY8-2026")
        XCTAssertTrue(LicenseManager.shared.isPro)
        
        LicenseManager.simulateFreeTierInTests = true
        LicenseManager.shared.deactivate()
        XCTAssertFalse(LicenseManager.shared.isPro)
        XCTAssertEqual(LicenseManager.shared.currentType, .free)
    }
}
