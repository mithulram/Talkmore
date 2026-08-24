import Foundation

enum ConversationalStructureFormatter {
    private static let markerExpression = try! NSRegularExpression(
        pattern: #"(?i)\b(first|second|third|fourth|fifth)(?:\s+one)?\s*(?:(?:is|would\s+be)\s+|:\s*|[-–—]\s*)?"#
    )
    private static let enumerationIntentExpression = try! NSRegularExpression(
        pattern: #"(?i)\b(ideas?|points?|things?|options?|reasons?|steps?|items?|examples?)\b"#
    )
    private static let leadingConnectorExpression = try! NSRegularExpression(
        pattern: #"(?i)^\s*(?:and|then|also)\s+"#
    )
    private static let trailingConnectorExpression = try! NSRegularExpression(
        pattern: #"(?i)[,;:.]?\s+(?:and|then|also)\s*$"#
    )

    static func format(_ input: String) -> String {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = markerExpression.matches(in: text, range: fullRange)
        guard matches.count >= 2,
              hasSequentialMarkers(matches, in: text) else { return text }

        let firstLocation = matches[0].range.location
        let introRange = NSRange(location: 0, length: firstLocation)
        let intro = cleanedIntro((text as NSString).substring(with: introRange))
        let hasEnumerationIntent = enumerationIntentExpression.firstMatch(
            in: intro,
            range: NSRange(intro.startIndex..<intro.endIndex, in: intro)
        ) != nil
        guard intro.isEmpty || hasEnumerationIntent else { return text }

        var items: [String] = []
        let nsText = text as NSString
        for (index, match) in matches.enumerated() {
            let start = NSMaxRange(match.range)
            let end = index + 1 < matches.count ? matches[index + 1].range.location : nsText.length
            guard end >= start else { return text }
            var item = nsText.substring(with: NSRange(location: start, length: end - start))
            item = replacing(leadingConnectorExpression, in: item, with: "")
            item = replacing(trailingConnectorExpression, in: item, with: "")
            item = item.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(
                CharacterSet(charactersIn: ",;:–—-")
            ))
            guard !item.isEmpty else { return text }
            items.append(capitalizingFirstLetter(item))
        }

        let list = items.enumerated().map { index, item in
            "\(index + 1). \(item)"
        }.joined(separator: "\n")
        return intro.isEmpty ? list : "\(capitalizingFirstLetter(intro)):\n\(list)"
    }

    private static func hasSequentialMarkers(
        _ matches: [NSTextCheckingResult],
        in text: String
    ) -> Bool {
        let expected = ["first", "second", "third", "fourth", "fifth"]
        let nsText = text as NSString
        for (index, match) in matches.enumerated() {
            guard index < expected.count, match.numberOfRanges > 1 else { return false }
            let value = nsText.substring(with: match.range(at: 1)).lowercased()
            guard value == expected[index] else { return false }
        }
        return true
    }

    private static func cleanedIntro(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: ",;:.")
        ))
    }

    private static func capitalizingFirstLetter(_ value: String) -> String {
        var result = value
        guard let index = result.firstIndex(where: \.isLetter) else { return result }
        result.replaceSubrange(index...index, with: String(result[index]).uppercased())
        return result
    }

    private static func replacing(
        _ expression: NSRegularExpression,
        in text: String,
        with template: String
    ) -> String {
        expression.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text),
            withTemplate: template
        )
    }
}
