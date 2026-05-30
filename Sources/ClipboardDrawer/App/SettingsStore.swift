import Combine
import Foundation
import SwiftUI

enum DrawerEdge: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum DrawerAnimationSpeed: String, CaseIterable, Identifiable {
    case fast
    case normal
    case slow

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var duration: TimeInterval {
        switch self {
        case .fast: 0.12
        case .normal: 0.22
        case .slow: 0.36
        }
    }
}

enum AppVisualTheme: String, CaseIterable, Identifiable {
    case glassDay
    case glassNight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glassDay: "Day"
        case .glassNight: "Night"
        }
    }

    var subtitle: String {
        switch self {
        case .glassDay: "Frosted translucent daylight"
        case .glassNight: "Frosted translucent night"
        }
    }

    var symbol: String {
        switch self {
        case .glassDay: "sun.max"
        case .glassNight: "moon"
        }
    }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .glassDay: .light
        case .glassNight: .dark
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var visualTheme: AppVisualTheme {
        didSet {
            defaults.set(visualTheme.rawValue, forKey: Keys.visualTheme)
        }
    }
    @Published var drawerEdge: DrawerEdge { didSet { defaults.set(drawerEdge.rawValue, forKey: Keys.drawerEdge) } }
    @Published var drawerWidth: Double { didSet { defaults.set(drawerWidth, forKey: Keys.drawerWidth) } }
    @Published var drawerAnimationSpeed: DrawerAnimationSpeed { didSet { defaults.set(drawerAnimationSpeed.rawValue, forKey: Keys.drawerAnimationSpeed) } }
    @Published var previewEnabled: Bool { didSet { defaults.set(previewEnabled, forKey: Keys.previewEnabled) } }
    @Published var previewHeight: Double { didSet { defaults.set(previewHeight, forKey: Keys.previewHeight) } }
    @Published var toggleDrawerShortcut: AppShortcut { didSet { persistShortcut(toggleDrawerShortcut, action: .toggleDrawer) } }
    @Published var screenshotOCRShortcut: AppShortcut { didSet { persistShortcut(screenshotOCRShortcut, action: .screenshotOCR) } }
    @Published var monitoringPaused: Bool { didSet { defaults.set(monitoringPaused, forKey: Keys.monitoringPaused) } }
    @Published var historyMaxCount: Int { didSet { defaults.set(historyMaxCount, forKey: Keys.historyMaxCount) } }
    @Published var dedupConsecutiveEnabled: Bool { didSet { defaults.set(dedupConsecutiveEnabled, forKey: Keys.dedupConsecutiveEnabled) } }
    @Published var autoPasteEnabled: Bool { didSet { defaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled) } }
    @Published var autoCloseDrawerEnabled: Bool { didSet { defaults.set(autoCloseDrawerEnabled, forKey: Keys.autoCloseDrawerEnabled) } }
    @Published var launchAtLoginEnabled: Bool { didSet { defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled) } }
    @Published var ignoredAppListText: String { didSet { defaults.set(ignoredAppListText, forKey: Keys.ignoredAppListText) } }
    @Published var ignoredFileExtensionsText: String { didSet { defaults.set(ignoredFileExtensionsText, forKey: Keys.ignoredFileExtensionsText) } }
    @Published var proEnabled: Bool { didSet { defaults.set(proEnabled, forKey: Keys.proEnabled) } }
    @Published var autoOCRImagesEnabled: Bool { didSet { defaults.set(autoOCRImagesEnabled, forKey: Keys.autoOCRImagesEnabled) } }
    @Published var proAIEnabled: Bool { didSet { defaults.set(proAIEnabled, forKey: Keys.proAIEnabled) } }
    @Published var proAIBaseURL: String { didSet { defaults.set(proAIBaseURL, forKey: Keys.proAIBaseURL) } }
    @Published var proAIAPIKey: String { didSet { defaults.set(proAIAPIKey, forKey: Keys.proAIAPIKey) } }
    @Published var proAIModel: String { didSet { defaults.set(proAIModel, forKey: Keys.proAIModel) } }
    @Published var proVocabularyEnabled: Bool { didSet { defaults.set(proVocabularyEnabled, forKey: Keys.proVocabularyEnabled) } }
    @Published var proTranslationSourceLanguage: TranslationLanguage {
        didSet { defaults.set(proTranslationSourceLanguage.rawValue, forKey: Keys.proTranslationSourceLanguage) }
    }
    @Published var proTranslationTargetLanguage: String { didSet { defaults.set(proTranslationTargetLanguage, forKey: Keys.proTranslationTargetLanguage) } }
    @Published var proTranslationTarget: TranslationLanguage {
        didSet {
            defaults.set(proTranslationTarget.rawValue, forKey: Keys.proTranslationTarget)
            proTranslationTargetLanguage = proTranslationTarget.displayName
        }
    }
    @Published var proOCRLanguagesText: String { didSet { defaults.set(proOCRLanguagesText, forKey: Keys.proOCRLanguagesText) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTheme = defaults.string(forKey: Keys.visualTheme) ?? ""
        let migratedTheme = Self.migratedVisualTheme(storedTheme)
        visualTheme = migratedTheme
        if storedTheme != migratedTheme.rawValue {
            defaults.set(migratedTheme.rawValue, forKey: Keys.visualTheme)
        }
        drawerEdge = DrawerEdge(rawValue: defaults.string(forKey: Keys.drawerEdge) ?? "") ?? .right
        let width = defaults.double(forKey: Keys.drawerWidth)
        drawerWidth = width == 0 ? 420 : width
        drawerAnimationSpeed = DrawerAnimationSpeed(rawValue: defaults.string(forKey: Keys.drawerAnimationSpeed) ?? "") ?? .normal
        previewEnabled = defaults.object(forKey: Keys.previewEnabled) as? Bool ?? true
        let storedPreviewHeight = defaults.double(forKey: Keys.previewHeight)
        previewHeight = storedPreviewHeight == 0 ? 260 : storedPreviewHeight

        let keyCodeValue = defaults.object(forKey: Keys.shortcutToggleDrawerKeyCode) as? NSNumber
        let modifiersValue = defaults.object(forKey: Keys.shortcutToggleDrawerModifiers) as? NSNumber
        let storedToggleShortcut = AppShortcut(
            keyCode: keyCodeValue?.uint32Value ?? AppShortcut.defaultToggleDrawer.keyCode,
            modifierFlags: modifiersValue?.uint32Value ?? AppShortcut.defaultToggleDrawer.modifierFlags
        )
        let migratedToggleShortcut = Self.migratedToggleDrawerShortcut(storedToggleShortcut)
        toggleDrawerShortcut = migratedToggleShortcut
        if migratedToggleShortcut != storedToggleShortcut {
            defaults.set(migratedToggleShortcut.keyCode, forKey: Keys.shortcutToggleDrawerKeyCode)
            defaults.set(migratedToggleShortcut.modifierFlags, forKey: Keys.shortcutToggleDrawerModifiers)
        }

        let screenshotKeyCodeValue = defaults.object(forKey: Keys.shortcutScreenshotOCRKeyCode) as? NSNumber
        let screenshotModifiersValue = defaults.object(forKey: Keys.shortcutScreenshotOCRModifiers) as? NSNumber
        screenshotOCRShortcut = AppShortcut(
            keyCode: screenshotKeyCodeValue?.uint32Value ?? AppShortcut.defaultScreenshotOCR.keyCode,
            modifierFlags: screenshotModifiersValue?.uint32Value ?? AppShortcut.defaultScreenshotOCR.modifierFlags
        )

        monitoringPaused = defaults.bool(forKey: Keys.monitoringPaused)
        let maxCount = defaults.integer(forKey: Keys.historyMaxCount)
        historyMaxCount = maxCount == 0 ? 500 : maxCount
        dedupConsecutiveEnabled = defaults.object(forKey: Keys.dedupConsecutiveEnabled) as? Bool ?? true
        autoPasteEnabled = defaults.object(forKey: Keys.autoPasteEnabled) as? Bool ?? false
        autoCloseDrawerEnabled = defaults.object(forKey: Keys.autoCloseDrawerEnabled) as? Bool ?? true
        launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
        ignoredAppListText = defaults.string(forKey: Keys.ignoredAppListText) ?? ""
        ignoredFileExtensionsText = defaults.string(forKey: Keys.ignoredFileExtensionsText) ?? ""
        proEnabled = defaults.object(forKey: Keys.proEnabled) as? Bool ?? true
        autoOCRImagesEnabled = defaults.object(forKey: Keys.autoOCRImagesEnabled) as? Bool ?? false
        proAIEnabled = defaults.object(forKey: Keys.proAIEnabled) as? Bool ?? true
        proAIBaseURL = defaults.string(forKey: Keys.proAIBaseURL) ?? "http://127.0.0.1:4000/v1"
        proAIAPIKey = defaults.string(forKey: Keys.proAIAPIKey) ?? ""
        proAIModel = defaults.string(forKey: Keys.proAIModel) ?? "gpt-5.4-mini"
        proVocabularyEnabled = defaults.object(forKey: Keys.proVocabularyEnabled) as? Bool ?? true
        proTranslationSourceLanguage = TranslationLanguage(rawValue: defaults.string(forKey: Keys.proTranslationSourceLanguage) ?? "") ?? .auto
        let storedTarget = defaults.string(forKey: Keys.proTranslationTarget)
        let legacyTargetName = defaults.string(forKey: Keys.proTranslationTargetLanguage)
        let translationTarget = TranslationLanguage(rawValue: storedTarget ?? "")
            ?? Self.migratedTranslationLanguage(displayName: legacyTargetName)
            ?? TranslationLanguageResolver.defaultTargetLanguage()
        proTranslationTarget = translationTarget
        proTranslationTargetLanguage = translationTarget.displayName
        proOCRLanguagesText = defaults.string(forKey: Keys.proOCRLanguagesText) ?? "zh-Hans,en-US"
    }

    func shortcutsByAction() -> [AppAction: AppShortcut] {
        [
            .toggleDrawer: toggleDrawerShortcut,
        ]
    }

    private static func migratedToggleDrawerShortcut(_ shortcut: AppShortcut) -> AppShortcut {
        shortcut == .internalLegacyDefaultToggleDrawer ? .defaultToggleDrawer : shortcut
    }

    private static func migratedVisualTheme(_ rawValue: String) -> AppVisualTheme {
        if let theme = AppVisualTheme(rawValue: rawValue) {
            return theme
        }

        switch rawValue {
        case "light":
            return .glassDay
        default:
            return .glassNight
        }
    }

    private static func migratedTranslationLanguage(displayName: String?) -> TranslationLanguage? {
        guard let displayName else { return nil }
        return TranslationLanguage.targetChoices.first { $0.displayName == displayName }
    }

    private func persistShortcut(_ shortcut: AppShortcut, action: AppAction) {
        switch action {
        case .toggleDrawer:
            defaults.set(shortcut.keyCode, forKey: Keys.shortcutToggleDrawerKeyCode)
            defaults.set(shortcut.modifierFlags, forKey: Keys.shortcutToggleDrawerModifiers)
        case .screenshotOCR:
            defaults.set(shortcut.keyCode, forKey: Keys.shortcutScreenshotOCRKeyCode)
            defaults.set(shortcut.modifierFlags, forKey: Keys.shortcutScreenshotOCRModifiers)
        }
    }

    func shouldIgnore(appName: String?, bundleIdentifier: String?) -> Bool {
        let rules = ignoredAppListText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !rules.isEmpty else {
            return false
        }

        let candidates = [appName, bundleIdentifier]
            .compactMap { $0?.lowercased() }

        return rules.contains { rule in
            candidates.contains { candidate in
                candidate == rule || candidate.contains(rule)
            }
        }
    }

    var ignoredFileExtensions: Set<String> {
        Set(
            ignoredFileExtensionsText
                .split { $0.isNewline || $0 == "," || $0 == ";" || $0 == " " || $0 == "\t" }
                .map {
                    $0.trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines))
                        .lowercased()
                }
                .filter { !$0.isEmpty }
        )
    }

    var proOCRLanguages: [String] {
        proOCRLanguagesText
            .split { $0.isNewline || $0 == "," || $0 == ";" || $0 == " " || $0 == "\t" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var proAIConfig: OpenAICompatibleConfig {
        OpenAICompatibleConfig(
            baseURL: proAIBaseURL,
            apiKey: proAIAPIKey,
            model: proAIModel
        )
    }

    var hasConfiguredAITranslation: Bool {
        !proAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !proAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !proAIModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum Keys {
        static let visualTheme = "visual_theme"
        static let drawerEdge = "drawer_edge"
        static let drawerWidth = "drawer_width"
        static let drawerAnimationSpeed = "drawer_animation_speed"
        static let previewEnabled = "preview_enabled"
        static let previewHeight = "preview_height"
        static let shortcutToggleDrawerKeyCode = "shortcut_toggle_drawer_keycode"
        static let shortcutToggleDrawerModifiers = "shortcut_toggle_drawer_modifiers"
        static let shortcutScreenshotOCRKeyCode = "shortcut_screenshot_ocr_keycode"
        static let shortcutScreenshotOCRModifiers = "shortcut_screenshot_ocr_modifiers"
        static let monitoringPaused = "monitoring_paused"
        static let historyMaxCount = "history_max_count"
        static let dedupConsecutiveEnabled = "dedup_consecutive_enabled"
        static let autoPasteEnabled = "auto_paste_enabled"
        static let autoCloseDrawerEnabled = "auto_close_drawer_enabled"
        static let launchAtLoginEnabled = "launch_at_login_enabled"
        static let ignoredAppListText = "ignored_app_list_text"
        static let ignoredFileExtensionsText = "ignored_file_extensions_text"
        static let proEnabled = "pro_enabled"
        static let autoOCRImagesEnabled = "auto_ocr_images_enabled"
        static let proAIEnabled = "pro_ai_enabled"
        static let proAIBaseURL = "pro_ai_base_url"
        static let proAIAPIKey = "pro_ai_api_key"
        static let proAIModel = "pro_ai_model"
        static let proVocabularyEnabled = "pro_vocabulary_enabled"
        static let proTranslationSourceLanguage = "pro_translation_source_language"
        static let proTranslationTarget = "pro_translation_target"
        static let proTranslationTargetLanguage = "pro_translation_target_language"
        static let proOCRLanguagesText = "pro_ocr_languages_text"
    }
}
