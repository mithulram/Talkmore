# Talkmore product guide

Talkmore lives in the macOS menu bar. Hold fn to speak, release it, and the finished text appears at the cursor. Recognition is English-only for now and stays on the Mac. No Talkmore account, server, or analytics service is involved.

## Automatic English recognition

There is no language or model selector. On Apple silicon, Talkmore prepares the Parakeet Unified English 320 ms streaming model in the background and automatically starts using it when ready. The first preparation downloads approximately 610 MB of model files. Until then—or if the model cannot load—Talkmore transparently uses Apple Speech. Other Macs supported by macOS 26 use the Apple fallback.

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

## Personal and automatic dictionary

Open Settings → Dictionary and add the phrase you say beside the exact result you want. Examples:

| Spoken form | Inserted form |
| --- | --- |
| open ai | OpenAI |
| talk more | Talkmore |
| my tool | MyTool |

Longer matches are applied first, matches are case-insensitive, and parts of larger words are not changed. Dictionary entries are stored locally and sent to Apple Speech as recognition hints at the start of the next dictation. Talkmore captures immediately while holding its first audio buffers until those hints are active, which helps names and technical terms at the beginning of an utterance without dropping the first word.

Talkmore also watches only the text range it just inserted. When the same spelling correction is made twice, it adds the correction to the personal dictionary automatically. Ordinary text typed before or after the inserted range is ignored, app-generated polishing is excluded, audio is never retained, and automatic evidence expires after 30 days.

## Conversational structure

Everyday, Concise, Email, and Automatic styles recognize explicit English sequences. For example, “I have two ideas. First one is improve recognition, and second one is reduce latency” becomes a short introduction followed by a numbered list. Talkmore requires sequential markers and list intent, so ordinary sentences such as “the first one is blue and the second one is green” stay unchanged. Developer and Verbatim modes preserve their specialized behavior.

## Local history and copy

The latest 50 successful dictations are kept on the Mac by default. The History tab shows the destination app, writing style, insertion route, and visible latency. Each item has a Copy button, and the menu offers Copy last dictation.

Turn off Save local dictation history in Settings → General when no history should be retained. Existing history can be erased from Settings → History.

## Customization

Settings → General controls:

- writing style (recognition is fixed to English and the engine is automatic);
- optional Apple Intelligence polish;
- developer-mode detection;
- whether the voice overlay appears and whether it sits at the top, center, or bottom;
- local history saving; and
- macOS permissions.

The voice overlay visualizes microphone level only. It does not display a live transcript.

## App and website compatibility

Talkmore inserts directly through macOS Accessibility when a native control safely exposes its text selection. Browsers, Electron apps, terminals, and JavaScript-controlled website fields use the paste fallback so the destination receives the same input event as a normal paste.

Multiprocess browsers such as Dia keep the address bar and website fields in different processes. Talkmore targets the visible browser and sends paste through the focused macOS session, covering browser UI fields as well as website search bars, chat composers, forms, and content-editable surfaces. Secure-input fields can intentionally reject simulated input.

## Speed and final words

Talkmore prepares both the preferred English model and Apple fallback before use. While fn is held, the transcript remains internal. On release, Talkmore finalizes recognition inside the existing 330 ms window. For Apple Speech, a partial update does not prematurely close that window, while a stable final result can still insert early. Optional rewriting never blocks the first insertion.

The visible-latency value in the menu and History is measured from fn release until insertion completes. The target for a warm pipeline is less than 0.5 seconds. First launch can spend time downloading and compiling the high-accuracy model, but Apple Speech remains usable during preparation.

## Privacy

- Audio recognition runs locally through Parakeet Unified or Apple's on-device Speech framework.
- Network access is used only to download model weights during first preparation, not to upload audio or transcripts.
- Deterministic cleanup, dictionary replacement, history, and settings remain local.
- Optional rewriting uses the on-device Foundation Models framework when Apple Intelligence is enabled.
- Talkmore has no backend, account system, analytics, or network transcription service.
