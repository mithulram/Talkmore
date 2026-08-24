# Changelog

Notable user-visible changes are recorded here. Talkmore follows semantic versioning once public binary releases begin.

## 0.2.0 — Open beta

### Added

- Native SwiftUI menu-bar product experience and working menu actions.
- Global fn/Globe push-to-talk interaction with a voice-responsive overlay.
- On-device Apple `DictationTranscriber` pipeline with prewarming.
- Bounded release finalization to retain trailing words.
- Direct Accessibility insertion and clipboard/paste fallback.
- Automatic, Everyday, Concise, Email, Developer, and Verbatim styles.
- Personal dictionary, local history, copy actions, and customization.
- Optional asynchronous Apple Intelligence cleanup with cursor-safety checks.
- Automated regression tests and real-app compatibility documentation.
- Automatic English engine routing with low-latency Parakeet Unified on Apple silicon and Apple Speech fallback.
- Safe automatic dictionary learning after the same local correction is observed twice.
- Numbered-list formatting for explicit “first, second, third” conversational sequences.

### Changed

- Reduced warm release-to-insert latency toward a sub-0.5-second target.
- Applied app and dictionary vocabulary context before Apple Speech receives the first buffered audio, improving first-word recognition without losing capture.
- Preferred completed Apple transcripts inside the existing 330 ms release window instead of settling on an ordinary partial update.
- Cached personal-dictionary matching rules until entries change, reducing repeated cleanup work.
- Kept live transcript text out of the overlay; the interface shows voice energy only.
- Routed paste fallback through the focused macOS session so website fields in multiprocess browsers—including Claude and YouTube in Dia—receive dictation just like native browser fields.
- Removed language and model choices from the interface; Talkmore is intentionally English-only and automatically chooses the best available path.

### Known limitations

- Source build is required; releases are not yet Developer ID signed or notarized.
- First launch downloads roughly 610 MB of high-accuracy English model files on Apple silicon; Apple Speech remains available while preparation completes.
- Secure input fields and some custom editors can block global key detection or simulated paste.
