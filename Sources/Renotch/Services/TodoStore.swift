import Combine
import Foundation

final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "virtualNotch.todos.v1"
    private let maxItems = 100

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let storedItems = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = storedItems
        } else {
            items = []
        }
    }

    var remainingCount: Int {
        items.lazy.filter { !$0.isCompleted }.count
    }

    var hasCompletedItems: Bool {
        items.contains(where: \TodoItem.isCompleted)
    }

    @discardableResult
    func add(_ rawTitle: String) -> Bool {
        let title = rawTitle
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }

        items.insert(TodoItem(title: title), at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        return true
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()
    }

    func remove(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearCompleted() {
        items.removeAll { $0.isCompleted }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}
