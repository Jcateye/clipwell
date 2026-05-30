import Foundation
import Translation

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case auto
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean
    case french
    case german
    case spanish
    case italian
    case portuguese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: "Auto Detect"
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        case .traditionalChinese: "Traditional Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .french: "French"
        case .german: "German"
        case .spanish: "Spanish"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        }
    }

    var localeLanguage: Locale.Language? {
        switch self {
        case .auto: nil
        case .english: Locale.Language(identifier: "en")
        case .simplifiedChinese: Locale.Language(identifier: "zh-Hans")
        case .traditionalChinese: Locale.Language(identifier: "zh-Hant")
        case .japanese: Locale.Language(identifier: "ja")
        case .korean: Locale.Language(identifier: "ko")
        case .french: Locale.Language(identifier: "fr")
        case .german: Locale.Language(identifier: "de")
        case .spanish: Locale.Language(identifier: "es")
        case .italian: Locale.Language(identifier: "it")
        case .portuguese: Locale.Language(identifier: "pt")
        }
    }

    static var targetChoices: [TranslationLanguage] {
        allCases.filter { $0 != .auto }
    }
}

enum TranslationLanguageResolver {
    static func sourceLocaleLanguage(_ language: TranslationLanguage) -> Locale.Language? {
        language.localeLanguage
    }

    static func targetDisplayName(_ language: TranslationLanguage) -> String {
        normalizedTarget(language).displayName
    }

    static func targetLocaleLanguage(_ language: TranslationLanguage) -> Locale.Language {
        normalizedTarget(language).localeLanguage ?? Locale.Language(identifier: "en")
    }

    static func defaultTargetLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> TranslationLanguage {
        let primaryLanguage = preferredLanguages.first?.lowercased() ?? ""
        if primaryLanguage.hasPrefix("zh-hant") || primaryLanguage.contains("tw") || primaryLanguage.contains("hk") {
            return .traditionalChinese
        }
        if primaryLanguage.hasPrefix("zh") {
            return .simplifiedChinese
        }
        return .english
    }

    private static func normalizedTarget(_ language: TranslationLanguage) -> TranslationLanguage {
        language == .auto ? defaultTargetLanguage() : language
    }
}
