# Talkmore

Talkmore is a fast, local-first push-to-talk dictation utility for macOS. Hold the fn key, speak naturally, and release to insert polished text into the focused app.

> Talkmore is currently an early alpha intended for local development and testing.

## Features

- Native SwiftUI menu-bar application
- Hold **fn/Globe** to record
- On-device dictation with Apple's `DictationTranscriber`
- Instant streaming insertion followed by optional in-place Apple Intelligence polish
- Accessibility insertion with a paste fallback
- Non-activating floating recording overlay
- Voice-responsive listening animation
- No backend, analytics, accounts, or network transcription

## Requirements

- macOS 26 or newer
- Apple silicon Mac
- Microphone, Speech Recognition, Accessibility, and Input Monitoring permissions
- Apple Intelligence enabled for optional background polishing

## Run locally

1. Open `Talkmore.xcodeproj` in Xcode.
2. Select the Talkmore target and choose a Development Team if Xcode requests one.
3. Run the app.
4. Open Talkmore from the menu bar and grant the requested permissions.
5. Hold **fn/Globe**, speak, and release.

If macOS also opens Emoji, Dictation, or switches input sources, change the Globe/fn key action to **Do Nothing** in System Settings → Keyboard.

The first transcription may take longer while macOS downloads the language asset. Apple Intelligence must be enabled for automatic cleanup; raw on-device transcription still works when cleanup is unavailable.

Talkmore inserts the latest streaming transcript immediately after the fn key is released. Final speech recognition and Apple Intelligence polish continue in the background. The polished result replaces the provisional text only when the cursor has not moved, so Talkmore never overwrites subsequent typing.

## Architecture

Talkmore is a native SwiftUI and AppKit application. It uses `AVAudioEngine` for microphone capture, Apple's `DictationTranscriber` for on-device speech recognition, the Foundation Models framework for optional cleanup, and macOS Accessibility APIs for safe cross-application text insertion.
