# Talkmore product guide

Talkmore lives in the macOS menu bar. Hold fn to speak, release it, and the finished text appears at the cursor. Recognition stays on the Mac. No Talkmore account, server, or analytics service is involved.

## Writing styles

Choose a style from the menu-bar panel or Settings.

| Style | Best for | Behavior |
| --- | --- | --- |
| Automatic | Daily use | Selects Email in mail apps, Developer in coding apps, and Everyday elsewhere. |
| Everyday | Notes and messages | Cleans filler words and punctuation while preserving meaning. |
| Concise | Short replies | Asks optional Apple Intelligence polish to tighten the wording after insertion. |
| Email | Mail and longer replies | Understands “subject line,” “new paragraph,” punctuation commands, greetings, and sign-offs. |
| Developer | Cursor, Xcode, Codex, and terminals | Preserves technical terms and converts spoken casing, symbols, and filenames. |
| Verbatim | Quotes and exact wording | Keeps the recognized wording with only outer whitespace removed. |

Automatic is the recommended default. A manually selected style takes priority in every application.

## Personal dictionary

Open Settings → Dictionary and add the phrase you say beside the exact result you want. Examples:

| Spoken form | Inserted form |
| --- | --- |
| open ai | OpenAI |
| talk more | Talkmore |
| my tool | MyTool |

Longer matches are applied first, matches are case-insensitive, and parts of larger words are not changed. Dictionary entries are stored locally and sent to Apple Speech as recognition hints at the start of the next dictation.

## Local history and copy

The latest 50 successful dictations are kept on the Mac by default. The History tab shows the destination app, writing style, insertion route, and visible latency. Each item has a Copy button, and the menu offers Copy last dictation.

Turn off Save local dictation history in Settings → General when no history should be retained. Existing history can be erased from Settings → History.

## Customization

Settings → General controls:

- writing style and recognition language;
- optional Apple Intelligence polish;
- developer-mode detection;
- whether the voice overlay appears and whether it sits at the top, center, or bottom;
- local history saving;
- macOS permissions.

The voice overlay visualizes microphone level only. It does not display a live transcript.

## App and website compatibility

Talkmore inserts directly through macOS Accessibility when a native control safely exposes its text selection. Browsers, Electron apps, terminals, and JavaScript-controlled website fields use the paste fallback so the destination receives the same input event as a normal paste.

Multiprocess browsers such as Dia keep the address bar and website fields in different processes. Talkmore targets the visible browser and sends paste through the focused macOS session, covering browser UI fields as well as website search bars, chat composers, forms, and content-editable surfaces. Secure-input fields can intentionally reject simulated input.

## Speed and final words

Talkmore prepares the Apple Speech pipeline before the first recording. While fn is held, the transcript remains internal. On release, Talkmore allows a short bounded window for Apple Speech to deliver the final trailing word and then inserts immediately. Optional rewriting never blocks the first insertion.

The visible-latency value in the menu and History is measured from fn release until insertion completes. The target for a warm pipeline is less than 0.5 seconds. The first dictation after a language change or a macOS speech-model download can be slower.

## Privacy

- Audio recognition uses Apple's on-device speech framework.
- Deterministic cleanup, dictionary replacement, history, and settings remain local.
- Optional rewriting uses the on-device Foundation Models framework when Apple Intelligence is enabled.
- Talkmore has no backend, account system, analytics, or network transcription service.
