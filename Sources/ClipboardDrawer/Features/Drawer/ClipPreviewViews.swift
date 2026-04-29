import AppKit
import Quartz
import SwiftUI

struct ClipPreviewPane: View {
    let clip: ClipItem?
    let onPaste: (ClipItem) -> Void

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
                if let clip {
                    Button("Paste") {
                        onPaste(clip)
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(TechPrimaryButtonStyle())
                }
            }

            Group {
                if let clip {
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
