import SwiftUI

struct DrawerView: View {
    @ObservedObject var monitor: ClipboardMonitorService
    @ObservedObject var settings: SettingsStore
    var onPaste: (ClipItem) -> Void
    @State private var selectedClipID: ClipItem.ID?
    @State private var keyboardMonitor: Any?
    @State private var confirmingClearFilter = false

    var body: some View {
        ZStack {
            TechBackground()

            VStack(spacing: 14) {
                header
                if let bannerMessage = monitor.bannerMessage, !bannerMessage.isEmpty {
                    bannerView(bannerMessage)
                }
                searchBar
                filterBar
                clipList
                if settings.previewEnabled {
                    ClipPreviewPane(
                        clip: selectedClip,
                        proResultTitle: monitor.proResultTitle,
                        proResultText: monitor.proResultText,
                        proBusyState: monitor.proBusyState,
                        onPaste: onPaste,
                        onImageOCR: { clip in
                            Task { await monitor.runImageOCR(for: clip) }
                        },
                        onAddToVocabulary: { clip in
                            Task { await monitor.addToVocabulary(for: clip) }
                        },
                        onAITranslate: { clip in
                            Task { await monitor.runAITranslate(for: clip) }
                        },
                        onAIRewrite: { clip in
                            Task { await monitor.runAIRewrite(for: clip) }
                        },
                        onAISummary: { clip in
                            Task { await monitor.runAISummary(for: clip) }
                        },
                        onScreenshotOCR: {
                            Task { await monitor.runScreenshotOCR() }
                        },
                        onCopyProResult: {
                            monitor.copyProResultToPasteboard()
                        },
                        onPasteProResult: {
                            monitor.pasteProResult()
                        },
                        onSaveProResult: {
                            monitor.saveProResultToHistory(derivedFrom: selectedClip)
                        }
                    )
                        .frame(height: settings.previewHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                shortcutButtons
                footer
            }
            .padding(18)
        }
        .animation(.snappy(duration: 0.18), value: settings.previewEnabled)
        .animation(.snappy(duration: 0.18), value: settings.previewHeight)
        .frame(minWidth: 320, idealWidth: settings.drawerWidth, maxWidth: 520, maxHeight: .infinity)
        .alert("Clear \(monitor.filter.displayName) clips?", isPresented: $confirmingClearFilter) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                monitor.clearCurrentFilter()
                selectedClipID = monitor.clips.first?.id
            }
        } message: {
            Text(clearFilterMessage)
        }
        .onChange(of: monitor.clips) { _, clips in
            if selectedClipID == nil || !clips.contains(where: { $0.id == selectedClipID }) {
                selectedClipID = clips.first?.id
            }
        }
        .onAppear {
            selectedClipID = selectedClipID ?? monitor.clips.first?.id
            installKeyboardMonitorIfNeeded()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    private func bannerView(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .foregroundStyle(TechTheme.cyan)
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TechTheme.text)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .techCard(selected: true, cornerRadius: 14)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CLIPBOARD")
                    .font(TechTheme.displayFont)
                    .tracking(1.2)
                    .foregroundStyle(TechTheme.text)
                Text("\(monitor.clips.count) clips · ⌘1–⌘9 paste")
                    .font(TechTheme.monoFont)
                    .foregroundStyle(TechTheme.muted)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(settings.monitoringPaused ? TechTheme.amber : TechTheme.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: settings.monitoringPaused ? TechTheme.amber : TechTheme.green, radius: 5)
                Text(settings.monitoringPaused ? "PAUSED" : "LIVE")
                    .font(TechTheme.monoFont)
                    .foregroundStyle(settings.monitoringPaused ? TechTheme.amber : TechTheme.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .techCard(cornerRadius: 999)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TechTheme.cyan)
            TextField("Search clips", text: $monitor.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TechTheme.text)
            if !monitor.searchText.isEmpty {
                Button {
                    monitor.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TechTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .techCard(cornerRadius: 14)
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(ClipFilter.allCases) { filter in
                Button {
                    monitor.filter = filter
                } label: {
                    Text(filter.displayName.uppercased())
                        .font(TechTheme.labelFont)
                        .tracking(0.5)
                        .foregroundStyle(monitor.filter == filter ? TechTheme.onAccent : TechTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(monitor.filter == filter ? TechTheme.cyan : Color.clear)
                                .shadow(color: monitor.filter == filter ? TechTheme.cyan.opacity(0.32) : .clear, radius: 10)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .techCard(cornerRadius: 14)
    }

    private var clipList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(monitor.clips.enumerated()), id: \.element.id) { index, clip in
                        ClipRow(
                            clip: clip,
                            index: index + 1,
                            isSelected: selectedClipID == clip.id
                        )
                        .id(clip.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedClipID = clip.id
                        }
                        .onTapGesture(count: 2) {
                            onPaste(clip)
                        }
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 170, idealHeight: 250)
            .techCard(cornerRadius: 18)
            .onChange(of: selectedClipID) { _, id in
                guard let id else { return }
                withAnimation(.snappy(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            shortcutPill("↑↓", "select")
            shortcutPill("↩", "paste")
            shortcutPill("⌘1–9", "direct")
            Spacer()
            Button {
                confirmingClearFilter = true
            } label: {
                Label("Clear \(monitor.filter.displayName)", systemImage: "trash")
                    .labelStyle(.titleAndIcon)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(TechTheme.amber)
            .buttonStyle(.plain)
            .disabled(monitor.clips.isEmpty)
            .opacity(monitor.clips.isEmpty ? 0.45 : 1)
            Text("LOCAL")
                .font(TechTheme.monoFont)
                .foregroundStyle(TechTheme.green.opacity(0.9))
        }
    }

    private var clearFilterMessage: String {
        if monitor.filter == .all {
            return "This deletes every saved clipboard item and stored payload."
        }
        return "This deletes all saved \(monitor.filter.displayName.lowercased()) clips in the current category."
    }

    private func shortcutPill(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(TechTheme.text)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(TechTheme.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .techCard(cornerRadius: 999)
    }

    private var selectedClip: ClipItem? {
        monitor.clips.first { $0.id == selectedClipID }
    }

    private var selectedIndex: Int? {
        guard let selectedClipID else { return nil }
        return monitor.clips.firstIndex { $0.id == selectedClipID }
    }

    private var shortcutButtons: some View {
        HStack(spacing: 0) {
            Button("Previous") { moveSelection(delta: -1) }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("Next") { moveSelection(delta: 1) }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("Previous with Command") { moveSelection(delta: -1) }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button("Next with Command") { moveSelection(delta: 1) }
                .keyboardShortcut(.downArrow, modifiers: .command)

            if let selectedClip {
                Button("Paste Selected") { onPaste(selectedClip) }
                    .keyboardShortcut(.return, modifiers: [])
            }

            ForEach(Array(monitor.clips.prefix(9).enumerated()), id: \.element.id) { index, clip in
                Button("Paste \(index + 1)") { onPaste(clip) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func moveSelection(delta: Int) {
        guard !monitor.clips.isEmpty else {
            selectedClipID = nil
            return
        }

        let currentIndex = selectedIndex ?? (delta > 0 ? -1 : monitor.clips.count)
        let nextIndex = min(max(currentIndex + delta, 0), monitor.clips.count - 1)
        selectedClipID = monitor.clips[nextIndex].id
    }

    private func installKeyboardMonitorIfNeeded() {
        guard keyboardMonitor == nil else { return }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window is DrawerPanel else { return event }

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                switch event.keyCode {
                case 126:
                    moveSelection(delta: -1)
                    return nil
                case 125:
                    moveSelection(delta: 1)
                    return nil
                case 36, 76:
                    if let selectedClip {
                        onPaste(selectedClip)
                        return nil
                    }
                default:
                    break
                }
            }

            if event.modifierFlags.contains(.command),
               let character = event.charactersIgnoringModifiers?.first,
               let index = Int(String(character)),
               index >= 1,
               index <= min(9, monitor.clips.count) {
                onPaste(monitor.clips[index - 1])
                return nil
            }

            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }
}

private struct ClipRow: View {
    let clip: ClipItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(index <= 9 ? "\(index)" : "·")
                .font(TechTheme.monoFont)
                .foregroundStyle(isSelected ? TechTheme.cyan : TechTheme.muted)
                .frame(width: 18)

            preview
                .frame(width: 46, height: 46)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TechTheme.elevated)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(clip.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(TechTheme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    typeTag
                    if let sourceApp = clip.sourceApp {
                        Text(sourceApp)
                    }
                    Text(clip.createdAt, style: .time)
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(TechTheme.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? TechTheme.cyan : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 12)
        }
        .techCard(selected: isSelected, cornerRadius: 14)
    }

    @ViewBuilder
    private var preview: some View {
        if clip.type == .media, let path = clip.payloadPath, let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else if clip.isImageDocument, let url = clip.documentURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? TechTheme.cyan : TechTheme.muted)
        }
    }

    private var typeTag: some View {
        Text(clip.kindDisplayName.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(clip.type == .media ? TechTheme.green : TechTheme.cyan)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TechTheme.elevated.opacity(0.8), in: Capsule())
    }

    private var systemImage: String {
        switch clip.type {
        case .text: "text.alignleft"
        case .rtf, .html: "text.viewfinder"
        case .media:
            if clip.isVideoDocument {
                "play.rectangle"
            } else {
                "photo"
            }
        case .document:
            "doc.text"
        }
    }
}
