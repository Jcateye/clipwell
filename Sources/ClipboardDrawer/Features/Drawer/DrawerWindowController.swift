import AppKit
import Combine
import SwiftUI

@MainActor
final class DrawerWindowController {
    private let monitor: ClipboardMonitorService
    private let settings: SettingsStore
    private let onPaste: @MainActor (ClipItem) -> Void
    private var panel: DrawerPanel?
    private var mouseMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    init(monitor: ClipboardMonitorService, settings: SettingsStore, onPaste: @MainActor @escaping (ClipItem) -> Void) {
        self.monitor = monitor
        self.settings = settings
        self.onPaste = onPaste

        settings.$drawerEdge.sink { [weak self] _ in self?.applyFrame(animated: false) }.store(in: &cancellables)
        settings.$drawerWidth.sink { [weak self] _ in self?.applyFrame(animated: false) }.store(in: &cancellables)
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func toggle() {
        isVisible ? close() : open()
    }

    func open() {
        let panel = ensurePanel()
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        applyFrame(animated: true)
        installOutsideClickMonitor()
    }

    func close() {
        guard let panel else { return }
        removeOutsideClickMonitor()
        let hiddenFrame = frame(hidden: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = settings.drawerAnimationSpeed.duration
            panel.animator().setFrame(hiddenFrame, display: true)
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        }
    }

    private func ensurePanel() -> DrawerPanel {
        if let panel {
            return panel
        }

        let panel = DrawerPanel(
            contentRect: frame(hidden: true),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.onEscape = { [weak self] in self?.close() }
        panel.contentView = NSHostingView(rootView: DrawerView(monitor: monitor, settings: settings) { [weak self] clip in
            self?.onPaste(clip)
            if self?.settings.autoCloseDrawerEnabled == true {
                self?.close()
            }
        })
        self.panel = panel
        return panel
    }

    private func applyFrame(animated: Bool) {
        guard let panel else { return }
        let visibleFrame = frame(hidden: false)
        guard panel.isVisible else {
            panel.setFrame(frame(hidden: true), display: false)
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = settings.drawerAnimationSpeed.duration
                panel.animator().setFrame(visibleFrame, display: true)
            }
        } else {
            panel.setFrame(visibleFrame, display: true)
        }
    }

    private func frame(hidden: Bool) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width = max(320, min(520, settings.drawerWidth))
        let x: CGFloat
        switch settings.drawerEdge {
        case .left:
            x = hidden ? screenFrame.minX - width : screenFrame.minX
        case .right:
            x = hidden ? screenFrame.maxX : screenFrame.maxX - width
        }
        return NSRect(x: x, y: screenFrame.minY, width: width, height: screenFrame.height)
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func removeOutsideClickMonitor() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }
}
