import AppKit
import CryptoKit
import Foundation

struct ParsedClip {
    let type: ClipType
    let plainText: String?
    let payloadData: Data?
    let payloadExtension: String?
    let contentHash: String
}

final class ClipboardParser {
    private let rtfType = NSPasteboard.PasteboardType("public.rtf")
    private let htmlType = NSPasteboard.PasteboardType("public.html")

    func parse(_ pasteboard: NSPasteboard = .general, ignoredFileExtensions: Set<String> = []) -> ParsedClip? {
        if let documentClip = parseDocument(pasteboard, ignoredFileExtensions: ignoredFileExtensions) {
            return documentClip
        }

        if let imageClip = parseImage(pasteboard) {
            return imageClip
        }

        if let rtfData = pasteboard.data(forType: rtfType) {
            let plainText = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string
            return ParsedClip(
                type: .rtf,
                plainText: plainText,
                payloadData: rtfData,
                payloadExtension: "rtf",
                contentHash: hash(data: rtfData)
            )
        }

        if let htmlData = pasteboard.data(forType: htmlType) {
            let plainText = NSAttributedString(html: htmlData, documentAttributes: nil)?.string
            return ParsedClip(
                type: .html,
                plainText: plainText,
                payloadData: htmlData,
                payloadExtension: "html",
                contentHash: hash(data: htmlData)
            )
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let data = Data(string.utf8)
            return ParsedClip(
                type: .text,
                plainText: string,
                payloadData: nil,
                payloadExtension: nil,
                contentHash: hash(data: data)
            )
        }

        return nil
    }

    private func parseDocument(_ pasteboard: NSPasteboard, ignoredFileExtensions: Set<String>) -> ParsedClip? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              let url = urls.first,
              url.isFileURL else {
            return nil
        }

        let allowedExtensions: Set<String> = [
            "pdf", "doc", "docx", "pages", "rtf", "rtfd", "txt", "md",
            "xls", "xlsx", "numbers", "csv", "ppt", "pptx", "key",
            "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff",
            "mp4", "mov", "m4v", "webm", "avi", "mkv"
        ]
        let fileExtension = url.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            return nil
        }
        guard !ignoredFileExtensions.contains(fileExtension) else {
            return nil
        }

        var hashInput = url.path
        if let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            hashInput += "|\(modifiedAt.timeIntervalSince1970)"
        }

        return ParsedClip(
            type: mediaExtensions.contains(fileExtension) ? .media : .document,
            plainText: url.path,
            payloadData: nil,
            payloadExtension: nil,
            contentHash: hash(data: Data(hashInput.utf8))
        )
    }

    private func parseImage(_ pasteboard: NSPasteboard) -> ParsedClip? {
        var image: NSImage?

        if let data = pasteboard.data(forType: .png) {
            image = NSImage(data: data)
        } else if let data = pasteboard.data(forType: .tiff) {
            image = NSImage(data: data)
        } else {
            image = NSImage(pasteboard: pasteboard)
        }

        guard let image, let pngData = pngData(from: image) else {
            return nil
        }

        return ParsedClip(
            type: .media,
            plainText: nil,
            payloadData: pngData,
            payloadExtension: "png",
            contentHash: hash(data: pngData)
        )
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    func hashText(_ text: String) -> String {
        hash(data: Data(text.utf8))
    }

    func hashData(_ data: Data) -> String {
        hash(data: data)
    }

    private func hash(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private let mediaExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff",
        "mp4", "mov", "m4v", "webm", "avi", "mkv"
    ]
}
