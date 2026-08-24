import Foundation

struct LearnedCorrectionCandidate: Equatable {
    let heardText: String
    let correctedText: String
}

enum CorrectionCandidateDetector {
    private static let boundaries = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: ",.!?;:\"“”‘’()[]{}<>/\\")
    )
    private static let trimming = boundaries.union(CharacterSet(charactersIn: "-–—"))

    static func candidate(
        before: String,
        after: String,
        insertedRange: NSRange
    ) -> LearnedCorrectionCandidate? {
        guard before != after,
              let change = changedRanges(before: before, after: after),
              !(change.old.length == 0 && change.old.location >= NSMaxRange(insertedRange)),
              change.old.location >= insertedRange.location,
              NSMaxRange(change.old) <= NSMaxRange(insertedRange) else { return nil }

        let oldRange = expandedTokenRange(in: before, around: change.old)
        let newRange = expandedTokenRange(in: after, around: change.new)
        guard oldRange.location >= insertedRange.location,
              NSMaxRange(oldRange) <= NSMaxRange(insertedRange) else { return nil }

        let heard = (before as NSString).substring(with: oldRange)
            .trimmingCharacters(in: trimming)
        let corrected = (after as NSString).substring(with: newRange)
            .trimmingCharacters(in: trimming)
        guard isUseful(heard), isUseful(corrected), heard != corrected else { return nil }
        return LearnedCorrectionCandidate(heardText: heard, correctedText: corrected)
    }

    private static func changedRanges(
        before: String,
        after: String
    ) -> (old: NSRange, new: NSRange)? {
        let old = before as NSString
        let new = after as NSString
        let shared = min(old.length, new.length)
        var prefix = 0
        while prefix < shared, old.character(at: prefix) == new.character(at: prefix) {
            prefix += 1
        }

        var suffix = 0
        while suffix < min(old.length - prefix, new.length - prefix),
              old.character(at: old.length - suffix - 1) == new.character(at: new.length - suffix - 1) {
            suffix += 1
        }
        return (
            NSRange(location: prefix, length: old.length - prefix - suffix),
            NSRange(location: prefix, length: new.length - prefix - suffix)
        )
    }

    private static func expandedTokenRange(in text: String, around range: NSRange) -> NSRange {
        let value = text as NSString
        var start = max(0, min(range.location, value.length))
        var end = max(start, min(NSMaxRange(range), value.length))
        while start > 0, !isBoundary(value.character(at: start - 1)) { start -= 1 }
        while end < value.length, !isBoundary(value.character(at: end)) { end += 1 }
        return NSRange(location: start, length: end - start)
    }

    private static func isBoundary(_ character: unichar) -> Bool {
        Unicode.Scalar(character).map(boundaries.contains) ?? false
    }

    private static func isUseful(_ value: String) -> Bool {
        let words = value.split(whereSeparator: \.isWhitespace)
        return !value.isEmpty
            && value.count <= 40
            && (1...3).contains(words.count)
            && value.rangeOfCharacter(from: .letters) != nil
    }
}

enum CorrectionLearningPolicy {
    static let requiredOccurrences = 2

    static func shouldLearn(occurrenceCount: Int) -> Bool {
        occurrenceCount >= requiredOccurrences
    }
}

@MainActor
final class AutomaticDictionaryLearner {
    private struct Evidence: Codable {
        var heardText: String
        var correctedText: String
        var occurrenceCount: Int
        var lastSeen: Date
    }

    private let defaults: UserDefaults
    private let key = "automaticDictionary.correctionEvidence"
    private var observationTasks: [UUID: Task<Void, Never>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func observe(
        receipt: TextInsertionReceipt,
        inserter: TextInserter,
        dictionary: PersonalDictionary
    ) {
        guard let snapshot = receipt.learningSnapshot else { return }

        let observationID = UUID()
        observationTasks[observationID] = Task { [weak self] in
            defer { self?.observationTasks[observationID] = nil }
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled,
                      let self,
                      let current = inserter.currentDocumentText(for: receipt) else { return }
                guard current != snapshot.documentText else { continue }
                guard let candidate = CorrectionCandidateDetector.candidate(
                    before: snapshot.documentText,
                    after: current,
                    insertedRange: snapshot.insertedRange
                ) else { return }
                self.record(candidate, dictionary: dictionary)
                return
            }
        }
    }

    private func record(
        _ candidate: LearnedCorrectionCandidate,
        dictionary: PersonalDictionary
    ) {
        guard !dictionary.entries.contains(where: {
            $0.spokenForm.localizedCaseInsensitiveCompare(candidate.heardText) == .orderedSame
        }) else { return }

        var evidence = loadEvidence().filter {
            Date().timeIntervalSince($0.lastSeen) < 30 * 24 * 60 * 60
        }
        if let index = evidence.firstIndex(where: {
            $0.heardText.localizedCaseInsensitiveCompare(candidate.heardText) == .orderedSame
                && $0.correctedText == candidate.correctedText
        }) {
            evidence[index].occurrenceCount += 1
            evidence[index].lastSeen = Date()
            if CorrectionLearningPolicy.shouldLearn(
                occurrenceCount: evidence[index].occurrenceCount
            ) {
                _ = dictionary.add(
                    spokenForm: candidate.heardText,
                    replacement: candidate.correctedText
                )
                evidence.remove(at: index)
            }
        } else {
            evidence.append(Evidence(
                heardText: candidate.heardText,
                correctedText: candidate.correctedText,
                occurrenceCount: 1,
                lastSeen: Date()
            ))
        }
        saveEvidence(Array(evidence.suffix(100)))
    }

    private func loadEvidence() -> [Evidence] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Evidence].self, from: data)) ?? []
    }

    private func saveEvidence(_ evidence: [Evidence]) {
        guard let data = try? JSONEncoder().encode(evidence) else { return }
        defaults.set(data, forKey: key)
    }
}
