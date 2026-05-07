import Carbon
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

    func testMultipleShortcutsPersistIndependently() {
        let suiteName = "SettingsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let settings = SettingsStore(defaults: defaults)
        settings.toggleDrawerShortcut = AppShortcut(keyCode: 12, modifierFlags: UInt32(optionKey | shiftKey))
        settings.screenshotOCRShortcut = AppShortcut(keyCode: 15, modifierFlags: UInt32(controlKey | shiftKey))

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.toggleDrawerShortcut, AppShortcut(keyCode: 12, modifierFlags: UInt32(optionKey | shiftKey)))
        XCTAssertEqual(reloaded.screenshotOCRShortcut, AppShortcut(keyCode: 15, modifierFlags: UInt32(controlKey | shiftKey)))
    }

    func testAIProviderSettingsPersist() {
        let suiteName = "SettingsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let settings = SettingsStore(defaults: defaults)
        settings.proAIBaseURL = "http://127.0.0.1:4000/v1"
        settings.proAIAPIKey = "test-key"
        settings.proAIModel = "gpt-5.4"
        settings.proVocabularyEnabled = false
        settings.proTranslationTargetLanguage = "Japanese"

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.proAIBaseURL, "http://127.0.0.1:4000/v1")
        XCTAssertEqual(reloaded.proAIAPIKey, "test-key")
        XCTAssertEqual(reloaded.proAIModel, "gpt-5.4")
        XCTAssertEqual(reloaded.proVocabularyEnabled, false)
        XCTAssertEqual(reloaded.proTranslationTargetLanguage, "Japanese")
    }
}
