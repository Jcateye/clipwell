import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let conflictService: ShortcutConflictService
    private let saveShortcut: @MainActor (AppAction, AppShortcut) -> Bool
    private let aiConnectionValidator: AIConnectionValidator
    private let openVocabulary: () -> Void
    private var window: NSWindow?

    init(settings: SettingsStore, conflictService: ShortcutConflictService, saveShortcut: @MainActor @escaping (AppAction, AppShortcut) -> Bool, aiConnectionValidator: AIConnectionValidator, openVocabulary: @escaping () -> Void) {
        self.settings = settings
        self.conflictService = conflictService
        self.saveShortcut = saveShortcut
        self.aiConnectionValidator = aiConnectionValidator
        self.openVocabulary = openVocabulary
    }

    func show() {
        if window == nil {
            let view = SettingsView(settings: settings, conflictService: conflictService, saveShortcut: saveShortcut, aiConnectionValidator: aiConnectionValidator, openVocabulary: openVocabulary)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Clipboard Drawer Settings"
            window.center()
            window.backgroundColor = .clear
            window.isOpaque = false
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
