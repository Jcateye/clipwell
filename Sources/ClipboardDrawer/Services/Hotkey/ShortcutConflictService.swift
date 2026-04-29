import Carbon
import Foundation

struct ShortcutConflictResult: Equatable {
    var isHardConflict: Bool
    var warning: String?
    var message: String?

    static let ok = ShortcutConflictResult(isHardConflict: false, warning: nil, message: nil)
}

final class ShortcutConflictService {
    private let reservedShortcuts: [AppShortcut: String] = [
        AppShortcut(keyCode: 49, modifierFlags: UInt32(cmdKey)): "Spotlight commonly uses ⌘Space.",
        AppShortcut(keyCode: 48, modifierFlags: UInt32(cmdKey)): "App switching commonly uses ⌘Tab.",
        AppShortcut(keyCode: 12, modifierFlags: UInt32(cmdKey)): "Quit commonly uses ⌘Q.",
        AppShortcut(keyCode: 13, modifierFlags: UInt32(cmdKey)): "Close window commonly uses ⌘W.",
        AppShortcut(keyCode: 4, modifierFlags: UInt32(cmdKey)): "Hide app commonly uses ⌘H.",
        AppShortcut(keyCode: 12, modifierFlags: UInt32(controlKey | cmdKey)): "Lock screen commonly uses ⌃⌘Q."
    ]

    func validate(shortcut: AppShortcut, for action: AppAction, existing: [AppAction: AppShortcut]) -> ShortcutConflictResult {
        if shortcut.isModifierOnly {
            return ShortcutConflictResult(
                isHardConflict: true,
                warning: nil,
                message: "Shortcut must include a non-modifier key."
            )
        }

        if let conflictingAction = existing.first(where: { $0.key != action && $0.value == shortcut })?.key {
            return ShortcutConflictResult(
                isHardConflict: true,
                warning: nil,
                message: "\(shortcut.displayString) is already assigned to \(conflictingAction.displayName)."
            )
        }

        if let warning = reservedShortcuts[shortcut] {
            return ShortcutConflictResult(isHardConflict: false, warning: warning, message: nil)
        }

        return .ok
    }
}
