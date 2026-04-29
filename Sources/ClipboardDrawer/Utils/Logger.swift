import Foundation
import os

enum AppLog {
    static let clipboard = Logger(subsystem: "ClipboardDrawer", category: "clipboard")
    static let hotkey = Logger(subsystem: "ClipboardDrawer", category: "hotkey")
    static let database = Logger(subsystem: "ClipboardDrawer", category: "database")
}
