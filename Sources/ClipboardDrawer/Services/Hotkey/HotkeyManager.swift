import Carbon
import Combine
import Foundation

@MainActor
final class HotkeyManager: ObservableObject {
    @Published private(set) var activeShortcuts: [AppAction: AppShortcut]
    @Published var lastError: String?

    private var hotKeyRefs: [AppAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var lastWorkingShortcuts: [AppAction: AppShortcut]
    private let actionMap: [AppAction: () -> Void]

    init(shortcuts: [AppAction: AppShortcut], actions: [AppAction: () -> Void]) {
        self.activeShortcuts = shortcuts
        self.lastWorkingShortcuts = shortcuts
        self.actionMap = actions
        installHandler()
        registerAll(shortcuts)
    }

    @discardableResult
    func updateShortcut(_ shortcut: AppShortcut, for action: AppAction) -> Bool {
        let previous = lastWorkingShortcuts[action] ?? shortcut
        unregister(action)

        if register(shortcut, for: action) {
            activeShortcuts[action] = shortcut
            lastWorkingShortcuts[action] = shortcut
            lastError = nil
            return true
        }

        AppLog.hotkey.error("Failed to register shortcut \(shortcut.displayString), rolling back")
        lastError = "Could not register \(shortcut.displayString). Reverted to \(previous.displayString)."
        _ = register(previous, for: action)
        activeShortcuts[action] = previous
        return false
    }

    private func registerAll(_ shortcuts: [AppAction: AppShortcut]) {
        for (action, shortcut) in shortcuts {
            if !register(shortcut, for: action) {
                let fallback: AppShortcut = action == .toggleDrawer ? .defaultToggleDrawer : .defaultScreenshotOCR
                _ = register(fallback, for: action)
                activeShortcuts[action] = fallback
                lastWorkingShortcuts[action] = fallback
            }
        }
    }

    private func register(_ shortcut: AppShortcut, for action: AppAction) -> Bool {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x43444356), id: hotKeyIdentifier(for: action))
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            AppLog.hotkey.error("RegisterEventHotKey failed with status \(status)")
            return false
        }
        if let hotKeyRef {
            hotKeyRefs[action] = hotKeyRef
        }
        return true
    }

    private func unregister(_ action: AppAction) {
        if let hotKeyRef = hotKeyRefs[action] {
            UnregisterEventHotKey(hotKeyRef)
            hotKeyRefs[action] = nil
        }
    }

    private func hotKeyIdentifier(for action: AppAction) -> UInt32 {
        switch action {
        case .toggleDrawer: return 1
        case .screenshotOCR: return 2
        }
    }

    private func action(for hotKeyID: UInt32) -> AppAction? {
        switch hotKeyID {
        case 1: return .toggleDrawer
        case 2: return .screenshotOCR
        default: return nil
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let managerAddress = UInt(bitPattern: userData)
            DispatchQueue.main.async {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(UnsafeRawPointer(bitPattern: managerAddress)!).takeUnretainedValue()
                guard let action = manager.action(for: hotKeyID.id) else { return }
                manager.actionMap[action]?()
            }
            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }
}
