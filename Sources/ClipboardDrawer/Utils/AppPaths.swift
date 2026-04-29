import Foundation

enum AppPaths {
    static var appSupportDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["CLIPBOARD_DRAWER_DATA_DIR"], !override.isEmpty {
            let directory = URL(fileURLWithPath: override, isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = base.appendingPathComponent("ClipboardDrawer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var databaseURL: URL {
        appSupportDirectory.appendingPathComponent("clips.sqlite")
    }

    static var payloadsDirectory: URL {
        let directory = appSupportDirectory.appendingPathComponent("payloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
