import Carbon
import Combine
import Foundation

@MainActor
final class HotkeyManager: ObservableObject {
    @Published private(set) var activeShortcut: AppShortcut
    @Published var lastError: String?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var lastWorkingShortcut: AppShortcut
    private let hotKeyID = EventHotKeyID(signature: OSType(0x43444356), id: 1)
    private let action: () -> Void

    init(shortcut: AppShortcut, action: @escaping () -> Void) {
        self.activeShortcut = shortcut
        self.lastWorkingShortcut = shortcut
        self.action = action
        installHandler()
        if !register(shortcut) {
            _ = register(.defaultToggleDrawer)
        }
    }

    @discardableResult
    func updateShortcut(_ shortcut: AppShortcut) -> Bool {
        let previous = lastWorkingShortcut
        unregister()

        if register(shortcut) {
            activeShortcut = shortcut
            lastWorkingShortcut = shortcut
            lastError = nil
            return true
        }

        AppLog.hotkey.error("Failed to register shortcut \(shortcut.displayString), rolling back")
        lastError = "Could not register \(shortcut.displayString). Reverted to \(previous.displayString)."
        _ = register(previous)
        activeShortcut = previous
        return false
    }

    private func register(_ shortcut: AppShortcut) -> Bool {
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
        return true
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
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
            guard hotKeyID.id == 1 else { return noErr }
            let managerAddress = UInt(bitPattern: userData)
            DispatchQueue.main.async {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(UnsafeRawPointer(bitPattern: managerAddress)!).takeUnretainedValue()
                manager.action()
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
