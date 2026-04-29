import Carbon
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: AppShortcut
    var onCancel: () -> Void
    var onRecord: (AppShortcut) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCancel = onCancel
        view.onRecord = { recorded in
            shortcut = recorded
            onRecord(recorded)
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.needsDisplay = true
    }
}

final class RecorderNSView: NSView {
    var onCancel: (() -> Void)?
    var onRecord: ((AppShortcut) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        let shortcut = AppShortcut(keyCode: UInt32(event.keyCode), modifierFlags: modifiers)
        onRecord?(shortcut)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        bounds.fill()
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
}
