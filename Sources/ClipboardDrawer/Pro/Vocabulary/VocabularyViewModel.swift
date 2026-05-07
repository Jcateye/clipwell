import Combine
import Foundation

@MainActor
final class VocabularyViewModel: ObservableObject {
    @Published var searchText: String = "" {
        didSet { refresh() }
    }
    @Published private(set) var items: [VocabularyItem] = []
    @Published var statusMessage: String?

    private let store: VocabularyStore

    init(store: VocabularyStore) {
        self.store = store
        refresh()
    }

    func refresh() {
        let all = store.allItems()
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else {
            items = all
            return
        }
        items = all.filter {
            $0.normalizedText.contains(keyword) ||
            $0.sourceText.lowercased().contains(keyword) ||
            ($0.sourceApp?.lowercased().contains(keyword) ?? false)
        }
    }

    func delete(_ item: VocabularyItem) {
        do {
            try store.remove(id: item.id)
            refresh()
            statusMessage = "Deleted from vocabulary."
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
        }
    }
}
