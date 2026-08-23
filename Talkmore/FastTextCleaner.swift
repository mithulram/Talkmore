import Foundation

enum FastTextCleaner {
    private static let fillerPattern = try! NSRegularExpression(
        pattern: #"(?i)(^|[\s,])(um+|uh+|erm+|hmm+)(?=([\s,.!?]|$))"#
    )
    private static let whitespacePattern = try! NSRegularExpression(pattern: #"[ \t]{2,}"#)
    private static let spaceBeforePunctuationPattern = try! NSRegularExpression(pattern: #"\s+([,.!?;:])"#)

    static func clean(_ transcript: String) -> String {
        var text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        text = replacing(fillerPattern, in: text, with: "$1")
        text = replacing(whitespacePattern, in: text, with: " ")
        text = replacing(spaceBeforePunctuationPattern, in: text, with: "$1")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = text.first, first.isLetter {
            text.replaceSubrange(text.startIndex...text.startIndex, with: String(first).uppercased())
        }
        return text
    }

    private static func replacing(
        _ expression: NSRegularExpression,
        in text: String,
        with template: String
    ) -> String {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
