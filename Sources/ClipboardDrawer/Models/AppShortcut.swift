import Carbon
import Foundation

enum AppAction: String, CaseIterable, Identifiable {
    case toggleDrawer
    case screenshotOCR

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggleDrawer: "Toggle Drawer"
        case .screenshotOCR: "Screenshot OCR"
        }
    }
}

struct AppShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifierFlags: UInt32

    static let defaultToggleDrawer = AppShortcut(keyCode: 49, modifierFlags: UInt32(optionKey))
    static let defaultScreenshotOCR = AppShortcut(keyCode: 15, modifierFlags: UInt32(optionKey | shiftKey))

    var isModifierOnly: Bool {
        keyCode == UInt32.max || modifierFlags == 0
    }

    var displayString: String {
        let modifiers = [
            (UInt32(cmdKey), "⌘"),
            (UInt32(optionKey), "⌥"),
            (UInt32(controlKey), "⌃"),
            (UInt32(shiftKey), "⇧")
        ]
        let prefix = modifiers.reduce(into: "") { result, entry in
            if modifierFlags & entry.0 != 0 {
                result += entry.1
            }
        }
        return prefix + Self.keyName(for: keyCode)
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 31: "O"
        case 32: "U"
        case 34: "I"
        case 35: "P"
        case 37: "L"
        case 38: "J"
        case 40: "K"
        case 45: "N"
        case 46: "M"
        case 49: "Space"
        case 53: "Esc"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default: "Key \(keyCode)"
        }
    }
}
