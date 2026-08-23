# Install Talkmore

Talkmore is currently an open beta distributed from source. It is not yet Developer ID signed or notarized, so Xcode is the supported and most transparent way to install it.

## Before you start

You need an Apple silicon Mac, macOS 26 or newer, Xcode 26 or newer, and a microphone. You do **not** need a paid Apple Developer account, a Talkmore account, Apple Intelligence, or a cloud API key.

## 1. Download the project

```sh
git clone https://github.com/mithulram/Talkmore.git
cd Talkmore
open Talkmore.xcodeproj
```

You can also use GitHub’s **Code → Download ZIP**, extract it, and open `Talkmore.xcodeproj`.

## 2. Build and launch

1. Wait for Xcode to finish loading the project.
2. Select the **Talkmore** scheme and **My Mac** destination.
3. Press the Run button or use **Product → Run**.
4. If Xcode asks for signing, open the Talkmore target → **Signing & Capabilities** and select your Personal Team.

Talkmore appears in the macOS menu bar, not the Dock.

## 3. Grant permissions

Open the Talkmore menu and follow the permission prompts.

| Permission | System Settings location | Used for |
| --- | --- | --- |
| Microphone | Privacy & Security → Microphone | Recording while fn is held. |
| Speech Recognition | Privacy & Security → Speech Recognition | On-device transcription. |
| Accessibility | Privacy & Security → Accessibility | Inserting text at the cursor. |
| Input Monitoring | Privacy & Security → Input Monitoring | Detecting fn globally. |

After changing Accessibility or Input Monitoring, quit Talkmore and run it again from Xcode so macOS refreshes the permission state.

## 4. Reserve fn for Talkmore

Open **System Settings → Keyboard** and set **Press fn key to → Do Nothing**. This prevents macOS from opening Emoji, switching input sources, or starting system Dictation when Talkmore is listening.

## 5. Dictate

Place the cursor in TextEdit, Mail, a browser, Cursor, Codex, Xcode, or a terminal. Hold **fn**, speak naturally, and release. The first transcription can be slower while macOS prepares or downloads a speech asset; later warm dictations should be substantially faster.

## Optional Apple Intelligence polish

Settings → General can enable on-device text polish. This is optional and never blocks the first insertion. It requires Apple Intelligence to be available and enabled on the Mac. Talkmore still works without it.

## Troubleshooting

### The overlay appears but no text is inserted

- Confirm all four permissions show as enabled.
- Quit and relaunch Talkmore after granting Accessibility or Input Monitoring.
- Try TextEdit. If TextEdit works, add the affected app and your compatibility result to a [bug report](https://github.com/mithulram/Talkmore/issues/new/choose).
- Check that the target field is editable and still focused when fn is released.

### Nothing happens when fn is held

- Set the macOS fn action to **Do Nothing**.
- Re-enable Input Monitoring for the exact Talkmore build that Xcode launched.
- Quit any other push-to-talk utility that captures fn.

### Text is transcribed but not pasted in Cursor, Codex, or a terminal

- Enable Accessibility for Talkmore.
- Keep the target editor focused through release.
- Check whether a clipboard manager or secure-input field is blocking simulated paste.
- Use the [real-app checklist](REAL_APP_TESTING.md) to capture a reproducible result.

### The first dictation is slow

This is expected after a new installation, language change, reboot, or Apple speech-model download. Test two or three dictations before measuring the warm path.

### The final word is missing

Update to the latest `main` branch. Talkmore includes a bounded release finalization window specifically for trailing words. If the problem remains, report the exact phrase, app, language, and visible latency.

## Update an existing checkout

```sh
git pull --ff-only
open Talkmore.xcodeproj
```

Build and run again. An ad-hoc development build can occasionally require a permission refresh.

## Remove Talkmore

Quit Talkmore, delete the local project/build, and remove Talkmore from the four Privacy & Security permission lists if desired. Use Talkmore’s History controls to erase saved dictations before removal.
