import Foundation

struct WritingContext: Equatable {
    let isDeveloperMode: Bool
    let applicationName: String?

    init(applicationName: String?, bundleIdentifier: String?, developerModeEnabled: Bool) {
        self.applicationName = applicationName
        isDeveloperMode = developerModeEnabled && Self.isCodingApp(
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier
        )
    }

    init(target: TextTarget, developerModeEnabled: Bool) {
        self.init(
            applicationName: target.applicationName,
            bundleIdentifier: target.bundleIdentifier,
            developerModeEnabled: developerModeEnabled
        )
    }

    static let standard = WritingContext(
        applicationName: nil,
        bundleIdentifier: nil,
        developerModeEnabled: false
    )

    var speechHints: [String] {
        guard isDeveloperMode else { return [] }
        return [
            "Swift", "SwiftUI", "UIKit", "AppKit", "Xcode", "GitHub", "GitLab",
            "JavaScript", "TypeScript", "Node.js", "Next.js", "React", "Python",
            "OpenAI", "ChatGPT", "Codex", "README.md", "package.json", "tsconfig.json",
            "camel case", "snake case", "Pascal case", "new line", "new paragraph",
            "open parenthesis", "close parenthesis", "open bracket", "close bracket",
            "open brace", "close brace", "underscore", "semicolon", "arrow"
        ]
    }

    var refinementInstructions: String {
        guard isDeveloperMode else { return "This is normal prose dictation." }
        let app = applicationName.map { " in \($0)" } ?? ""
        return """
        This dictation is being inserted into a developer app\(app). Preserve code identifiers,
        API names, filenames, URLs, symbols, line breaks, casing, and indentation exactly. Keep a
        spoken request as prose unless the speaker explicitly dictates code or formatting.
        """
    }

    func process(_ text: String) -> String {
        guard isDeveloperMode else { return text }
        return DeveloperTextProcessor.process(text)
    }

    private static func isCodingApp(applicationName: String?, bundleIdentifier: String?) -> Bool {
        let bundle = bundleIdentifier?.lowercased() ?? ""
        let knownBundles = [
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.microsoft.vscode",
            "com.microsoft.vscodeinsiders",
            "com.apple.dt.xcode",
            "com.apple.terminal",
            "com.googlecode.iterm2",
            "dev.warp.warp-stable",
            "dev.warp.warp",
            "dev.zed.zed",
            "com.mitchellh.ghostty",
            "com.openai.codex",
            "com.t3tools.t3code"
        ]
        if knownBundles.contains(bundle) { return true }

        let name = applicationName?.lowercased() ?? ""
        return [
            "cursor", "visual studio code", "xcode", "terminal", "iterm", "iterm2",
            "warp", "zed", "ghostty", "codex", "t3 code"
        ].contains(name)
    }
}

enum DeveloperTextProcessor {
    private enum LetterCase: String {
        case camel
        case snake
        case pascal
    }

    static func process(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }

        text = applyCaseCommands(to: text)
        text = normalizeTechnologyNames(in: text)
        text = normalizeFilenames(in: text)
        text = applyFormattingCommands(to: text)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func applyCaseCommands(to input: String) -> String {
        let wholePattern = #"(?i)^(camel|snake|pascal)\s+case\s+(.+)$"#
        if let match = firstMatch(wholePattern, in: input),
           let style = capture(1, match: match, in: input).flatMap({ LetterCase(rawValue: $0.lowercased()) }),
           let phrase = capture(2, match: match, in: input) {
            return convert(phrase, to: style)
        }

        let delimitedPattern = #"(?i)\b(camel|snake|pascal)\s+case\s+(.+?)\s+end\s+case\b"#
        return replacingMatches(delimitedPattern, in: input) { match in
            guard
                let styleName = capture(1, match: match, in: input),
                let style = LetterCase(rawValue: styleName.lowercased()),
                let phrase = capture(2, match: match, in: input)
            else { return capture(0, match: match, in: input) ?? "" }
            return convert(phrase, to: style)
        }
    }

    private static func convert(_ phrase: String, to style: LetterCase) -> String {
        let words = phrase
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
        guard let first = words.first else { return phrase }

        switch style {
        case .camel:
            return first + words.dropFirst().map(capitalize).joined()
        case .snake:
            return words.joined(separator: "_")
        case .pascal:
            return words.map(capitalize).joined()
        }
    }

    private static func capitalize(_ word: String) -> String {
        guard let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

    private static func normalizeTechnologyNames(in input: String) -> String {
        let replacements: [(String, String)] = [
            (#"(?i)\bswift\s*u\s*i\b"#, "SwiftUI"),
            (#"(?i)\bu\s*i\s*kit\b"#, "UIKit"),
            (#"(?i)\bapp\s*kit\b"#, "AppKit"),
            (#"(?i)\bx\s*code\b"#, "Xcode"),
            (#"(?i)\bgit\s*hub\b"#, "GitHub"),
            (#"(?i)\bgit\s*lab\b"#, "GitLab"),
            (#"(?i)\bjava\s*script\b"#, "JavaScript"),
            (#"(?i)\btype\s*script\b"#, "TypeScript"),
            (#"(?i)\bnode(?:\s+dot)?\s+j\s*s\b"#, "Node.js"),
            (#"(?i)\bnext(?:\s+dot)?\s+j\s*s\b"#, "Next.js"),
            (#"(?i)\bopen\s*a\s*i\b"#, "OpenAI"),
            (#"(?i)\bchat\s*g\s*p\s*t\b"#, "ChatGPT")
        ]
        return replacements.reduce(input) { text, replacement in
            replace(replacement.0, in: text, with: replacement.1)
        }
    }

    private static func normalizeFilenames(in input: String) -> String {
        var text = input
        let knownFiles: [(String, String)] = [
            (#"(?i)\bread\s*me\s+dot\s+md\b"#, "README.md"),
            (#"(?i)\bpackage\s+dot\s+json\b"#, "package.json"),
            (#"(?i)\btsconfig\s+dot\s+json\b"#, "tsconfig.json"),
            (#"(?i)\bgitignore\b"#, ".gitignore")
        ]
        for (pattern, replacement) in knownFiles {
            text = replace(pattern, in: text, with: replacement)
        }

        let extensions = "swift|ts|tsx|js|jsx|json|md|yml|yaml|toml|env|html|css|scss|py|go|rs"
        let pattern = #"(?i)\b([a-z][a-z0-9_-]*)\s+dot\s+("# + extensions + #")\b"#
        return replacingMatches(pattern, in: text) { match in
            guard let base = capture(1, match: match, in: text),
                  let ext = capture(2, match: match, in: text) else {
                return capture(0, match: match, in: text) ?? ""
            }
            return "\(base.lowercased()).\(ext.lowercased())"
        }
    }

    private static func applyFormattingCommands(to input: String) -> String {
        var text = input
        let commands: [(String, String)] = [
            (#"(?i)\bnew\s+paragraph\b"#, "\n\n"),
            (#"(?i)\bnew\s+line\b"#, "\n"),
            (#"(?i)\b(open\s+parenthesis|open\s+paren)\b"#, "("),
            (#"(?i)\b(close\s+parenthesis|close\s+paren)\b"#, ")"),
            (#"(?i)\bopen\s+bracket\b"#, "["),
            (#"(?i)\bclose\s+bracket\b"#, "]"),
            (#"(?i)\bopen\s+brace\b"#, "{"),
            (#"(?i)\bclose\s+brace\b"#, "}"),
            (#"(?i)\bsemicolon\b"#, ";"),
            (#"(?i)\bcolon\b"#, ":"),
            (#"(?i)\bunderscore\b"#, "_"),
            (#"(?i)\bequals?\b"#, "="),
            (#"(?i)\barrow\b"#, "->")
        ]
        for (pattern, replacement) in commands {
            text = replace(pattern, in: text, with: replacement)
        }

        text = replace(#"[ \t]+\n"#, in: text, with: "\n")
        text = replace(#"\n[ \t]+"#, in: text, with: "\n")
        text = replace(#"[ \t]+([\)\]\};:,])"#, in: text, with: "$1")
        text = replace(#"([\(\[\{])\s+"#, in: text, with: "$1")
        text = replace(#"([A-Za-z0-9_])\s+\("#, in: text, with: "$1(")
        text = replace(#"\s*_\s*"#, in: text, with: "_")
        text = replace(#"\s*(->|=)\s*"#, in: text, with: " $1 ")
        text = replace(#"([:;,])(?=\S)"#, in: text, with: "$1 ")
        text = replace(#"[ \t]{2,}"#, in: text, with: " ")
        return text
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        try? NSRegularExpression(pattern: pattern).firstMatch(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
    }

    private static func replace(_ pattern: String, in text: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        return expression.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: replacement
        )
    }

    private static func replacingMatches(
        _ pattern: String,
        in text: String,
        transform: (NSTextCheckingResult) -> String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: transform(match))
        }
        return result
    }

    private static func capture(
        _ index: Int,
        match: NSTextCheckingResult,
        in text: String
    ) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: text) else { return nil }
        return String(text[range])
    }
}
