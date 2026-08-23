# Talkmore

Talkmore is a private, local-first push-to-talk dictation app for macOS. Hold the fn key, speak naturally, and release to insert clean text into the focused app. Version 0.2 is a usable local beta with a complete menu-bar experience, customization, and no account or cloud transcription.

## Features

- Native SwiftUI menu-bar application
- Hold **fn/Globe** to record
- On-device dictation with Apple's `DictationTranscriber`
- Sub-0.5-second release-to-insert target with a prewarmed recognition pipeline
- Optional in-place Apple Intelligence polish after the first insertion
- Accessibility insertion with a paste fallback
- Non-activating, voice-responsive floating overlay with configurable placement
- Automatic, Everyday, Concise, Email, Developer, and Verbatim writing styles
- App-aware Email and Developer modes
- Personal dictionary for names, products, acronyms, and exact spellings
- Private local history with one-click copy and an option to disable saving
- Original Talkmore app icon and polished menu/settings experience
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

Talkmore keeps transcription internal while you speak, waits briefly for the final trailing word when fn is released, and inserts the latest complete transcript. Optional Apple Intelligence polish continues in the background. The polished result replaces the provisional text only when the cursor has not moved, so Talkmore never overwrites subsequent typing.

## Architecture

Talkmore is a native SwiftUI and AppKit application. It uses `AVAudioEngine` for microphone capture, Apple's `DictationTranscriber` for on-device speech recognition, the Foundation Models framework for optional cleanup, and macOS Accessibility APIs for safe cross-application text insertion.

## Testing

Run the automated regression suite from Xcode with **Product → Test**, or from the command line:

```sh
xcodebuild -project Talkmore.xcodeproj -scheme Talkmore test
```

See [the real-app compatibility checklist](Docs/REAL_APP_TESTING.md) for native, browser, Electron, and terminal testing.

See [developer mode](Docs/DEVELOPER_MODE.md) for supported coding apps and voice formatting commands.

See [the product guide](Docs/PRODUCT_GUIDE.md) for writing styles, dictionary, history, customization, and privacy behavior.
