import Foundation

@MainActor
final class AIProviderConfigStore {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func current() -> OpenAICompatibleConfig {
        settings.proAIConfig
    }
}
