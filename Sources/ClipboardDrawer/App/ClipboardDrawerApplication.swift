import AppKit
import Combine
import Foundation

@main
@MainActor
final class ClipboardDrawerApplication: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let vocabularyStore = VocabularyStore()
    private lazy var clipboardMonitor = ClipboardMonitorService(settings: settings, vocabularyStore: vocabularyStore)
    private lazy var vocabularyViewModel = VocabularyViewModel(store: vocabularyStore)
    private lazy var vocabularyWindowController = VocabularyWindowController(viewModel: vocabularyViewModel, settings: settings)
    private let conflictService = ShortcutConflictService()
    private var drawerController: DrawerWindowController?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var hotkeyManager: HotkeyManager?
    private var aiConnectionValidator: AIConnectionValidator?
    private var cancellables: Set<AnyCancellable> = []

    static func main() {
        let app = NSApplication.shared
        let delegate = ClipboardDrawerApplication()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        drawerController = DrawerWindowController(
            monitor: clipboardMonitor,
            settings: settings,
            onPaste: { [weak self] clip in
                self?.clipboardMonitor.paste(clip)
            },
            onOpenSettings: { [weak self] in
                self?.settingsWindowController?.show()
            }
        )
        menuBarController = MenuBarController(
            settings: settings,
            openDrawer: { [weak self] in self?.drawerController?.open() },
            clearHistory: { [weak self] in self?.clipboardMonitor.clearHistory() },
            openSettings: { [weak self] in self?.settingsWindowController?.show() }
        )
        let aiConfigStore = AIProviderConfigStore(settings: settings)
        let aiService = OpenAICompatibleTextAIService(configStore: aiConfigStore)
        let aiConnectionValidator = AIConnectionValidator(service: aiService)
        self.aiConnectionValidator = aiConnectionValidator

        settingsWindowController = SettingsWindowController(
            settings: settings,
            conflictService: conflictService,
            saveShortcut: { [weak self] action, shortcut in
                self?.hotkeyManager?.updateShortcut(shortcut, for: action) ?? false
            },
            aiConnectionValidator: aiConnectionValidator,
            openVocabulary: { [weak self] in
                self?.vocabularyWindowController.show()
            }
        )
        hotkeyManager = HotkeyManager(
            shortcuts: settings.shortcutsByAction(),
            actions: [
                .toggleDrawer: { [weak self] in
                    self?.drawerController?.toggle()
                },
            ]
        )

        settings.$monitoringPaused
            .sink { [weak self] _ in self?.menuBarController?.refreshMenu() }
            .store(in: &cancellables)

        hotkeyManager?.$lastError
            .sink { [weak self] message in
                self?.clipboardMonitor.bannerMessage = message
            }
            .store(in: &cancellables)

        clipboardMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }
}
