import AppKit
import Combine
import Foundation

@main
@MainActor
final class ClipboardDrawerApplication: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var clipboardMonitor = ClipboardMonitorService(settings: settings)
    private let conflictService = ShortcutConflictService()
    private var drawerController: DrawerWindowController?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var hotkeyManager: HotkeyManager?
    private var cancellables: Set<AnyCancellable> = []

    static func main() {
        let app = NSApplication.shared
        let delegate = ClipboardDrawerApplication()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        drawerController = DrawerWindowController(monitor: clipboardMonitor, settings: settings) { [weak self] clip in
            self?.clipboardMonitor.paste(clip)
        }
        menuBarController = MenuBarController(
            settings: settings,
            openDrawer: { [weak self] in self?.drawerController?.open() },
            clearHistory: { [weak self] in self?.clipboardMonitor.clearHistory() },
            openSettings: { [weak self] in self?.settingsWindowController?.show() }
        )
        settingsWindowController = SettingsWindowController(
            settings: settings,
            conflictService: conflictService,
            saveShortcut: { [weak self] shortcut in
                self?.hotkeyManager?.updateShortcut(shortcut) ?? false
            }
        )
        hotkeyManager = HotkeyManager(shortcut: settings.toggleDrawerShortcut) { [weak self] in
            self?.drawerController?.toggle()
        }

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
