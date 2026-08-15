import Combine
import Foundation

struct ShelfAddResult: Equatable {
    let addedCount: Int
    let duplicateCount: Int
    let invalidCount: Int
    let capacityRejectedCount: Int
}

final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    let maxItems: Int

    init(maxItems: Int = 12) {
        self.maxItems = max(1, maxItems)
    }

    @discardableResult
    func add(_ urls: [URL]) -> ShelfAddResult {
        var seen = Set(items.map { $0.url.standardizedFileURL })
        var candidates: [URL] = []
        var duplicateCount = 0
        var invalidCount = 0

        for rawURL in urls {
            let url = rawURL.standardizedFileURL
            guard url.isFileURL,
                  FileManager.default.fileExists(atPath: url.path) else {
                invalidCount += 1
                continue
            }
            guard seen.insert(url).inserted else {
                duplicateCount += 1
                continue
            }
            candidates.append(url)
        }

        let availableSlots = max(0, maxItems - items.count)
        let accepted = candidates.prefix(availableSlots)
        items.append(contentsOf: accepted.map(ShelfItem.make))

        return ShelfAddResult(
            addedCount: accepted.count,
            duplicateCount: duplicateCount,
            invalidCount: invalidCount,
            capacityRejectedCount: max(0, candidates.count - availableSlots)
        )
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    @discardableResult
    func removeMissingFiles() -> Int {
        let previousCount = items.count
        items.removeAll { !$0.isAvailable }
        return previousCount - items.count
    }
}
