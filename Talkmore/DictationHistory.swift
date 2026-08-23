import Foundation
import Observation

struct DictationHistoryItem: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let text: String
    let applicationName: String
    let writingStyle: String
    let insertionRoute: String
    let visibleLatency: TimeInterval
}

@MainActor
@Observable
final class DictationHistory {
    private(set) var items: [DictationHistoryItem]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "dictationHistory.items"
    @ObservationIgnored private let maximumCount = 50

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([DictationHistoryItem].self, from: data) {
            items = decoded
        } else {
            items = []
        }
    }

    func record(
        text: String,
        applicationName: String?,
        writingStyle: WritingStyle,
        route: TextInsertionRoute,
        visibleLatency: TimeInterval
    ) {
        let item = DictationHistoryItem(
            id: UUID(),
            createdAt: Date(),
            text: text,
            applicationName: applicationName ?? "Unknown app",
            writingStyle: writingStyle.title,
            insertionRoute: route.rawValue,
            visibleLatency: visibleLatency
        )
        items.insert(item, at: 0)
        if items.count > maximumCount {
            items.removeLast(items.count - maximumCount)
        }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}
