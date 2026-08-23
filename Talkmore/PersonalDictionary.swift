import Foundation
import Observation

struct PersonalDictionaryEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var spokenForm: String
    var replacement: String

    init(id: UUID = UUID(), spokenForm: String, replacement: String) {
        self.id = id
        self.spokenForm = spokenForm
        self.replacement = replacement
    }
}

@MainActor
@Observable
final class PersonalDictionary {
    private(set) var entries: [PersonalDictionaryEntry]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "personalDictionary.entries"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PersonalDictionaryEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    var speechHints: [String] {
        entries.flatMap { [$0.spokenForm, $0.replacement] }
    }

    @discardableResult
    func add(spokenForm: String, replacement: String) -> Bool {
        let spoken = spokenForm.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !written.isEmpty else { return false }

        if let index = entries.firstIndex(where: {
            $0.spokenForm.localizedCaseInsensitiveCompare(spoken) == .orderedSame
        }) {
            entries[index].replacement = written
        } else {
            entries.append(PersonalDictionaryEntry(spokenForm: spoken, replacement: written))
        }
        entries.sort { $0.spokenForm.localizedCaseInsensitiveCompare($1.spokenForm) == .orderedAscending }
        persist()
        return true
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func apply(to input: String) -> String {
        entries
            .sorted { $0.spokenForm.count > $1.spokenForm.count }
            .reduce(input) { text, entry in
                let escaped = NSRegularExpression.escapedPattern(for: entry.spokenForm)
                let pattern = "(?i)(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])"
                guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                return expression.stringByReplacingMatches(
                    in: text,
                    range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: entry.replacement)
                )
            }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
