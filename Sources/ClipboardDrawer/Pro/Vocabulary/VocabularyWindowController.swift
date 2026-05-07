import AppKit
import SwiftUI

@MainActor
final class VocabularyWindowController {
    private let viewModel: VocabularyViewModel
    private var window: NSWindow?

    init(viewModel: VocabularyViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        viewModel.refresh()
        if window == nil {
            let view = VocabularyView(viewModel: viewModel)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Clipwell Vocabulary"
            window.center()
            window.contentView = NSHostingView(rootView: view)
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
