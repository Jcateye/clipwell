import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var aiConnectionValidator: AIConnectionValidator
    let conflictService: ShortcutConflictService
    let saveShortcut: @MainActor (AppAction, AppShortcut) -> Bool
    let openVocabulary: () -> Void

    @State private var selectedTab: SettingsTab = .general
    @State private var recordingAction: AppAction?
    @State private var pendingShortcut: AppShortcut
    @State private var conflictMessage: String?
    @State private var warningMessage: String?
    @State private var registrationMessage: String?
    @State private var launchAtLoginMessage: String?
    @State private var pendingActionForWarning: AppAction?

    init(settings: SettingsStore, conflictService: ShortcutConflictService, saveShortcut: @MainActor @escaping (AppAction, AppShortcut) -> Bool, aiConnectionValidator: AIConnectionValidator, openVocabulary: @escaping () -> Void) {
        self.settings = settings
        self.conflictService = conflictService
        self.saveShortcut = saveShortcut
        self.aiConnectionValidator = aiConnectionValidator
        self.openVocabulary = openVocabulary
        _pendingShortcut = State(initialValue: settings.toggleDrawerShortcut)
    }

    var body: some View {
        ZStack {
            TechBackground()
            VStack(spacing: 18) {
                header
                tabSwitcher
                ScrollView {
                    content
                }
                .scrollIndicators(.automatic)
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(width: 620, height: 460)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("CONTROL SURFACE")
                    .font(TechTheme.displayFont)
                    .tracking(1.4)
                    .foregroundStyle(TechTheme.text)
                Text("Local clipboard manager · V0.1")
                    .font(TechTheme.monoFont)
                    .foregroundStyle(TechTheme.muted)
            }
            Spacer()
            Text(settings.toggleDrawerShortcut.displayString)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(TechTheme.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .techCard(cornerRadius: 999)
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.symbol)
                        Text(tab.title.uppercased())
                    }
                    .font(TechTheme.labelFont)
                    .foregroundStyle(selectedTab == tab ? TechTheme.onAccent : TechTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTab == tab ? TechTheme.cyan : Color.clear)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .techCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .drawer:
            drawerTab
        case .clipboard:
            clipboardTab
        }
    }

    private var generalTab: some View {
        VStack(spacing: 14) {
            settingsRow(
                title: "Launch at login",
                subtitle: "Start the local clipboard engine after macOS login.",
                trailing: AnyView(
                    Toggle("", isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { enabled in
                            switch LaunchAtLoginService.apply(enabled: enabled) {
                            case .success(let message):
                                settings.launchAtLoginEnabled = enabled
                                launchAtLoginMessage = message
                            case .failure(let error):
                                settings.launchAtLoginEnabled = false
                                launchAtLoginMessage = "Could not update launch at login: \(error.localizedDescription)"
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                )
            )

            if let launchAtLoginMessage {
                statusText(launchAtLoginMessage, color: LaunchAtLoginService.isSupportedInCurrentBundle ? TechTheme.muted : TechTheme.amber)
            }

            settingsRow(
                title: "Theme",
                subtitle: settings.visualTheme.subtitle,
                trailing: AnyView(
                    Picker("", selection: $settings.visualTheme) {
                        ForEach(AppVisualTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                )
            )
        }
        .padding(16)
        .techCard(cornerRadius: 20)
    }

    private var drawerTab: some View {
        VStack(spacing: 16) {
            settingsRow(
                title: "Drawer edge",
                subtitle: "Pick the side where the memory drawer enters.",
                trailing: AnyView(
                    Picker("", selection: $settings.drawerEdge) {
                        ForEach(DrawerEdge.allCases) { edge in
                            Text(edge.displayName).tag(edge)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                )
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    labelBlock("Width", "Current drawer width")
                    Spacer()
                    statusBadge("\(Int(settings.drawerWidth)) PX")
                }
                Slider(value: $settings.drawerWidth, in: 320...520, step: 20)
                    .tint(TechTheme.cyan)
            }

            settingsRow(
                title: "Animation",
                subtitle: "Tune the slide-in speed.",
                trailing: AnyView(
                    Picker("", selection: $settings.drawerAnimationSpeed) {
                        ForEach(DrawerAnimationSpeed.allCases) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                )
            )

            previewSection

            shortcutSection
        }
        .padding(16)
        .techCard(cornerRadius: 20)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            settingsRow(
                title: "Preview pane",
                subtitle: "Turn off to show more history rows.",
                trailing: AnyView(
                    Toggle("", isOn: $settings.previewEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                )
            )

            if settings.previewEnabled {
                HStack {
                    labelBlock("Preview height", "Controls vertical space used by preview")
                    Spacer()
                    statusBadge("\(Int(settings.previewHeight)) PX")
                }
                Slider(value: $settings.previewHeight, in: 140...360, step: 20)
                    .tint(TechTheme.cyan)
            }
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            shortcutRow(
                action: .toggleDrawer,
                title: "Toggle shortcut",
                subtitle: "Global trigger for the drawer",
                current: settings.toggleDrawerShortcut
            )

            shortcutRow(
                action: .screenshotOCR,
                title: "Screenshot OCR shortcut",
                subtitle: "Global trigger for interactive screenshot text capture",
                current: settings.screenshotOCRShortcut
            )

            if let action = recordingAction {
                ShortcutRecorderView(shortcut: $pendingShortcut) {
                    recordingAction = nil
                } onRecord: { shortcut in
                    let targetAction = action
                    recordingAction = nil
                    validateAndMaybeSave(shortcut, for: targetAction, allowReserved: false)
                }
                .frame(height: 44)
                .overlay {
                    Text("PRESS KEYS · ESC CANCELS")
                        .font(TechTheme.monoFont)
                        .foregroundStyle(TechTheme.cyan)
                }
                .techCard(selected: true, cornerRadius: 14)
            }

            if let conflictMessage {
                statusText(conflictMessage, color: .red)
            }
            if let warningMessage, let action = recordingAction ?? pendingActionForWarning {
                HStack {
                    statusText(warningMessage, color: TechTheme.amber)
                    Button("Save anyway") {
                        validateAndMaybeSave(pendingShortcut, for: action, allowReserved: true)
                    }
                    .buttonStyle(TechSecondaryButtonStyle())
                }
            }
            if let registrationMessage {
                statusText(registrationMessage, color: .red)
            }
        }
    }

    private var clipboardTab: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    labelBlock("History depth", "Maximum local records before pruning")
                    Spacer()
                    statusBadge("\(settings.historyMaxCount)")
                }
                Stepper("", value: $settings.historyMaxCount, in: 50...5000, step: 50)
                    .labelsHidden()
            }

            settingsRow(title: "Deduplicate", subtitle: "Skip consecutive identical captures.", trailing: AnyView(Toggle("", isOn: $settings.dedupConsecutiveEnabled).toggleStyle(.switch).labelsHidden()))
            settingsRow(title: "Auto paste", subtitle: "After selecting a clip, send ⌘V automatically.", trailing: AnyView(Toggle("", isOn: $settings.autoPasteEnabled).toggleStyle(.switch).labelsHidden()))
            settingsRow(title: "Auto close", subtitle: "Close drawer after selection.", trailing: AnyView(Toggle("", isOn: $settings.autoCloseDrawerEnabled).toggleStyle(.switch).labelsHidden()))

            VStack(alignment: .leading, spacing: 8) {
                labelBlock("Ignored apps", "One app name or bundle identifier per line")
                TextEditor(text: $settings.ignoredAppListText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(TechTheme.text)
                    .frame(height: 92)
                    .scrollContentBackground(.hidden)
                    .background(TechTheme.background.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                labelBlock("Ignored file suffixes", "Comma, space, or line separated; examples: mov, zip, psd")
                TextEditor(text: $settings.ignoredFileExtensionsText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(TechTheme.text)
                    .frame(height: 58)
                    .scrollContentBackground(.hidden)
                    .background(TechTheme.background.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                    }
            }

            Divider()
                .overlay(TechTheme.line)

            settingsRow(
                title: "Pro OCR",
                subtitle: "Enable local image OCR and screenshot OCR actions.",
                trailing: AnyView(
                    Toggle("", isOn: $settings.proEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                )
            )

            settingsRow(
                title: "Vocabulary",
                subtitle: "Enable local add-to-vocabulary action for text clips.",
                trailing: AnyView(
                    HStack(spacing: 10) {
                        Button("Open") {
                            openVocabulary()
                        }
                        .buttonStyle(TechSecondaryButtonStyle())

                        Toggle("", isOn: $settings.proVocabularyEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                )
            )

            settingsRow(
                title: "Pro AI",
                subtitle: "Enable AI translate, rewrite, and summarize actions for text clips.",
                trailing: AnyView(
                    Toggle("", isOn: $settings.proAIEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                )
            )

            VStack(alignment: .leading, spacing: 8) {
                labelBlock("Translation target", "Language name for the Translate action, for example: English, Chinese, Japanese")
                TextField("English", text: $settings.proTranslationTargetLanguage)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(TechTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(TechTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                labelBlock("AI base URL", "OpenAI-compatible endpoint; recommended local LiteLLM URL")
                TextField("http://127.0.0.1:4000/v1", text: $settings.proAIBaseURL)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(TechTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(TechTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                labelBlock("AI model", "LiteLLM short name or any OpenAI-compatible model id")
                TextField("gpt-5.4-mini", text: $settings.proAIModel)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(TechTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(TechTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                labelBlock("AI API key", "LiteLLM virtual key or local master key; leave empty only if your endpoint allows it")
                SecureField("sk-...", text: $settings.proAIAPIKey)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(TechTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(TechTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                    }
            }

            HStack(spacing: 10) {
                Button(aiConnectionValidator.isTesting ? "Testing…" : "Test AI Connection") {
                    aiConnectionValidator.testConnection()
                }
                .buttonStyle(TechSecondaryButtonStyle())
                .disabled(aiConnectionValidator.isTesting)

                if let statusMessage = aiConnectionValidator.statusMessage {
                    statusText(statusMessage, color: statusMessage.contains("OK") ? TechTheme.green : TechTheme.amber)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                labelBlock("OCR languages", "Comma separated Vision language codes; example: zh-Hans, en-US")
                TextEditor(text: $settings.proOCRLanguagesText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(TechTheme.text)
                    .frame(height: 58)
                    .scrollContentBackground(.hidden)
                    .background(TechTheme.background.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TechTheme.line.opacity(0.8), lineWidth: 0.8)
                    }
            }
        }
        .padding(16)
        .techCard(cornerRadius: 20)
    }

    private func settingsRow(title: String, subtitle: String, trailing: AnyView) -> some View {
        HStack(spacing: 16) {
            labelBlock(title, subtitle)
            Spacer()
            trailing
        }
        .padding(12)
        .background(TechTheme.background.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(TechTheme.line.opacity(0.5), lineWidth: 0.7)
        }
    }

    private func labelBlock(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(TechTheme.labelFont)
                .tracking(0.7)
                .foregroundStyle(TechTheme.text)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(TechTheme.muted)
        }
    }

    private func statusBadge(_ text: String) -> some View {
        Text(text)
            .font(TechTheme.monoFont)
            .foregroundStyle(TechTheme.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TechTheme.elevated, in: Capsule())
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortcutRow(action: AppAction, title: String, subtitle: String, current: AppShortcut) -> some View {
        HStack {
            labelBlock(title, subtitle)
            Spacer()
            Text(current.displayString)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(TechTheme.cyan)
            Button(recordingAction == action ? "Listening…" : "Set Shortcut") {
                recordingAction = action
                pendingActionForWarning = nil
                pendingShortcut = current
                conflictMessage = nil
                warningMessage = nil
                registrationMessage = nil
            }
            .buttonStyle(TechSecondaryButtonStyle())
        }
    }

    private func validateAndMaybeSave(_ shortcut: AppShortcut, for action: AppAction, allowReserved: Bool) {
        let result = conflictService.validate(shortcut: shortcut, for: action, existing: settings.shortcutsByAction())
        if result.isHardConflict {
            pendingActionForWarning = nil
            conflictMessage = result.message
            warningMessage = nil
            return
        }

        if let warning = result.warning, !allowReserved {
            pendingShortcut = shortcut
            pendingActionForWarning = action
            warningMessage = warning
            conflictMessage = nil
            return
        }

        if saveShortcut(action, shortcut) {
            switch action {
            case .toggleDrawer:
                settings.toggleDrawerShortcut = shortcut
            case .screenshotOCR:
                settings.screenshotOCRShortcut = shortcut
            }
            pendingActionForWarning = nil
            settings.objectWillChange.send()
            conflictMessage = nil
            warningMessage = nil
            registrationMessage = nil
        } else {
            pendingActionForWarning = nil
            warningMessage = nil
            let kept = settings.shortcutsByAction()[action]?.displayString ?? shortcut.displayString
            registrationMessage = "Registration failed; kept \(kept)."
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case drawer
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .drawer: "Drawer"
        case .clipboard: "Clipboard"
        }
    }

    var symbol: String {
        switch self {
        case .general: "power"
        case .drawer: "sidebar.leading"
        case .clipboard: "doc.on.clipboard"
        }
    }
}

struct TechSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TechTheme.labelFont)
            .foregroundStyle(TechTheme.cyan)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(TechTheme.elevated.opacity(configuration.isPressed ? 0.7 : 0.95), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(TechTheme.lineBright, lineWidth: 0.8)
            }
    }
}
