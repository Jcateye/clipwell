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

    func testToggleDrawerDefaultsToShiftCommandV() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.toggleDrawerShortcut, AppShortcut(keyCode: 9, modifierFlags: UInt32(cmdKey | shiftKey)))
        XCTAssertEqual(settings.toggleDrawerShortcut.displayString, "⌘⇧V")
    }

    func testInternalLegacyToggleDrawerDefaultMigratesToShiftCommandV() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        defaults.set(AppShortcut.internalLegacyDefaultToggleDrawer.keyCode, forKey: "shortcut_toggle_drawer_keycode")
        defaults.set(AppShortcut.internalLegacyDefaultToggleDrawer.modifierFlags, forKey: "shortcut_toggle_drawer_modifiers")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.toggleDrawerShortcut, AppShortcut.defaultToggleDrawer)
        XCTAssertEqual((defaults.object(forKey: "shortcut_toggle_drawer_keycode") as? NSNumber)?.uint32Value, AppShortcut.defaultToggleDrawer.keyCode)
        XCTAssertEqual((defaults.object(forKey: "shortcut_toggle_drawer_modifiers") as? NSNumber)?.uint32Value, AppShortcut.defaultToggleDrawer.modifierFlags)
    }

    func testCustomToggleDrawerShortcutDoesNotMigrate() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        let customShortcut = AppShortcut(keyCode: 12, modifierFlags: UInt32(optionKey | shiftKey))
        defaults.set(customShortcut.keyCode, forKey: "shortcut_toggle_drawer_keycode")
        defaults.set(customShortcut.modifierFlags, forKey: "shortcut_toggle_drawer_modifiers")

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.toggleDrawerShortcut, customShortcut)
    }

    func testLegacyVisualThemesMigrateToGlassModes() {
        let lightDefaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        lightDefaults.set("light", forKey: "visual_theme")
        let lightSettings = SettingsStore(defaults: lightDefaults)
        XCTAssertEqual(lightSettings.visualTheme, .glassDay)
        XCTAssertEqual(lightDefaults.string(forKey: "visual_theme"), AppVisualTheme.glassDay.rawValue)

        let darkDefaults = UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
        darkDefaults.set("graphite", forKey: "visual_theme")
        let darkSettings = SettingsStore(defaults: darkDefaults)
        XCTAssertEqual(darkSettings.visualTheme, .glassNight)
        XCTAssertEqual(darkDefaults.string(forKey: "visual_theme"), AppVisualTheme.glassNight.rawValue)
    }

    func testAIProviderSettingsPersist() {
        let suiteName = "SettingsStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let settings = SettingsStore(defaults: defaults)
        settings.proAIBaseURL = "http://127.0.0.1:4000/v1"
        settings.proAIAPIKey = "test-key"
        settings.proAIModel = "gpt-5.4"
        settings.autoOCRImagesEnabled = true
        settings.proVocabularyEnabled = false
        settings.proTranslationSourceLanguage = .auto
        settings.proTranslationTarget = .japanese

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.proAIBaseURL, "http://127.0.0.1:4000/v1")
        XCTAssertEqual(reloaded.proAIAPIKey, "test-key")
        XCTAssertEqual(reloaded.proAIModel, "gpt-5.4")
        XCTAssertEqual(reloaded.autoOCRImagesEnabled, true)
        XCTAssertEqual(reloaded.proVocabularyEnabled, false)
        XCTAssertEqual(reloaded.proTranslationSourceLanguage, .auto)
        XCTAssertEqual(reloaded.proTranslationTarget, .japanese)
        XCTAssertEqual(reloaded.proTranslationTargetLanguage, "Japanese")
    }
}
