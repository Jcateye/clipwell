import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settings: SettingsStore
    private let openDrawer: () -> Void
    private let clearHistory: () -> Void
    private let openSettings: () -> Void

    init(settings: SettingsStore, openDrawer: @escaping () -> Void, clearHistory: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.openDrawer = openDrawer
        self.clearHistory = clearHistory
        self.openSettings = openSettings
        super.init()
        configure()
    }

    func refreshMenu() {
        configureMenu()
    }

    private func configure() {
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Drawer")
        statusItem.button?.image?.isTemplate = true
        configureMenu()
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: settings.monitoringPaused ? "Monitoring Paused" : "Monitoring Active", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Open Drawer", action: #selector(openDrawerAction), keyEquivalent: "o", target: self))
        menu.addItem(NSMenuItem(title: settings.monitoringPaused ? "Resume Monitoring" : "Pause Monitoring", action: #selector(toggleMonitoringAction), keyEquivalent: "p", target: self))
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistoryAction), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettingsAction), keyEquivalent: ",", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q", target: self))
        statusItem.menu = menu
    }

    @objc private func openDrawerAction() {
        openDrawer()
    }

    @objc private func toggleMonitoringAction() {
        settings.monitoringPaused.toggle()
        configureMenu()
    }

    @objc private func clearHistoryAction() {
        clearHistory()
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}

private extension NSMenuItem {
    convenience init(title: String, action: Selector?, keyEquivalent: String, target: AnyObject) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}
