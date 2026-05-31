import XCTest
@testable import ClipboardDrawer

private struct TestPipelinePlugin: ClipPipelinePlugin {
    let id: String
    let name: String
    let shouldProcess: Bool
    let transform: @Sendable (ClipPipelineContext) throws -> ClipPipelineContext

    init(
        id: String,
        name: String,
        shouldProcess: Bool = true,
        transform: @escaping @Sendable (ClipPipelineContext) throws -> ClipPipelineContext
    ) {
        self.id = id
        self.name = name
        self.shouldProcess = shouldProcess
        self.transform = transform
    }

    func canProcess(_ context: ClipPipelineContext) async -> Bool {
        shouldProcess
    }

    func process(_ context: ClipPipelineContext) async throws -> ClipPipelineContext {
        try transform(context)
    }
}

private enum TestPipelineError: Error {
    case failed
}

final class ClipPipelineRunnerTests: XCTestCase {
    func testRunPassesUpdatedContextToFollowingPlugin() async throws {
        let clip = makeTextClip("hello")
        let runner = ClipPipelineRunner(plugins: [
            TestPipelinePlugin(id: "prefix", name: "Prefix") { context in
                var next = context
                next.current = .text("rewritten: hello")
                return next
            },
            TestPipelinePlugin(id: "summary", name: "Summary") { context in
                var next = context
                if case .text(let text) = context.current {
                    next.current = .text("summary: \(text)")
                }
                return next
            },
        ])

        let result = try await runner.run(makeContext(clip: clip))

        if case .text(let text) = result.current {
            XCTAssertEqual(text, "summary: rewritten: hello")
        } else {
            XCTFail("Expected text output")
        }
        XCTAssertEqual(result.stageResults.map(\.pluginID), ["prefix", "summary"])
        XCTAssertEqual(result.stageResults.map(\.status), [.succeeded, .succeeded])
    }

    func testRunRecordsSkippedPlugins() async throws {
        let runner = ClipPipelineRunner(plugins: [
            TestPipelinePlugin(id: "skip", name: "Skip", shouldProcess: false) { context in
                XCTFail("Skipped plugin should not process")
                return context
            },
        ])

        let result = try await runner.run(makeContext(clip: makeTextClip("hello")))

        XCTAssertEqual(result.stageResults.count, 1)
        XCTAssertEqual(result.stageResults.first?.pluginID, "skip")
        XCTAssertEqual(result.stageResults.first?.status, .skipped)
    }

    func testRunContinuesAfterFailureByDefault() async throws {
        let runner = ClipPipelineRunner(plugins: [
            TestPipelinePlugin(id: "fail", name: "Fail") { _ in
                throw TestPipelineError.failed
            },
            TestPipelinePlugin(id: "recover", name: "Recover") { context in
                var next = context
                next.current = .text("recovered")
                return next
            },
        ])

        let result = try await runner.run(makeContext(clip: makeTextClip("hello")))

        XCTAssertEqual(result.stageResults.map(\.status), [.failed, .succeeded])
        if case .text(let text) = result.current {
            XCTAssertEqual(text, "recovered")
        } else {
            XCTFail("Expected text output")
        }
    }

    private func makeContext(clip: ClipItem) -> ClipPipelineContext {
        ClipPipelineContext(
            trigger: .postCapture,
            originalClip: clip,
            source: ClipPipelineSource(
                appName: "Tests",
                bundleIdentifier: "com.example.tests",
                capturedAt: clip.createdAt
            )
        )
    }

    private func makeTextClip(_ text: String) -> ClipItem {
        ClipItem(
            id: UUID().uuidString,
            createdAt: Date(),
            type: .text,
            plainText: text,
            payloadPath: nil,
            sourceApp: "Tests",
            isPinned: false,
            contentHash: text,
            origin: .original,
            derivedFromClipID: nil
        )
    }
}

