# Developer mode

Talkmore automatically enables developer mode when dictating into a supported coding app. It stays on the same local, fast English path: Talkmore applies dictionary replacements and deterministic formatting before the first text insertion, while Apple Speech fallback also receives technical vocabulary hints. Apple Intelligence cleanup remains optional and runs afterward.

Developer mode is enabled by default and can be switched off from the menu bar or Settings.

## Supported apps

- Cursor
- Xcode
- Visual Studio Code
- Terminal and iTerm
- Warp
- Zed
- Ghostty
- Codex
- T3 Code

Other apps keep normal prose behavior, so phrases such as “new line” are not converted outside coding apps.

## Voice commands

| Say | Result |
| --- | --- |
| `camel case user profile` | `userProfile` |
| `snake case user profile` | `user_profile` |
| `Pascal case user profile` | `UserProfile` |
| `camel case user profile end case` | `userProfile` inside a longer sentence |
| `new line` / `new paragraph` | One / two line breaks |
| `open parenthesis` / `close parenthesis` | `(` / `)` |
| `open bracket` / `close bracket` | `[` / `]` |
| `open brace` / `close brace` | `{` / `}` |
| `underscore`, `colon`, `semicolon` | `_`, `:`, `;` |
| `equals`, `arrow` | `=`, `->` |
| `read me dot md` | `README.md` |
| `server dot swift` | `server.swift` |

Talkmore also normalizes common names such as SwiftUI, AppKit, Xcode, GitHub, JavaScript, TypeScript, Node.js, Next.js, OpenAI, and ChatGPT.

Whole-utterance casing commands format everything after “case.” When using a casing command inside a longer request, end it with “end case” so Talkmore knows exactly where the identifier ends.
