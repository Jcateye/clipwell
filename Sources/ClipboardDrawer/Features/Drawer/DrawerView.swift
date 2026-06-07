import SwiftUI

struct DrawerView: View {
    @ObservedObject var monitor: ClipboardMonitorService
    @ObservedObject var settings: SettingsStore
    @ObservedObject var selectionResetSignal: DrawerSelectionResetSignal
    var onPaste: (ClipItem) -> Void
    var onOpenSettings: () -> Void
    @State private var selectedClipID: ClipItem.ID?
    @State private var keyboardMonitor: Any?
    @State private var confirmingClearFilter = false
    @State private var bannerDetailMessage: String?

    var body: some View {
        ZStack {
            TechBackground(theme: settings.visualTheme)

            VStack(spacing: 12) {
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
                        proResultTitle: scopedProResultTitle,
                        proResultText: scopedProResultText,
                        proBusyState: monitor.proBusyState,
                        useConfiguredAITranslation: settings.proAIEnabled && settings.hasConfiguredAITranslation,
                        translationSourceLanguage: settings.proTranslationSourceLanguage,
                        translationTargetLanguage: settings.proTranslationTarget,
                        onPaste: onPaste,
                        onImageOCR: { clip in
                            Task { await monitor.runImageOCR(for: clip) }
                        },
                        onAITranslate: { clip in
                            Task { await monitor.runAITranslate(for: clip) }
                        },
                        onSystemTranslateResult: { clip, text in
                            monitor.publishSystemTranslation(text, for: clip)
                        },
                        onSystemTranslateFailure: { message in
                            monitor.reportSystemTranslationFailure(message)
                        },
                        onCopyProResult: {
                            monitor.copyProResultToPasteboard(derivedFrom: selectedClip)
                        },
                        onSaveTextClip: { clip, text in
                            monitor.updateTextClip(clip, text: text)
                        }
                    )
                        .frame(height: settings.previewHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                shortcutButtons
                footer
            }
            .padding(16)
        }
        .animation(.snappy(duration: 0.18), value: settings.previewEnabled)
        .animation(.snappy(duration: 0.18), value: settings.previewHeight)
        .frame(minWidth: 360, idealWidth: settings.drawerWidth, maxWidth: 600, maxHeight: .infinity)
        .background(TechTheme.palette(for: settings.visualTheme).background)
        .preferredColorScheme(settings.visualTheme.preferredColorScheme)
        .id(settings.visualTheme)
        .alert("Clear \(monitor.filter.displayName) clips?", isPresented: $confirmingClearFilter) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                monitor.clearCurrentFilter()
                selectedClipID = monitor.clips.first?.id
            }
        } message: {
            Text(clearFilterMessage)
        }
        .alert("Message Detail", isPresented: Binding(
            get: { bannerDetailMessage != nil },
            set: { if !$0 { bannerDetailMessage = nil } }
        )) {
            Button("Copy") {
                if let bannerDetailMessage {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bannerDetailMessage, forType: .string)
                }
                bannerDetailMessage = nil
            }
            Button("OK", role: .cancel) {
                bannerDetailMessage = nil
            }
        } message: {
            Text(bannerDetailMessage ?? "")
        }
        .onChange(of: monitor.clips) { _, clips in
            if selectedClipID == nil || !clips.contains(where: { $0.id == selectedClipID }) {
                selectedClipID = clips.first?.id
            }
        }
        .onChange(of: monitor.proResultClipID) { _, id in
            guard let id, monitor.clips.contains(where: { $0.id == id }) else {
                return
            }
            selectedClipID = id
        }
        .onChange(of: selectionResetSignal.generation) { _, _ in
            resetSelectionToFirstClip()
        }
        .onAppear {
            resetSelectionToFirstClip()
            installKeyboardMonitorIfNeeded()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    private func bannerView(_ text: String) -> some View {
        Button {
            bannerDetailMessage = text
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: bannerIcon(for: text))
                    .foregroundStyle(TechTheme.green)
                    .padding(.top, 1)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TechTheme.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(TechTheme.muted)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Click to view and copy full message")
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .techCard(selected: true, cornerRadius: 7)
    }

    private func bannerIcon(for text: String) -> String {
        text.localizedCaseInsensitiveContains("translate") ? "character.bubble" : "checkmark.circle"
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CLIPWELL")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(TechTheme.text)
                
                HStack(spacing: 6) {
                    Text("\(monitor.clips.count) clips")
                    Text("•")
                    Text("Local only")
                    Text("•")
                    Text("Private by design")
                    Image(systemName: "checkmark.shield")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TechTheme.muted)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(settings.monitoringPaused ? TechTheme.amber : TechTheme.green)
                    .frame(width: 8, height: 8)
                Text(settings.monitoringPaused ? "PAUSED" : "LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(settings.monitoringPaused ? TechTheme.amber : TechTheme.green)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().stroke(settings.monitoringPaused ? TechTheme.amber.opacity(0.3) : TechTheme.green.opacity(0.3), lineWidth: 1))
            
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(TechTheme.muted)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .help("Open Settings")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TechTheme.muted)
                .font(.system(size: 16))
            TextField("Search clips", text: $monitor.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(TechTheme.text)
            
            Spacer()
            
            if !monitor.searchText.isEmpty {
                Button {
                    monitor.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TechTheme.muted)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘F")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(TechTheme.muted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TechTheme.palette(for: settings.visualTheme).background)
                .shadow(color: TechTheme.line.opacity(0.5), radius: 4, y: 2)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TechTheme.line, lineWidth: 1))
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(ClipFilter.allCases) { filter in
                Button {
                    monitor.filter = filter
                } label: {
                    HStack(spacing: 6) {
                        if filter == .media && monitor.filter == filter {
                            Image(systemName: "photo.artframe")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(filter.displayName.uppercased())
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(monitor.filter == filter ? TechTheme.green : TechTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        if monitor.filter == filter {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(TechTheme.green.opacity(0.15))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TechTheme.line, lineWidth: 1)
        )
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
            .frame(minHeight: 200, idealHeight: 300)
            .background(RoundedRectangle(cornerRadius: 12).stroke(TechTheme.line.opacity(0.5), lineWidth: 1))
            .onChange(of: selectedClipID) { _, id in
                guard let id else { return }
                withAnimation(.snappy(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            shortcutPill("⌘N", "New")
            shortcutPill("⌘R", "Scan")
            shortcutPill("⌥T", "Text")
            shortcutPill("⌘V", "Paste")
            shortcutPill("⌘1–9", "1-9")
            
            Spacer()
            
            Button {
                confirmingClearFilter = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Clear All")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TechTheme.green)
            .buttonStyle(.plain)
            .padding(.horizontal, 2)
            
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield")
                Text("Local")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(TechTheme.green)
        }
        .padding(.top, 4)
    }

    private var clearFilterMessage: String {
        if monitor.filter == .all {
            return "This deletes every saved clipboard item and stored payload."
        }
        return "This deletes all saved \(monitor.filter.displayName.lowercased()) clips in the current category."
    }

    private func shortcutPill(_ key: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(TechTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(TechTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 42, height: 34)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(TechTheme.line, lineWidth: 1)
        )
    }

    private var selectedClip: ClipItem? {
        monitor.clips.first { $0.id == selectedClipID }
    }

    private var scopedProResultTitle: String? {
        guard proResultMatchesSelectedClip else { return nil }
        return monitor.proResultTitle
    }

    private var scopedProResultText: String? {
        guard proResultMatchesSelectedClip else { return nil }
        return monitor.proResultText
    }

    private var proResultMatchesSelectedClip: Bool {
        guard let resultClipID = monitor.proResultClipID else {
            return selectedClipID != nil
        }
        return resultClipID == selectedClipID
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
            Button("Previous Filter") { moveFilter(delta: -1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("Next Filter") { moveFilter(delta: 1) }
                .keyboardShortcut(.rightArrow, modifiers: [])

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

    private func moveFilter(delta: Int) {
        let filters = ClipFilter.allCases
        guard let currentIndex = filters.firstIndex(of: monitor.filter) else {
            monitor.filter = .all
            resetSelectionToFirstClip()
            return
        }

        let nextIndex = (currentIndex + delta + filters.count) % filters.count
        monitor.filter = filters[nextIndex]
        resetSelectionToFirstClip()
    }

    private func resetSelectionToFirstClip() {
        selectedClipID = monitor.clips.first?.id
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
                case 123:
                    moveFilter(delta: -1)
                    return nil
                case 124:
                    moveFilter(delta: 1)
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
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(TechTheme.muted)
                    .lineLimit(1)
                    .frame(width: 18, alignment: .trailing)
                
                Circle()
                    .fill(isSelected ? TechTheme.green : Color.clear)
                    .frame(width: 5, height: 5)
            }
            
            preview
                .frame(width: 46, height: 34)
                .background(TechTheme.line.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(TechTheme.line.opacity(0.8), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(clip.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TechTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TechTheme.muted)
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
            
            Text(clip.createdAt, style: .time)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(TechTheme.muted)
                .lineLimit(1)
                .frame(width: 42, alignment: .trailing)
                
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TechTheme.muted)
                .frame(width: 18)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? TechTheme.surface : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? TechTheme.line : Color.clear, lineWidth: 1)
        )
        .shadow(color: isSelected ? TechTheme.line.opacity(0.5) : .clear, radius: 4, y: 2)
    }

    private var subtitle: String {
        [clip.kindDisplayName.capitalized, clip.sourceApp]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: " • ")
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
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(TechTheme.green)
        }
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
