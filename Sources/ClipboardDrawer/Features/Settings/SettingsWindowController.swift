import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let conflictService: ShortcutConflictService
    private let saveShortcut: @MainActor (AppShortcut) -> Bool
    private var window: NSWindow?

    init(settings: SettingsStore, conflictService: ShortcutConflictService, saveShortcut: @MainActor @escaping (AppShortcut) -> Bool) {
        self.settings = settings
        self.conflictService = conflictService
        self.saveShortcut = saveShortcut
    }

    func show() {
        if window == nil {
            let view = SettingsView(settings: settings, conflictService: conflictService, saveShortcut: saveShortcut)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Clipboard Drawer Settings"
            window.center()
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
