import AppKit
import Foundation

enum ClipType: String, CaseIterable, Identifiable, Codable {
    case text
    case rtf
    case html
    case media
    case document

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: "Text"
        case .rtf: "Rich Text"
        case .html: "HTML"
        case .media: "Media"
        case .document: "Document"
        }
    }
}

enum ClipFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case media
    case document

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .text: "Text"
        case .media: "Media"
        case .document: "Document"
        }
    }
}

enum ClipOrigin: String, Codable {
    case original
    case proDerived
}

struct ClipItem: Identifiable, Hashable {
    let id: String
    let createdAt: Date
    let type: ClipType
    let plainText: String?
    let payloadPath: String?
    let sourceApp: String?
    let isPinned: Bool
    let contentHash: String
    let origin: ClipOrigin
    let derivedFromClipID: String?

    var title: String {
        if type == .media, let documentURL {
            return documentURL.lastPathComponent
        }

        if type == .media {
            if let payloadPath,
               let image = NSImage(contentsOfFile: payloadPath) {
                return "Image \(Int(image.size.width))×\(Int(image.size.height))"
            }
            return "Media clip"
        }

        if type == .document, let documentURL {
            return documentURL.lastPathComponent
        }

        let value = plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? type.displayName : value
    }

    var documentURL: URL? {
        guard (type == .document || type == .media), let plainText else {
            return nil
        }
        return URL(fileURLWithPath: plainText)
    }

    var isVideoDocument: Bool {
        guard let fileExtension = documentURL?.pathExtension.lowercased() else {
            return false
        }
        return Self.videoExtensions.contains(fileExtension)
    }

    var isImageDocument: Bool {
        guard let fileExtension = documentURL?.pathExtension.lowercased() else {
            return false
        }
        return Self.imageExtensions.contains(fileExtension)
    }

    var kindDisplayName: String {
        switch origin {
        case .original:
            return type.displayName
        case .proDerived:
            return "Pro \(type.displayName)"
        }
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "webp", "tiff"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm", "avi", "mkv"]
}
