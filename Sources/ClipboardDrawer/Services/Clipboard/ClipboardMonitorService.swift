import AppKit
import Combine
import Foundation

enum ProBusyKind: String {
    case imageOCR
    case screenshotOCR
    case addToVocabulary
    case aiTranslate
    case aiRewrite
    case aiSummarize

    var statusText: String {
        switch self {
        case .imageOCR: return "Running image OCR..."
        case .screenshotOCR: return "Running screenshot OCR..."
        case .addToVocabulary: return "Saving to vocabulary..."
        case .aiTranslate: return "Translating text with AI..."
        case .aiRewrite: return "Rewriting text with AI..."
        case .aiSummarize: return "Summarizing text with AI..."
        }
    }
}

@MainActor
final class ClipboardMonitorService: ObservableObject {
    @Published private(set) var clips: [ClipItem] = []
    @Published var searchText: String = "" { didSet { refresh() } }
    @Published var filter: ClipFilter = .all { didSet { refresh() } }
    @Published var bannerMessage: String?
    @Published var proResultTitle: String?
    @Published var proResultText: String?
    @Published var proResultClipID: ClipItem.ID?
    @Published var proBusyState: ProBusyKind?

    private let settings: SettingsStore
    private let proActionEngine: ProActionEngine
    private let proFeatureGate: ProFeatureGate
    private let vocabularyStore: VocabularyStore
    private let repository: ClipRepository
    private let payloadStore: PayloadStore
    private let parser: ClipboardParser
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastCapturedHash: String?
    private var uncapturableChangeCount: Int?
    private var uncapturableRetryCount = 0
    private var cancellables: Set<AnyCancellable> = []
    private let maxUncapturableRetries = 5

    init(
        settings: SettingsStore,
        repository: ClipRepository = ClipRepository(),
        payloadStore: PayloadStore = PayloadStore(),
        parser: ClipboardParser = ClipboardParser(),
        vocabularyStore: VocabularyStore = VocabularyStore()
    ) {
        self.settings = settings
        self.repository = repository
        self.payloadStore = payloadStore
        self.parser = parser
        self.vocabularyStore = vocabularyStore
        let aiConfigStore = AIProviderConfigStore(settings: settings)
        let textAIService = OpenAICompatibleTextAIService(configStore: aiConfigStore)
        self.proActionEngine = ProActionEngine(actions: [
            ImageOCRAction(ocrService: OCRService(), settings: settings),
            ScreenshotOCRAction(screenshotService: ScreenshotService(), ocrService: OCRService(), settings: settings),
            AddToVocabularyAction(store: vocabularyStore),
            TranslateTextAction(service: textAIService, settings: settings),
            RewriteTextAction(service: textAIService),
            SummarizeTextAction(service: textAIService),
        ])
        self.proFeatureGate = ProFeatureGate(settings: settings)
        self.lastChangeCount = NSPasteboard.general.changeCount
        self.lastCapturedHash = repository.latestClip()?.contentHash

        settings.$monitoringPaused
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        settings.$historyMaxCount
            .sink { [weak self] maxCount in self?.pruneHistory(maxCount: maxCount); self?.refresh() }
            .store(in: &cancellables)

        refresh()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        clips = repository.fetch(search: searchText, filter: filter, limit: settings.historyMaxCount)
    }

    func clearHistory() {
        repository.clear()
        payloadStore.clearAll()
        lastCapturedHash = nil
        resetUncapturableRetryState()
        refresh()
    }

    func clearCurrentFilter() {
        if filter == .all {
            clearHistory()
            bannerMessage = "Cleared all clipboard history."
            return
        }

        let removedPayloadPaths = repository.payloadPaths(matching: filter)
        repository.delete(matching: filter)
        for path in removedPayloadPaths {
            payloadStore.remove(path: path)
        }
        lastCapturedHash = repository.latestClip()?.contentHash
        resetUncapturableRetryState()
        refresh()
        bannerMessage = "Cleared \(filter.displayName.lowercased()) clips."
    }

    func runImageOCR(for clip: ClipItem) async {
        guard proBusyState == nil else { return }
        proBusyState = .imageOCR
        bannerMessage = ProBusyKind.imageOCR.statusText
        defer { proBusyState = nil }

        do {
            try proFeatureGate.require(.imageOCR)
            guard clip.type == .media,
                  clip.documentURL == nil,
                  payloadStore.read(path: clip.payloadPath) != nil else {
                bannerMessage = "Select an image clip to run OCR."
                return
            }

            let result = try await runPipeline([.imageOCR], trigger: .manual, for: clip)
            handlePipelineTextResult(result, title: "Text", emptyMessage: "No text found in image.", clipID: clip.id)
        } catch ProFeatureError.locked {
            bannerMessage = "Pro OCR is locked."
        } catch {
            bannerMessage = "Image OCR failed: \(error.localizedDescription)"
        }
    }

    func addToVocabulary(for clip: ClipItem) async {
        guard proBusyState == nil else { return }
        proBusyState = .addToVocabulary
        bannerMessage = ProBusyKind.addToVocabulary.statusText
        defer { proBusyState = nil }

        do {
            try proFeatureGate.require(.vocabulary)
            guard settings.proVocabularyEnabled else {
                bannerMessage = "Vocabulary is disabled in settings."
                return
            }
            guard let text = clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                bannerMessage = "Select a text clip to add to vocabulary."
                return
            }

            let result = try await runPipeline([.addToVocabulary], trigger: .manual, for: clip)

            let outcome = result.metadata["result"]
            if outcome == "duplicate" {
                bannerMessage = "Already in vocabulary."
            } else {
                bannerMessage = "Added to vocabulary."
            }
        } catch ProFeatureError.locked {
            bannerMessage = "Pro vocabulary is locked."
        } catch {
            bannerMessage = "Add to vocabulary failed: \(error.localizedDescription)"
        }
    }

    func runAITranslate(for clip: ClipItem) async {
        guard proBusyState == nil else { return }
        proBusyState = .aiTranslate
        bannerMessage = ProBusyKind.aiTranslate.statusText
        defer { proBusyState = nil }

        do {
            try proFeatureGate.require(.aiTranslate)
            guard let text = clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                bannerMessage = "Select a text clip to translate."
                return
            }

            let result = try await runPipeline([.translateText], trigger: .manual, for: clip)
            handlePipelineTextResult(result, title: "Translation", emptyMessage: "No translated text returned.", clipID: clip.id)
        } catch ProFeatureError.locked {
            bannerMessage = "Pro AI Translate is locked."
        } catch {
            proResultTitle = nil
            proResultText = nil
            proResultClipID = nil
            bannerMessage = "AI Translate failed: \(error.localizedDescription)"
        }
    }

    func publishSystemTranslation(_ text: String, for clip: ClipItem) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        proResultTitle = "Translation"
        proResultText = normalizedText
        proResultClipID = clip.id
        bannerMessage = normalizedText.isEmpty ? "No translated text returned." : nil
    }

    func reportSystemTranslationFailure(_ message: String) {
        proResultTitle = nil
        proResultText = nil
        proResultClipID = nil
        bannerMessage = "System translation failed: \(message)"
    }

    func runAIRewrite(for clip: ClipItem) async {
        guard proBusyState == nil else { return }
        proBusyState = .aiRewrite
        bannerMessage = ProBusyKind.aiRewrite.statusText
        defer { proBusyState = nil }

        do {
            try proFeatureGate.require(.aiRewrite)
            guard let text = clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                bannerMessage = "Select a text clip to rewrite."
                return
            }

            let result = try await runPipeline([.rewriteText], trigger: .manual, for: clip)
            handlePipelineTextResult(result, title: "AI Rewrite ready", emptyMessage: "No rewritten text returned.", clipID: clip.id)
        } catch ProFeatureError.locked {
            bannerMessage = "Pro AI Rewrite is locked."
        } catch {
            proResultTitle = nil
            proResultText = nil
            proResultClipID = nil
            bannerMessage = "AI Rewrite failed: \(error.localizedDescription)"
        }
    }

    func runAISummary(for clip: ClipItem) async {
        guard proBusyState == nil else { return }
        proBusyState = .aiSummarize
        bannerMessage = ProBusyKind.aiSummarize.statusText
        defer { proBusyState = nil }

        do {
            try proFeatureGate.require(.aiSummarize)
            guard let text = clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                bannerMessage = "Select a text clip to summarize."
                return
            }

            let result = try await runPipeline([.summarizeText], trigger: .manual, for: clip)
            handlePipelineTextResult(result, title: "AI Summary ready", emptyMessage: "No summary text returned.", clipID: clip.id)
        } catch ProFeatureError.locked {
            bannerMessage = "Pro AI Summary is locked."
        } catch {
            proResultTitle = nil
            proResultText = nil
            proResultClipID = nil
            bannerMessage = "AI Summary failed: \(error.localizedDescription)"
        }
    }

    func runScreenshotOCR() async {
        guard proBusyState == nil else { return }
        proBusyState = .screenshotOCR
        bannerMessage = ProBusyKind.screenshotOCR.statusText
        defer { proBusyState = nil }

        do {
            try proFeatureGate.require(.screenshotOCR)
            let sourceAppName = NSWorkspace.shared.frontmostApplication?.localizedName
            let result = try await proActionEngine.run([
                .screenshotOCR
            ], context: ProActionContext(
                trigger: .manual,
                clipboardItem: nil,
                inputText: nil,
                inputImageData: nil,
                sourceAppName: sourceAppName,
                userPrompt: nil
            ))

            let clipID = try result.imageData.map { try saveScreenshotClip(imageData: $0, sourceAppName: sourceAppName) }
            handleProActionResult(result, title: "Screenshot OCR ready", emptyMessage: "No text found in screenshot.", clipID: clipID)
        } catch ProFeatureError.locked {
            bannerMessage = "Pro screenshot OCR is locked."
        } catch ScreenshotError.cancelled {
            bannerMessage = "Screenshot OCR cancelled."
        } catch {
            bannerMessage = "Screenshot OCR failed: \(error.localizedDescription)"
        }
    }

    func paste(_ clip: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var didWritePasteboard = false

        switch clip.type {
        case .text:
            didWritePasteboard = writePlainTextFallback(clip.plainText, to: pasteboard)
        case .rtf:
            didWritePasteboard = writePlainTextFallback(clip.plainText, to: pasteboard)
            if let data = payloadStore.read(path: clip.payloadPath) {
                didWritePasteboard = pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.rtf")) || didWritePasteboard
            }
        case .html:
            didWritePasteboard = writePlainTextFallback(clip.plainText, to: pasteboard)
            if let data = payloadStore.read(path: clip.payloadPath) {
                didWritePasteboard = pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.html")) || didWritePasteboard
            }
        case .media:
            if let url = clip.documentURL {
                if clip.isImageDocument {
                    didWritePasteboard = writeImageFile(url, to: pasteboard)
                } else {
                    didWritePasteboard = pasteboard.writeObjects([url as NSURL])
                }
            } else if let data = payloadStore.read(path: clip.payloadPath) {
                didWritePasteboard = pasteboard.setData(data, forType: .png)
                if let image = NSImage(data: data) {
                    didWritePasteboard = pasteboard.writeObjects([image]) || didWritePasteboard
                }
            }
        case .document:
            if let url = clip.documentURL {
                let didWriteFile = pasteboard.writeObjects([url as NSURL])
                let didWriteText = writePlainTextFallback(url.path, to: pasteboard)
                didWritePasteboard = didWriteFile || didWriteText
            }
        }

        lastChangeCount = pasteboard.changeCount
        lastCapturedHash = clip.contentHash
        resetUncapturableRetryState()
        if didWritePasteboard {
            promotePastedClipIfNeeded(clip)
        }

        if settings.autoPasteEnabled {
            sendPasteKeystroke()
        }
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let observedChangeCount = pasteboard.changeCount
        guard !settings.monitoringPaused, observedChangeCount != lastChangeCount else {
            return
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        guard !settings.shouldIgnore(appName: frontmostApp?.localizedName, bundleIdentifier: frontmostApp?.bundleIdentifier) else {
            AppLog.clipboard.debug("Ignored clipboard capture from \(frontmostApp?.localizedName ?? "unknown app")")
            markChangeCountConsumed(observedChangeCount)
            return
        }

        guard let parsed = parser.parse(pasteboard, ignoredFileExtensions: settings.ignoredFileExtensions) else {
            markChangeCountUncapturableAfterRetry(observedChangeCount)
            return
        }

        resetUncapturableRetryState()
        if settings.dedupConsecutiveEnabled, parsed.contentHash == lastCapturedHash {
            markChangeCountConsumed(observedChangeCount)
            return
        }

        let id = UUID().uuidString
        var payloadPath: String?
        if let payloadData = parsed.payloadData, let payloadExtension = parsed.payloadExtension {
            do {
                payloadPath = try payloadStore.write(data: payloadData, id: id, fileExtension: payloadExtension)
            } catch {
                AppLog.clipboard.error("Payload write failed: \(error.localizedDescription)")
                bannerMessage = "Failed to save clipboard payload."
                markChangeCountConsumed(observedChangeCount)
                return
            }
        }

        let clip = ClipItem(
            id: id,
            createdAt: Date(),
            type: parsed.type,
            plainText: parsed.plainText,
            payloadPath: payloadPath,
            sourceApp: NSWorkspace.shared.frontmostApplication?.localizedName,
            isPinned: false,
            contentHash: parsed.contentHash,
            origin: .original,
            derivedFromClipID: nil
        )

        do {
            try repository.insert(clip)
            pruneHistory(maxCount: settings.historyMaxCount)
            lastCapturedHash = parsed.contentHash
            markChangeCountConsumed(observedChangeCount)
            refresh()
            runAutomaticOCRIfNeeded(for: clip)
        } catch {
            AppLog.clipboard.error("Clip insert failed: \(error.localizedDescription)")
            bannerMessage = "Failed to save clipboard item."
            markChangeCountConsumed(observedChangeCount)
        }
    }

    private func runAutomaticOCRIfNeeded(for clip: ClipItem) {
        guard settings.proEnabled,
              settings.postCapturePipelineStages.contains(where: { $0.enabled }) else {
            return
        }

        Task { @MainActor in
            await runPostCapturePipeline(for: clip)
        }
    }

    private func runPostCapturePipeline(for clip: ClipItem) async {
        guard proBusyState == nil else { return }
        defer { proBusyState = nil }

        do {
            let plugins = enabledPostCapturePlugins(for: clip)
            guard !plugins.isEmpty else { return }
            proBusyState = plugins.contains(.imageOCR) ? .imageOCR : nil
            if let proBusyState {
                bannerMessage = proBusyState.statusText
            }
            for plugin in plugins {
                try requireFeature(for: plugin)
            }
            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let context = ClipPipelineContext(
                trigger: .postCapture,
                originalClip: clip,
                source: ClipPipelineSource(
                    appName: clip.sourceApp,
                    bundleIdentifier: frontmostApp?.bundleIdentifier,
                    capturedAt: clip.createdAt
                )
            )
            let resultContext = try await makePipelineRunner(for: plugins).run(context)
            if let textArtifact = resultContext.artifacts.last(where: { artifact in
                ["ocr.text", "translation.text", "rewrite.text", "summary.text"].contains(artifact.kind)
            }), case .text(let text) = textArtifact.content {
                handleProActionResult(
                    ProActionResult(text: text, shouldSaveToHistory: true),
                    title: textArtifact.title,
                    emptyMessage: "No text returned.",
                    clipID: clip.id
                )
            } else if resultContext.stageResults.contains(where: { $0.status == .succeeded }) {
                bannerMessage = "Post-copy pipeline complete."
            }
        } catch ProFeatureError.locked {
            bannerMessage = "A Pro pipeline plugin is locked."
        } catch {
            bannerMessage = "Post-copy pipeline failed: \(error.localizedDescription)"
        }
    }

    func copyProResultToPasteboard(derivedFrom clip: ClipItem? = nil) {
        guard let text = proResultText, !text.isEmpty else {
            bannerMessage = "No result to copy."
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        lastCapturedHash = nil
        resetUncapturableRetryState()
        saveProResultToHistory(derivedFrom: clip, successMessage: "Result copied and saved.")
    }

    func saveProResultToHistory(derivedFrom clip: ClipItem?, successMessage: String = "Result saved as derived clip.") {
        guard let text = proResultText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            bannerMessage = "No result to save."
            return
        }

        let derivedClip = ClipItem(
            id: UUID().uuidString,
            createdAt: Date(),
            type: .text,
            plainText: text,
            payloadPath: nil,
            sourceApp: "Clipwell Pro",
            isPinned: false,
            contentHash: parser.hashText(text),
            origin: .proDerived,
            derivedFromClipID: clip?.id
        )

        do {
            try repository.insert(derivedClip)
            pruneHistory(maxCount: settings.historyMaxCount)
            refresh()
            bannerMessage = successMessage
        } catch {
            AppLog.clipboard.error("Saving derived pro result failed: \(error.localizedDescription)")
            bannerMessage = "Failed to save result."
        }
    }

    func updateTextClip(_ clip: ClipItem, text: String) {
        guard clip.type == .text else {
            bannerMessage = "Only text clips can be edited."
            return
        }

        do {
            try repository.updatePlainText(id: clip.id, text: text, contentHash: parser.hashText(text))
            lastCapturedHash = repository.latestClip()?.contentHash
            resetUncapturableRetryState()
            refresh()
            bannerMessage = "Text clip saved."
        } catch {
            AppLog.clipboard.error("Updating text clip failed: \(error.localizedDescription)")
            bannerMessage = "Failed to save text clip."
        }
    }

    private func handleProActionResult(_ result: ProActionResult, title: String, emptyMessage: String, clipID: ClipItem.ID?) {
        let normalizedText = result.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        proResultTitle = title
        proResultText = normalizedText
        proResultClipID = clipID

        guard let text = normalizedText, !text.isEmpty else {
            bannerMessage = emptyMessage
            return
        }

        if result.shouldCopyToPasteboard {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            lastChangeCount = pasteboard.changeCount
            lastCapturedHash = nil
            resetUncapturableRetryState()
        }

        if result.shouldSaveToHistory {
            let clip = ClipItem(
                id: UUID().uuidString,
                createdAt: Date(),
                type: .text,
                plainText: text,
                payloadPath: nil,
                sourceApp: "Clipwell Pro",
                isPinned: false,
                contentHash: parser.hashText(text),
                origin: .proDerived,
                derivedFromClipID: nil
            )
            do {
                try repository.insert(clip)
                pruneHistory(maxCount: settings.historyMaxCount)
                refresh()
            } catch {
                AppLog.clipboard.error("Pro result insert failed: \(error.localizedDescription)")
            }
        }

        if result.shouldPasteImmediately {
            sendPasteKeystroke()
        }

        bannerMessage = nil
    }

    private func runPipeline(_ plugins: [BuiltInClipPlugin], trigger: ClipPipelineTrigger, for clip: ClipItem) async throws -> ClipPipelineContext {
        for plugin in plugins {
            try requireFeature(for: plugin)
        }
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let context = ClipPipelineContext(
            trigger: trigger,
            originalClip: clip,
            source: ClipPipelineSource(
                appName: clip.sourceApp,
                bundleIdentifier: frontmostApp?.bundleIdentifier,
                capturedAt: clip.createdAt
            )
        )
        return try await makePipelineRunner(for: plugins).run(context)
    }

    private func handlePipelineTextResult(_ context: ClipPipelineContext, title: String, emptyMessage: String, clipID: ClipItem.ID?) {
        if case .text(let text) = context.current {
            handleProActionResult(
                ProActionResult(text: text, shouldSaveToHistory: false),
                title: context.artifacts.last?.title ?? title,
                emptyMessage: emptyMessage,
                clipID: clipID
            )
            return
        }

        guard let textArtifact = context.artifacts.last(where: { artifact in
            if case .text = artifact.content { return true }
            return false
        }), case .text(let text) = textArtifact.content else {
            bannerMessage = emptyMessage
            return
        }

        handleProActionResult(
            ProActionResult(text: text, shouldSaveToHistory: false),
            title: textArtifact.title,
            emptyMessage: emptyMessage,
            clipID: clipID
        )
    }

    private func makePipelineRunner(for plugins: [BuiltInClipPlugin]) -> ClipPipelineRunner {
        ClipPipelineRunner(plugins: plugins.map {
            BuiltInProActionPipelinePlugin(builtInPlugin: $0, engine: proActionEngine, payloadStore: payloadStore)
        })
    }

    private func enabledPostCapturePlugins(for clip: ClipItem) -> [BuiltInClipPlugin] {
        settings.postCapturePipelineStages
            .filter(\.enabled)
            .sorted { lhs, rhs in
                lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order
            }
            .compactMap { stage in
                guard stage.triggers.contains(.postCapture),
                      let plugin = BuiltInClipPlugin.allCases.first(where: { $0.id == stage.pluginID }) else {
                    return nil
                }
                return plugin
            }
    }

    private func requireFeature(for plugin: BuiltInClipPlugin) throws {
        switch plugin {
        case .imageOCR:
            try proFeatureGate.require(.imageOCR)
        case .translateText:
            try proFeatureGate.require(.aiTranslate)
        case .rewriteText:
            try proFeatureGate.require(.aiRewrite)
        case .summarizeText:
            try proFeatureGate.require(.aiSummarize)
        case .addToVocabulary:
            try proFeatureGate.require(.vocabulary)
        }
    }

    private func saveScreenshotClip(imageData: Data, sourceAppName: String?) throws -> ClipItem.ID {
        let id = UUID().uuidString
        let payloadPath = try payloadStore.write(data: imageData, id: id, fileExtension: "png")
        let contentHash = parser.hashData(imageData)
        let clip = ClipItem(
            id: id,
            createdAt: Date(),
            type: .media,
            plainText: nil,
            payloadPath: payloadPath,
            sourceApp: sourceAppName ?? "Screenshot",
            isPinned: false,
            contentHash: contentHash,
            origin: .original,
            derivedFromClipID: nil
        )

        try repository.insert(clip)
        pruneHistory(maxCount: settings.historyMaxCount)
        lastCapturedHash = contentHash
        resetUncapturableRetryState()
        refresh()
        return id
    }

    private func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func writePlainTextFallback(_ text: String?, to pasteboard: NSPasteboard) -> Bool {
        guard let text, !text.isEmpty else {
            return false
        }
        return pasteboard.setString(text, forType: .string)
    }

    private func writeImageFile(_ url: URL, to pasteboard: NSPasteboard) -> Bool {
        guard let image = NSImage(contentsOf: url) else {
            return pasteboard.writeObjects([url as NSURL])
        }

        var didWrite = false
        if let pngData = pngData(from: image) {
            didWrite = pasteboard.setData(pngData, forType: .png)
        }
        return pasteboard.writeObjects([image]) || didWrite
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func pruneHistory(maxCount: Int) {
        let removedPayloadPaths = repository.payloadPathsBeyondLimit(maxCount: maxCount)
        repository.prune(maxCount: maxCount)
        for path in removedPayloadPaths {
            payloadStore.remove(path: path)
        }
    }

    private func markChangeCountConsumed(_ changeCount: Int) {
        lastChangeCount = changeCount
        resetUncapturableRetryState()
    }

    private func markChangeCountUncapturableAfterRetry(_ changeCount: Int) {
        if uncapturableChangeCount == changeCount {
            uncapturableRetryCount += 1
        } else {
            uncapturableChangeCount = changeCount
            uncapturableRetryCount = 1
        }

        if uncapturableRetryCount >= maxUncapturableRetries {
            markChangeCountConsumed(changeCount)
        }
    }

    private func resetUncapturableRetryState() {
        uncapturableChangeCount = nil
        uncapturableRetryCount = 0
    }

    private func promotePastedClipIfNeeded(_ clip: ClipItem) {
        guard repository.latestClip()?.contentHash != clip.contentHash else {
            return
        }

        let id = UUID().uuidString
        do {
            let promotedPayloadPath = try payloadStore.duplicate(path: clip.payloadPath, id: id)
            let promotedClip = ClipItem(
                id: id,
                createdAt: Date(),
                type: clip.type,
                plainText: clip.plainText,
                payloadPath: promotedPayloadPath,
                sourceApp: clip.sourceApp,
                isPinned: false,
                contentHash: clip.contentHash,
                origin: clip.origin,
                derivedFromClipID: clip.derivedFromClipID
            )
            try repository.insert(promotedClip)
            pruneHistory(maxCount: settings.historyMaxCount)
            refresh()
        } catch {
            AppLog.clipboard.error("Promoting pasted clip failed: \(error.localizedDescription)")
            bannerMessage = "Pasted, but failed to move item to top."
        }
    }
}
