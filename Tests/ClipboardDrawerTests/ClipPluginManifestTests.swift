import XCTest
@testable import ClipboardDrawer

final class ClipPluginManifestTests: XCTestCase {
    func testManifestDecodesWasmEntrypoint() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "com.example.cleaner",
          "name": "Cleaner",
          "version": "1.0.0",
          "author": "Example",
          "description": "Clean text",
          "entrypoint": {
            "kind": "wasm",
            "path": "main.wasm"
          },
          "triggers": ["postCapture", "manual"],
          "contentTypes": ["text"],
          "permissions": ["readCurrentContent"]
        }
        """

        let manifest = try JSONDecoder().decode(ClipPluginManifest.self, from: Data(json.utf8))

        XCTAssertEqual(manifest.id, "com.example.cleaner")
        XCTAssertEqual(manifest.triggers, [.postCapture, .manual])
        XCTAssertEqual(manifest.entrypoint, .wasm(path: "main.wasm"))
    }

    func testBuiltInDefaultStagesUseStableOrderGaps() {
        let stages = BuiltInClipPlugin.defaultPostCaptureStages

        XCTAssertEqual(stages.map(\.order), [10, 20, 30, 40])
        XCTAssertEqual(stages.map(\.pluginID), [
            BuiltInClipPlugin.imageOCR.id,
            BuiltInClipPlugin.translateText.id,
            BuiltInClipPlugin.summarizeText.id,
            BuiltInClipPlugin.addToVocabulary.id,
        ])
    }
}

