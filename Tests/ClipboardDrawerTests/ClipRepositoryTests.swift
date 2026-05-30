@testable import ClipboardDrawer
import XCTest

final class ClipRepositoryTests: XCTestCase {
    func testUpdatePlainTextChangesEditableTextClipOnly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ClipRepository(databaseURL: directory.appendingPathComponent("clips.sqlite"))
        let textClip = ClipItem(
            id: "text",
            createdAt: Date(timeIntervalSince1970: 1),
            type: .text,
            plainText: "before",
            payloadPath: nil,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "before-hash",
            origin: .original,
            derivedFromClipID: nil
        )

        try repository.insert(textClip)
        try repository.updatePlainText(id: textClip.id, text: "after", contentHash: "after-hash")

        let updatedClip = try XCTUnwrap(repository.fetch(limit: 1).first)
        XCTAssertEqual(updatedClip.plainText, "after")
        XCTAssertEqual(updatedClip.contentHash, "after-hash")
        XCTAssertEqual(updatedClip.createdAt, textClip.createdAt)
    }

    func testPruneKeepsNewestAndReportsPayloads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ClipRepository(databaseURL: directory.appendingPathComponent("clips.sqlite"))
        let old = ClipItem(
            id: "old",
            createdAt: Date(timeIntervalSince1970: 1),
            type: .media,
            plainText: nil,
            payloadPath: directory.appendingPathComponent("old.png").path,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "old-hash",
            origin: .original,
            derivedFromClipID: nil
        )
        let new = ClipItem(
            id: "new",
            createdAt: Date(timeIntervalSince1970: 2),
            type: .text,
            plainText: "new",
            payloadPath: nil,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "new-hash",
            origin: .original,
            derivedFromClipID: nil
        )

        try repository.insert(old)
        try repository.insert(new)

        XCTAssertEqual(repository.payloadPathsBeyondLimit(maxCount: 1), [old.payloadPath!])
        repository.prune(maxCount: 1)

        let clips = repository.fetch(limit: 10)
        XCTAssertEqual(clips.map(\.id), ["new"])
    }

    func testMediaFilterIncludesCopiedMediaFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ClipRepository(databaseURL: directory.appendingPathComponent("clips.sqlite"))
        let mediaPayloadClip = ClipItem(
            id: "media-payload",
            createdAt: Date(timeIntervalSince1970: 1),
            type: .media,
            plainText: nil,
            payloadPath: directory.appendingPathComponent("payload.png").path,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "payload-hash",
            origin: .original,
            derivedFromClipID: nil
        )
        let mediaFileClip = ClipItem(
            id: "media-file",
            createdAt: Date(timeIntervalSince1970: 2),
            type: .media,
            plainText: directory.appendingPathComponent("named-photo.png").path,
            payloadPath: nil,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "file-hash",
            origin: .original,
            derivedFromClipID: nil
        )
        let documentClip = ClipItem(
            id: "document",
            createdAt: Date(timeIntervalSince1970: 3),
            type: .document,
            plainText: directory.appendingPathComponent("notes.pdf").path,
            payloadPath: nil,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "document-hash",
            origin: .original,
            derivedFromClipID: nil
        )

        try repository.insert(mediaPayloadClip)
        try repository.insert(mediaFileClip)
        try repository.insert(documentClip)

        let clips = repository.fetch(filter: .media, limit: 10)
        XCTAssertEqual(clips.map(\.id), ["media-file", "media-payload"])
    }

    func testDeleteMatchingFilterRemovesOnlyCurrentCategory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ClipRepository(databaseURL: directory.appendingPathComponent("clips.sqlite"))
        let textClip = ClipItem(
            id: "text",
            createdAt: Date(timeIntervalSince1970: 1),
            type: .text,
            plainText: "hello",
            payloadPath: nil,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "text-hash",
            origin: .original,
            derivedFromClipID: nil
        )
        let mediaClip = ClipItem(
            id: "media",
            createdAt: Date(timeIntervalSince1970: 2),
            type: .media,
            plainText: nil,
            payloadPath: directory.appendingPathComponent("image.png").path,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "media-hash",
            origin: .original,
            derivedFromClipID: nil
        )
        let documentClip = ClipItem(
            id: "document",
            createdAt: Date(timeIntervalSince1970: 3),
            type: .document,
            plainText: directory.appendingPathComponent("notes.pdf").path,
            payloadPath: nil,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: "document-hash",
            origin: .original,
            derivedFromClipID: nil
        )

        try repository.insert(textClip)
        try repository.insert(mediaClip)
        try repository.insert(documentClip)

        XCTAssertEqual(repository.payloadPaths(matching: .media), [mediaClip.payloadPath!])
        repository.delete(matching: .media)

        XCTAssertEqual(repository.fetch(limit: 10).map(\.id), ["document", "text"])
    }
}
