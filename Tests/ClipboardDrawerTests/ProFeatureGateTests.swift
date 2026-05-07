import XCTest
@testable import ClipboardDrawer

@MainActor
final class ProFeatureGateTests: XCTestCase {
    func testBaseProFeaturesFollowProEnabled() throws {
        let suiteName = "ProFeatureGateTests.base.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        let gate = ProFeatureGate(settings: settings)

        settings.proEnabled = true
        XCTAssertTrue(gate.canUse(.imageOCR))
        XCTAssertTrue(gate.canUse(.screenshotOCR))
        XCTAssertTrue(gate.canUse(.vocabulary))

        settings.proEnabled = false
        XCTAssertFalse(gate.canUse(.imageOCR))
        XCTAssertFalse(gate.canUse(.screenshotOCR))
        XCTAssertFalse(gate.canUse(.vocabulary))
        XCTAssertThrowsError(try gate.require(.imageOCR))
    }

    func testAIFeaturesRequireProAndAIEnabled() {
        let suiteName = "ProFeatureGateTests.ai.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        let gate = ProFeatureGate(settings: settings)

        settings.proEnabled = true
        settings.proAIEnabled = true
        XCTAssertTrue(gate.canUse(.aiTranslate))
        XCTAssertTrue(gate.canUse(.aiRewrite))
        XCTAssertTrue(gate.canUse(.aiSummarize))

        settings.proAIEnabled = false
        XCTAssertFalse(gate.canUse(.aiTranslate))

        settings.proAIEnabled = true
        settings.proEnabled = false
        XCTAssertFalse(gate.canUse(.aiRewrite))
    }
}
