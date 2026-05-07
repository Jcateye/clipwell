import Foundation

final class ScreenshotService: @unchecked Sendable {
    func captureSelectionPNG() async throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", url.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ScreenshotError.cancelled
        }

        defer {
            try? FileManager.default.removeItem(at: url)
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ScreenshotError.missingCaptureFile
        }

        return try Data(contentsOf: url)
    }
}

enum ScreenshotError: LocalizedError, Equatable {
    case cancelled
    case missingCaptureFile

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Screenshot OCR was cancelled."
        case .missingCaptureFile:
            return "Clipwell could not read the captured screenshot. Please try again."
        }
    }
}
