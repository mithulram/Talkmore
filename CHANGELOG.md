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

### Changed

- Reduced warm release-to-insert latency toward a sub-0.5-second target.
- Kept live transcript text out of the overlay; the interface shows voice energy only.

### Known limitations

- Source build is required; releases are not yet Developer ID signed or notarized.
- The first dictation after installation, reboot, or language change may be slower while Apple Speech prepares assets.
- Secure input fields and some custom editors can block global key detection or simulated paste.
