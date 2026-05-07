import Foundation

enum ProFeature {
    case imageOCR
    case screenshotOCR
    case vocabulary
    case aiTranslate
    case aiRewrite
    case aiSummarize
}

enum ProFeatureError: Error {
    case locked(ProFeature)
}

@MainActor
final class ProFeatureGate {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func canUse(_ feature: ProFeature) -> Bool {
        switch feature {
        case .imageOCR, .screenshotOCR, .vocabulary:
            return settings.proEnabled
        case .aiTranslate, .aiRewrite, .aiSummarize:
            return settings.proEnabled && settings.proAIEnabled
        }
    }

    func require(_ feature: ProFeature) throws {
        guard canUse(feature) else {
            throw ProFeatureError.locked(feature)
        }
    }
}
