import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardMonitorService: ObservableObject {
    @Published private(set) var clips: [ClipItem] = []
    @Published var searchText: String = "" { didSet { refresh() } }
    @Published var filter: ClipFilter = .all { didSet { refresh() } }
    @Published var bannerMessage: String?

    private let settings: SettingsStore
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
        parser: ClipboardParser = ClipboardParser()
    ) {
        self.settings = settings
        self.repository = repository
        self.payloadStore = payloadStore
        self.parser = parser
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
            contentHash: parsed.contentHash
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
                contentHash: clip.contentHash
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
