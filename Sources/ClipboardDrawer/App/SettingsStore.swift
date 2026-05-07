import Combine
import Foundation

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
    case light
    case graphite
    case slate
    case warm
    case tech

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .graphite: "Graphite"
        case .slate: "Slate"
        case .warm: "Warm"
        case .tech: "Tech"
        }
    }

    var subtitle: String {
        switch self {
        case .light: "Clean light interface"
        case .graphite: "Quiet neutral dark"
        case .slate: "Soft blue-gray"
        case .warm: "Muted warm dark"
        case .tech: "High contrast cyan"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    var visualTheme: AppVisualTheme {
        didSet {
            defaults.set(visualTheme.rawValue, forKey: Keys.visualTheme)
            objectWillChange.send()
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
    @Published var proAIEnabled: Bool { didSet { defaults.set(proAIEnabled, forKey: Keys.proAIEnabled) } }
    @Published var proAIBaseURL: String { didSet { defaults.set(proAIBaseURL, forKey: Keys.proAIBaseURL) } }
    @Published var proAIAPIKey: String { didSet { defaults.set(proAIAPIKey, forKey: Keys.proAIAPIKey) } }
    @Published var proAIModel: String { didSet { defaults.set(proAIModel, forKey: Keys.proAIModel) } }
    @Published var proVocabularyEnabled: Bool { didSet { defaults.set(proVocabularyEnabled, forKey: Keys.proVocabularyEnabled) } }
    @Published var proTranslationTargetLanguage: String { didSet { defaults.set(proTranslationTargetLanguage, forKey: Keys.proTranslationTargetLanguage) } }
    @Published var proOCRLanguagesText: String { didSet { defaults.set(proOCRLanguagesText, forKey: Keys.proOCRLanguagesText) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        visualTheme = AppVisualTheme(rawValue: defaults.string(forKey: Keys.visualTheme) ?? "") ?? .graphite
        drawerEdge = DrawerEdge(rawValue: defaults.string(forKey: Keys.drawerEdge) ?? "") ?? .right
        let width = defaults.double(forKey: Keys.drawerWidth)
        drawerWidth = width == 0 ? 420 : width
        drawerAnimationSpeed = DrawerAnimationSpeed(rawValue: defaults.string(forKey: Keys.drawerAnimationSpeed) ?? "") ?? .normal
        previewEnabled = defaults.object(forKey: Keys.previewEnabled) as? Bool ?? true
        let storedPreviewHeight = defaults.double(forKey: Keys.previewHeight)
        previewHeight = storedPreviewHeight == 0 ? 260 : storedPreviewHeight

        let keyCodeValue = defaults.object(forKey: Keys.shortcutToggleDrawerKeyCode) as? NSNumber
        let modifiersValue = defaults.object(forKey: Keys.shortcutToggleDrawerModifiers) as? NSNumber
        toggleDrawerShortcut = AppShortcut(
            keyCode: keyCodeValue?.uint32Value ?? AppShortcut.defaultToggleDrawer.keyCode,
            modifierFlags: modifiersValue?.uint32Value ?? AppShortcut.defaultToggleDrawer.modifierFlags
        )

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
        proAIEnabled = defaults.object(forKey: Keys.proAIEnabled) as? Bool ?? true
        proAIBaseURL = defaults.string(forKey: Keys.proAIBaseURL) ?? "http://127.0.0.1:4000/v1"
        proAIAPIKey = defaults.string(forKey: Keys.proAIAPIKey) ?? ""
        proAIModel = defaults.string(forKey: Keys.proAIModel) ?? "gpt-5.4-mini"
        proVocabularyEnabled = defaults.object(forKey: Keys.proVocabularyEnabled) as? Bool ?? true
        proTranslationTargetLanguage = defaults.string(forKey: Keys.proTranslationTargetLanguage) ?? "English"
        proOCRLanguagesText = defaults.string(forKey: Keys.proOCRLanguagesText) ?? "zh-Hans,en-US"
    }

    func shortcutsByAction() -> [AppAction: AppShortcut] {
        [
            .toggleDrawer: toggleDrawerShortcut,
            .screenshotOCR: screenshotOCRShortcut,
        ]
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
        static let proAIEnabled = "pro_ai_enabled"
        static let proAIBaseURL = "pro_ai_base_url"
        static let proAIAPIKey = "pro_ai_api_key"
        static let proAIModel = "pro_ai_model"
        static let proVocabularyEnabled = "pro_vocabulary_enabled"
        static let proTranslationTargetLanguage = "pro_translation_target_language"
        static let proOCRLanguagesText = "pro_ocr_languages_text"
    }
}
