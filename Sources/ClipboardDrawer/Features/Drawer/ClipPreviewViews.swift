import AppKit
import Quartz
import SwiftUI
import Translation

struct ClipPreviewPane: View {
    let clip: ClipItem?
    let proResultTitle: String?
    let proResultText: String?
    let proBusyState: ProBusyKind?
    let useConfiguredAITranslation: Bool
    let translationSourceLanguage: TranslationLanguage
    let translationTargetLanguage: TranslationLanguage
    let onPaste: (ClipItem) -> Void
    let onImageOCR: (ClipItem) -> Void
    let onAITranslate: (ClipItem) -> Void
    let onSystemTranslateResult: (ClipItem, String) -> Void
    let onSystemTranslateFailure: (String) -> Void
    let onCopyProResult: () -> Void
    let onSaveTextClip: (ClipItem, String) -> Void
    @State private var displayMode: PreviewDisplayMode = .original
    @State private var systemTranslationConfiguration: TranslationSession.Configuration?
    @State private var systemTranslationText = ""
    @State private var systemTranslationClip: ClipItem?
    @State private var isSystemTranslating = false

    var body: some View {
        let hasResult = proResultText?.isEmpty == false
        let isBusy = proBusyState != nil || isSystemTranslating

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(alignment: .center, spacing: 8) {
                    Text("PREVIEW")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(TechTheme.text)
                    if let statusLabel {
                        Text(statusLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(TechTheme.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(TechTheme.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                if hasResult {
                    HStack(spacing: 6) {
                        displayModePicker
                        Button {
                            onCopyProResult()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(TechPrimaryButtonStyle())
                        .disabled(isBusy)
                    }
                } else if let clip {
                    HStack(spacing: 8) {
                        if clip.type == .text || clip.type == .rtf || clip.type == .html {
                            Button {
                                translate(clip)
                            } label: {
                                Label(proBusyState == .aiTranslate || isSystemTranslating ? "Translating" : "Translate", systemImage: "character.bubble")
                            }
                            .buttonStyle(TechSecondaryButtonStyle())
                            .disabled(isBusy)
                        }
                        if canConvertImageToText(clip) {
                            Button {
                                onImageOCR(clip)
                            } label: {
                                Label(proBusyState == .imageOCR ? "Reading" : "To Text", systemImage: "text.viewfinder")
                            }
                            .buttonStyle(TechSecondaryButtonStyle())
                            .disabled(isBusy)
                        }
                        Button {
                            onPaste(clip)
                        } label: {
                            Label("Paste", systemImage: "arrowshape.turn.up.right")
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(TechPrimaryButtonStyle())
                        .disabled(isBusy)
                    }
                }
            }

            Group {
                if let proBusyState {
                    busyView(proBusyState.statusText)
                } else if isSystemTranslating {
                    busyView("Translating with macOS...")
                } else if displayMode == .result, let proResultText, !proResultText.isEmpty {
                    proResultView(title: proResultTitle ?? "Pro Result", text: proResultText)
                } else if let clip {
                    preview(for: clip)
                } else if let proResultText, !proResultText.isEmpty {
                    proResultView(title: proResultTitle ?? "Pro Result", text: proResultText)
                } else {
                    ContentUnavailableView(
                        "No clip selected",
                        systemImage: "rectangle.dashed",
                        description: Text("Select media or a document to preview it here.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TechTheme.line.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TechTheme.line, lineWidth: 1)
        )
        .onChange(of: clip?.id) { _, _ in
            displayMode = .original
        }
        .onChange(of: proResultText) { _, text in
            displayMode = text?.isEmpty == false ? .result : .original
        }
        .translationTask(systemTranslationConfiguration) { session in
            guard let clip = systemTranslationClip, !systemTranslationText.isEmpty else { return }
            let text = systemTranslationText
            nonisolated(unsafe) let translationSession = session
            do {
                let response = try await translationSession.translate(text)
                await MainActor.run {
                    isSystemTranslating = false
                    onSystemTranslateResult(clip, response.targetText)
                }
            } catch {
                await MainActor.run {
                    isSystemTranslating = false
                    onSystemTranslateFailure(error.localizedDescription)
                }
            }
        }
    }

    private var statusLabel: String? {
        if proResultText?.isEmpty == false {
            return proResultTitle?.capitalized ?? "Result Ready"
        } else {
            return clip?.kindDisplayName.capitalized
        }
    }

    private func canConvertImageToText(_ clip: ClipItem) -> Bool {
        clip.type == .media && clip.documentURL == nil
    }

    private func translate(_ clip: ClipItem) {
        if useConfiguredAITranslation {
            onAITranslate(clip)
            return
        }

        guard let text = clip.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            onSystemTranslateFailure("Select a text clip to translate.")
            return
        }

        systemTranslationText = text
        systemTranslationClip = clip
        isSystemTranslating = true
        var configuration = TranslationSession.Configuration(
            source: TranslationLanguageResolver.sourceLocaleLanguage(translationSourceLanguage),
            target: TranslationLanguageResolver.targetLocaleLanguage(translationTargetLanguage)
        )
        configuration.invalidate()
        systemTranslationConfiguration = configuration
    }

    private var displayModePicker: some View {
        HStack(spacing: 3) {
            ForEach(PreviewDisplayMode.allCases) { mode in
                Button {
                    displayMode = mode
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(displayMode == mode ? TechTheme.onAccent : TechTheme.muted)
                        .frame(width: 28, height: 26)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(displayMode == mode ? TechTheme.green : Color.clear)
                        }
                }
                .buttonStyle(.plain)
                .help(mode.helpText)
                .disabled(mode == .original && clip == nil)
                .opacity(mode == .original && clip == nil ? 0.45 : 1)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(TechTheme.line.opacity(0.55), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func preview(for clip: ClipItem) -> some View {
        switch clip.type {
        case .media:
            if let url = clip.documentURL {
                ClickableQuickLookPreview(url: url, title: clip.title)
            } else if let path = clip.payloadPath, let image = NSImage(contentsOfFile: path) {
                Button {
                    ImagePreviewWindowController.shared.show(image: image, title: clip.title)
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(12)

                        PreviewBadge()
                            .padding(12)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                unavailable("Media payload is unavailable.")
            }
        case .rtf:
            if let path = clip.payloadPath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let attributedString = NSAttributedString(rtf: data, documentAttributes: nil),
               !attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                RichTextPreview(attributedString: attributedString)
            } else {
                textPreview(clip.plainText ?? "Rich text payload is unavailable.")
            }
        case .html:
            if let path = clip.payloadPath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let attributedString = NSAttributedString(html: data, documentAttributes: nil),
               !attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                RichTextPreview(attributedString: attributedString)
            } else {
                textPreview(clip.plainText ?? "HTML payload is unavailable.")
            }
        case .document:
            if let url = clip.documentURL {
                ClickableQuickLookPreview(url: url, title: clip.title)
            } else {
                unavailable("Document URL is unavailable.")
            }
        case .text:
            EditableTextPreview(clip: clip, onSave: onSaveTextClip)
        }
    }

    private func busyView(_ text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(TechTheme.green)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TechTheme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func proResultView(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(TechTheme.labelFont)
                    .tracking(0.5)
                    .foregroundStyle(TechTheme.green)
                Spacer()
                Text("TEXT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(TechTheme.muted)
            }
            textPreview(text)
        }
        .padding(14)
    }

    private func textPreview(_ value: String) -> some View {
        ScrollView {
            Text(value.isEmpty ? "Empty text clip" : value)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(TechTheme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }

    private func unavailable(_ message: String) -> some View {
        ContentUnavailableView("Preview unavailable", systemImage: "eye.slash", description: Text(message))
    }

}

private struct EditableTextPreview: View {
    let clip: ClipItem
    let onSave: (ClipItem, String) -> Void
    @State private var draft: String

    init(clip: ClipItem, onSave: @escaping (ClipItem, String) -> Void) {
        self.clip = clip
        self.onSave = onSave
        _draft = State(initialValue: clip.plainText ?? "")
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: $draft)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(TechTheme.text)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(TechTheme.surface.opacity(TechTheme.palette.surfaceOpacity))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isDirty ? TechTheme.green.opacity(0.75) : TechTheme.line.opacity(0.7), lineWidth: 1)
                        }
                }

            if isDirty {
                Button {
                    onSave(clip, draft)
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(TechPrimaryButtonStyle())
                .keyboardShortcut("s", modifiers: [.command])
                .padding(10)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .padding(10)
        .onChange(of: clip.id) { _, _ in
            draft = clip.plainText ?? ""
        }
        .onChange(of: clip.plainText) { _, text in
            guard !isDirty else { return }
            draft = text ?? ""
        }
    }

    private var isDirty: Bool {
        draft != (clip.plainText ?? "")
    }
}

private enum PreviewDisplayMode: String, CaseIterable, Identifiable {
    case original
    case result

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .original: "photo"
        case .result: "text.alignleft"
        }
    }

    var helpText: String {
        switch self {
        case .original: "Show original clip"
        case .result: "Show OCR or AI result"
        }
    }
}

struct TechPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.white)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: NSColor(red: 32/255, green: 138/255, blue: 78/255, alpha: 1.0)))
                    .shadow(color: Color.black.opacity(configuration.isPressed ? 0.05 : 0.1), radius: configuration.isPressed ? 2 : 4, y: configuration.isPressed ? 1 : 2)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct RichTextPreview: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else {
            return
        }
        textView.textStorage?.setAttributedString(attributedString)
    }
}

struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        previewView.autostarts = true
        previewView.enclosingScrollView?.autohidesScrollers = true
        previewView.enclosingScrollView?.scrollerStyle = .overlay
        return previewView
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
        nsView.enclosingScrollView?.autohidesScrollers = true
        nsView.enclosingScrollView?.scrollerStyle = .overlay
    }
}

@MainActor
private struct ClickableQuickLookPreview: View {
    let url: URL
    let title: String

    var body: some View {
        Button {
            DocumentPreviewWindowController.shared.show(url: url, title: title)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                QuickLookPreview(url: url)
                PreviewBadge()
                    .padding(14)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PreviewBadge: View {
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(TechTheme.text.opacity(0.85))
            .frame(width: 32, height: 32)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(TechTheme.surface.opacity(0.6))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(TechTheme.line.opacity(0.4), lineWidth: 1)
            }
            .help("Preview")
    }
}

@MainActor
final class ImagePreviewWindowController {
    static let shared = ImagePreviewWindowController()

    private var window: NSWindow?

    func show(image: NSImage, title: String) {
        let previewWindow = window ?? makeWindow()
        previewWindow.title = title
        previewWindow.contentView = NSHostingView(rootView: LargeImagePreview(image: image, title: title))
        previewWindow.center()
        previewWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = previewWindow
    }

    private func makeWindow() -> NSWindow {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width = min(screenFrame.width * 0.82, 980)
        let height = min(screenFrame.height * 0.82, 760)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 320)
        return window
    }
}

@MainActor
final class DocumentPreviewWindowController {
    static let shared = DocumentPreviewWindowController()

    private var window: NSWindow?

    func show(url: URL, title: String) {
        let previewWindow = window ?? makeWindow()
        previewWindow.title = title
        previewWindow.contentView = NSHostingView(rootView: LargeDocumentPreview(url: url, title: title))
        previewWindow.center()
        previewWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = previewWindow
    }

    private func makeWindow() -> NSWindow {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width = min(screenFrame.width * 0.82, 980)
        let height = min(screenFrame.height * 0.82, 760)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 320)
        return window
    }
}

private struct LargeImagePreview: View {
    let image: NSImage
    let title: String

    var body: some View {
        ZStack {
            TechBackground(theme: TechTheme.activeTheme)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TechTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(image.size.width)) x \(Int(image.size.height))")
                        .font(TechTheme.monoFont)
                        .foregroundStyle(TechTheme.muted)
                }

                GeometryReader { proxy in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                    }
                    .background(TechTheme.surface.opacity(0.34), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(TechTheme.line.opacity(0.75), lineWidth: 1)
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}

private struct LargeDocumentPreview: View {
    let url: URL
    let title: String

    var body: some View {
        ZStack {
            TechBackground(theme: TechTheme.activeTheme)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TechTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Text(url.pathExtension.uppercased())
                        .font(TechTheme.monoFont)
                        .foregroundStyle(TechTheme.muted)
                }

                QuickLookPreview(url: url)
                    .background(TechTheme.surface.opacity(0.34), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(TechTheme.line.opacity(0.75), lineWidth: 1)
                    }
            }
            .padding(20)
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}
