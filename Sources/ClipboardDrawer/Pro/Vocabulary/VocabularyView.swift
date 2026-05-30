import SwiftUI

struct VocabularyView: View {
    @ObservedObject var viewModel: VocabularyViewModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ZStack {
            TechBackground(theme: settings.visualTheme)
            VStack(spacing: 14) {
                header
                searchBar
                if let statusMessage = viewModel.statusMessage, !statusMessage.isEmpty {
                    statusView(statusMessage)
                }
                list
            }
            .padding(18)
        }
        .frame(width: 560, height: 420)
        .background(TechTheme.palette(for: settings.visualTheme).background)
        .preferredColorScheme(settings.visualTheme.preferredColorScheme)
        .id(settings.visualTheme)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VOCABULARY")
                    .font(TechTheme.displayFont)
                    .tracking(1.2)
                    .foregroundStyle(TechTheme.text)
                Text("\(viewModel.items.count) saved words")
                    .font(TechTheme.monoFont)
                    .foregroundStyle(TechTheme.muted)
            }
            Spacer()
            Button("Refresh") {
                viewModel.refresh()
            }
            .buttonStyle(TechSecondaryButtonStyle())
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TechTheme.cyan)
            TextField("Search vocabulary", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TechTheme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .techCard(cornerRadius: 7)
    }

    private func statusView(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .foregroundStyle(TechTheme.cyan)
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TechTheme.text)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .techCard(selected: true, cornerRadius: 7)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No saved words",
                        systemImage: "text.book.closed",
                        description: Text("Use Add Word from a text clip to build your local vocabulary.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                } else {
                    ForEach(viewModel.items) { item in
                        row(item)
                    }
                }
            }
            .padding(8)
        }
        .techCard(cornerRadius: 9)
    }

    private func row(_ item: VocabularyItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.sourceText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TechTheme.text)
                        .textSelection(.enabled)
                    Text(item.normalizedText)
                        .font(TechTheme.monoFont)
                        .foregroundStyle(TechTheme.muted)
                        .textSelection(.enabled)
                }
                Spacer()
                Button(role: .destructive) {
                    viewModel.delete(item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(TechTheme.amber)
            }

            HStack(spacing: 8) {
                if let sourceApp = item.sourceApp, !sourceApp.isEmpty {
                    tag(sourceApp)
                }
                tag(Self.dateFormatter.string(from: item.createdAt))
                Spacer()
            }
        }
        .padding(12)
        .background(TechTheme.background.opacity(0.28), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(TechTheme.line.opacity(0.5), lineWidth: 0.7)
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(TechTheme.monoFont)
            .foregroundStyle(TechTheme.cyan)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(TechTheme.elevated, in: Capsule())
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
