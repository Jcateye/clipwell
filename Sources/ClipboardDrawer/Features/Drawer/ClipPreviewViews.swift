import AppKit
import Quartz
import SwiftUI

struct ClipPreviewPane: View {
    let clip: ClipItem?
    let proResultTitle: String?
    let proResultText: String?
    let proBusyState: ProBusyKind?
    let onPaste: (ClipItem) -> Void
    let onImageOCR: (ClipItem) -> Void
    let onAddToVocabulary: (ClipItem) -> Void
    let onAITranslate: (ClipItem) -> Void
    let onAIRewrite: (ClipItem) -> Void
    let onAISummary: (ClipItem) -> Void
    let onScreenshotOCR: () -> Void
    let onCopyProResult: () -> Void
    let onPasteProResult: () -> Void
    let onSaveProResult: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("PREVIEW")
                        .font(TechTheme.labelFont)
                        .tracking(0.9)
                        .foregroundStyle(TechTheme.text)
                    if let clip {
                        Text(clip.kindDisplayName.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(TechTheme.cyan)
                    }
                }
                Spacer()
                if let proResultText, !proResultText.isEmpty {
                    HStack(spacing: 8) {
                        Button("Copy Result") {
                            onCopyProResult()
                        }
                        .buttonStyle(TechSecondaryButtonStyle())
                        .disabled(proBusyState != nil)
                        Button("Save Result") {
                            onSaveProResult()
                        }
                        .buttonStyle(TechSecondaryButtonStyle())
                        .disabled(proBusyState != nil)
                        Button("Paste Result") {
                            onPasteProResult()
                        }
                        .buttonStyle(TechPrimaryButtonStyle())
                        .disabled(proBusyState != nil)
                        Button(proBusyState == .screenshotOCR ? "Shot OCR…" : "Shot OCR") {
                            onScreenshotOCR()
                        }
                        .buttonStyle(TechSecondaryButtonStyle())
                        .disabled(proBusyState != nil)
                    }
                } else if let clip {
                    HStack(spacing: 8) {
                        if clip.type == .media, clip.documentURL == nil {
                            Button(proBusyState == .imageOCR ? "Image OCR…" : "Image OCR") {
                                onImageOCR(clip)
                            }
                            .buttonStyle(TechSecondaryButtonStyle())
                            .disabled(proBusyState != nil)
                        }
                        if clip.type == .text || clip.type == .rtf || clip.type == .html {
                            Button(proBusyState == .addToVocabulary ? "Add Word…" : "Add Word") {
                                onAddToVocabulary(clip)
                            }
                            .buttonStyle(TechSecondaryButtonStyle())
                            .disabled(proBusyState != nil)
                            Button(proBusyState == .aiTranslate ? "Translate…" : "Translate") {
                                onAITranslate(clip)
                            }
                            .buttonStyle(TechSecondaryButtonStyle())
                            .disabled(proBusyState != nil)
                            Button(proBusyState == .aiRewrite ? "Rewrite…" : "Rewrite") {
                                onAIRewrite(clip)
                            }
                            .buttonStyle(TechSecondaryButtonStyle())
                            .disabled(proBusyState != nil)
                            Button(proBusyState == .aiSummarize ? "Summarize…" : "Summarize") {
                                onAISummary(clip)
                            }
                            .buttonStyle(TechSecondaryButtonStyle())
                            .disabled(proBusyState != nil)
                        }
                        Button(proBusyState == .screenshotOCR ? "Shot OCR…" : "Shot OCR") {
                            onScreenshotOCR()
                        }
                        .buttonStyle(TechSecondaryButtonStyle())
                        .disabled(proBusyState != nil)
                        Button("Paste") {
                            onPaste(clip)
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(TechPrimaryButtonStyle())
                        .disabled(proBusyState != nil)
                    }
                } else {
                    Button(proBusyState == .screenshotOCR ? "Shot OCR…" : "Shot OCR") {
                        onScreenshotOCR()
                    }
                    .buttonStyle(TechSecondaryButtonStyle())
                    .disabled(proBusyState != nil)
                }
            }

            Group {
                if let proBusyState {
                    busyView(proBusyState.statusText)
                } else if let proResultText, !proResultText.isEmpty {
                    proResultView(title: proResultTitle ?? "Pro Result", text: proResultText)
                } else if let clip {
                    preview(for: clip)
                } else {
                    ContentUnavailableView(
                        "No clip selected",
                        systemImage: "rectangle.dashed",
                        description: Text("Select media or a document to preview it here.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .techCard(cornerRadius: 18)
        }
    }

    @ViewBuilder
    private func preview(for clip: ClipItem) -> some View {
        switch clip.type {
        case .media:
            if let url = clip.documentURL {
                QuickLookPreview(url: url)
            } else if let path = clip.payloadPath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            } else {
                unavailable("Media payload is unavailable.")
            }
        case .rtf:
            if let path = clip.payloadPath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) {
                RichTextPreview(attributedString: attributedString)
            } else {
                textPreview(clip.plainText ?? "Rich text payload is unavailable.")
            }
        case .html:
            if let path = clip.payloadPath, let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let attributedString = NSAttributedString(html: data, documentAttributes: nil) {
                RichTextPreview(attributedString: attributedString)
            } else {
                textPreview(clip.plainText ?? "HTML payload is unavailable.")
            }
        case .document:
            if let url = clip.documentURL {
                QuickLookPreview(url: url)
            } else {
                unavailable("Document URL is unavailable.")
            }
        case .text:
            textPreview(clip.plainText ?? "")
        }
    }

    private func busyView(_ text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(TechTheme.cyan)
            Text(text)
                .font(.system(size: 13.5, weight: .medium))
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
                    .tracking(0.8)
                    .foregroundStyle(TechTheme.cyan)
                Spacer()
                Text("TEXT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(TechTheme.green)
            }
            textPreview(text)
        }
        .padding(12)
    }

    private func textPreview(_ value: String) -> some View {
        ScrollView {
            Text(value.isEmpty ? "Empty text clip" : value)
                .font(.system(size: 13.5, weight: .medium))
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

struct TechPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TechTheme.labelFont)
            .foregroundStyle(TechTheme.onAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(TechTheme.cyan)
                    .shadow(color: TechTheme.cyan.opacity(configuration.isPressed ? 0.18 : 0.38), radius: configuration.isPressed ? 4 : 10)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
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
        textView.textContainerInset = NSSize(width: 10, height: 10)
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
        return previewView
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }
}
