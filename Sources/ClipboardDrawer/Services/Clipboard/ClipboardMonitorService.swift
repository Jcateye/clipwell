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
    private var cancellables: Set<AnyCancellable> = []

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
                  let imageData = payloadStore.read(path: clip.payloadPath) else {
                bannerMessage = "Select an image clip to run OCR."
                return
            }

            let result = try await proActionEngine.run([
                .imageOCR
            ], context: ProActionContext(
                trigger: .manual,
                clipboardItem: clip,
                inputText: clip.plainText,
                inputImageData: imageData,
                sourceAppName: clip.sourceApp,
                userPrompt: nil
            ))

            handleProActionResult(result, title: "Image OCR ready", emptyMessage: "No text found in image.")
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

            let result = try await proActionEngine.run([
                .addToVocabulary
            ], context: ProActionContext(
                trigger: .manual,
                clipboardItem: clip,
                inputText: text,
                inputImageData: nil,
                sourceAppName: clip.sourceApp,
                userPrompt: nil
            ))

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

            let result = try await proActionEngine.run([
                .translateText
            ], context: ProActionContext(
                trigger: .manual,
                clipboardItem: clip,
                inputText: text,
                inputImageData: nil,
                sourceAppName: clip.sourceApp,
                userPrompt: nil
            ))

            handleProActionResult(result, title: "AI Translate ready", emptyMessage: "No translated text returned.")
        } catch ProFeatureError.locked {
            bannerMessage = "Pro AI Translate is locked."
        } catch {
            proResultTitle = nil
            proResultText = nil
            bannerMessage = "AI Translate failed: \(error.localizedDescription)"
        }
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

            let result = try await proActionEngine.run([
                .rewriteText
            ], context: ProActionContext(
                trigger: .manual,
                clipboardItem: clip,
                inputText: text,
                inputImageData: nil,
                sourceAppName: clip.sourceApp,
                userPrompt: nil
            ))

            handleProActionResult(result, title: "AI Rewrite ready", emptyMessage: "No rewritten text returned.")
        } catch ProFeatureError.locked {
            bannerMessage = "Pro AI Rewrite is locked."
        } catch {
            proResultTitle = nil
            proResultText = nil
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

            let result = try await proActionEngine.run([
                .summarizeText
            ], context: ProActionContext(
                trigger: .manual,
                clipboardItem: clip,
                inputText: text,
                inputImageData: nil,
                sourceAppName: clip.sourceApp,
                userPrompt: nil
            ))

            handleProActionResult(result, title: "AI Summary ready", emptyMessage: "No summary text returned.")
        } catch ProFeatureError.locked {
            bannerMessage = "Pro AI Summary is locked."
        } catch {
            proResultTitle = nil
            proResultText = nil
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
            let result = try await proActionEngine.run([
                .screenshotOCR
            ], context: ProActionContext(
                trigger: .manual,
                clipboardItem: nil,
                inputText: nil,
                inputImageData: nil,
                sourceAppName: NSWorkspace.shared.frontmostApplication?.localizedName,
                userPrompt: nil
            ))

            handleProActionResult(result, title: "Screenshot OCR ready", emptyMessage: "No text found in screenshot.")
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
            didWritePasteboard = pasteboard.setString(clip.plainText ?? "", forType: .string)
        case .rtf:
            if let data = payloadStore.read(path: clip.payloadPath) {
                didWritePasteboard = pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.rtf"))
                if let plainText = clip.plainText {
                    pasteboard.setString(plainText, forType: .string)
                }
            }
        case .html:
            if let data = payloadStore.read(path: clip.payloadPath) {
                didWritePasteboard = pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.html"))
                if let plainText = clip.plainText {
                    pasteboard.setString(plainText, forType: .string)
                }
            }
        case .media:
            if let url = clip.documentURL {
                didWritePasteboard = pasteboard.writeObjects([url as NSURL])
            } else if let data = payloadStore.read(path: clip.payloadPath) {
                didWritePasteboard = pasteboard.setData(data, forType: .png)
                if let image = NSImage(data: data) {
                    didWritePasteboard = pasteboard.writeObjects([image]) || didWritePasteboard
                }
            }
        case .document:
            if let url = clip.documentURL {
                didWritePasteboard = pasteboard.writeObjects([url as NSURL])
            }
        }

        lastChangeCount = pasteboard.changeCount
        lastCapturedHash = clip.contentHash
        if didWritePasteboard {
            promotePastedClipIfNeeded(clip)
        }

        if settings.autoPasteEnabled {
            sendPasteKeystroke()
        }
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard !settings.monitoringPaused, pasteboard.changeCount != lastChangeCount else {
            return
        }
        lastChangeCount = pasteboard.changeCount

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        guard !settings.shouldIgnore(appName: frontmostApp?.localizedName, bundleIdentifier: frontmostApp?.bundleIdentifier) else {
            AppLog.clipboard.debug("Ignored clipboard capture from \(frontmostApp?.localizedName ?? "unknown app")")
            return
        }

        guard let parsed = parser.parse(pasteboard, ignoredFileExtensions: settings.ignoredFileExtensions) else {
            return
        }

        if settings.dedupConsecutiveEnabled, parsed.contentHash == lastCapturedHash {
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
            refresh()
        } catch {
            AppLog.clipboard.error("Clip insert failed: \(error.localizedDescription)")
            bannerMessage = "Failed to save clipboard item."
        }
    }

    func copyProResultToPasteboard() {
        guard let text = proResultText, !text.isEmpty else {
            bannerMessage = "No result to copy."
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        lastCapturedHash = nil
        bannerMessage = "Result copied."
    }

    func pasteProResult() {
        guard let text = proResultText, !text.isEmpty else {
            bannerMessage = "No result to paste."
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        lastCapturedHash = nil
        sendPasteKeystroke()
        bannerMessage = "Result pasted."
    }

    func saveProResultToHistory(derivedFrom clip: ClipItem?) {
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
            bannerMessage = "Result saved as derived clip."
        } catch {
            AppLog.clipboard.error("Saving derived pro result failed: \(error.localizedDescription)")
            bannerMessage = "Failed to save result."
        }
    }

    private func handleProActionResult(_ result: ProActionResult, title: String, emptyMessage: String) {
        let normalizedText = result.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        proResultTitle = title
        proResultText = normalizedText

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

        bannerMessage = "\(title) · result ready"
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

    private func pruneHistory(maxCount: Int) {
        let removedPayloadPaths = repository.payloadPathsBeyondLimit(maxCount: maxCount)
        repository.prune(maxCount: maxCount)
        for path in removedPayloadPaths {
            payloadStore.remove(path: path)
        }
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
