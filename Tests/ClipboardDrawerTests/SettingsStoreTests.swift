@testable import ClipboardDrawer
import XCTest

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testIgnoredAppsMatchNameOrBundleIdentifier() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.ignoredAppListText = """
        com.example.secret
        Notes
        """

        XCTAssertTrue(settings.shouldIgnore(appName: "Apple Notes", bundleIdentifier: "com.apple.Notes"))
        XCTAssertTrue(settings.shouldIgnore(appName: "Secret", bundleIdentifier: "com.example.secret"))
        XCTAssertFalse(settings.shouldIgnore(appName: "Safari", bundleIdentifier: "com.apple.Safari"))
    }

    func testIgnoredFileExtensionsNormalizeSeparatorsAndDots() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.ignoredFileExtensionsText = """
        .mov, ZIP
        psd webm
        """

        XCTAssertEqual(settings.ignoredFileExtensions, ["mov", "zip", "psd", "webm"])
    }
}
