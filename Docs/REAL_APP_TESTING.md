# Real-app compatibility testing

Talkmore uses two insertion routes:

1. **Accessibility** — direct insertion with safe in-place background polishing.
2. **Paste fallback** — broad compatibility when an app does not expose editable Accessibility attributes.

The menu-bar panel shows the route used for the most recent dictation.

## Compatibility matrix

| App surface | Technology | Accessibility audit | Voice test |
| --- | --- | --- | --- |
| Codex composer | Native/web hybrid | Editable field available | Paste route verified |
| TextEdit document | AppKit rich text | Editable text area available | Manual regression required |
| Apple Notes editor | AppKit rich text | Editable surface available | Manual regression required |
| Safari address/search | AppKit field | Editable field available | Manual regression required |
| YouTube search in Safari/Chrome | Web input | DOM input event required | Paste route selected |
| Dia address/search | Browser UI field | Main browser process | Paste route selected |
| Claude/YouTube fields in Dia | Chromium renderer | Session-focused paste required | Paste route selected |
| Cursor composer/editor | Electron/Monaco | Paste route selected | Verified during development |
| Terminal prompt | Terminal text surface | Automation restricted | Manual regression required |

Browsers, Cursor, and Codex intentionally prefer the paste route. Website inputs can expose a writable Accessibility value without sending the DOM input event that JavaScript-controlled fields require, while Electron and hybrid editors do not always expose a stable editable Accessibility value.

For multiprocess browsers, Talkmore records the visible frontmost browser as the destination even when the focused web control is exposed by a renderer/helper process. Paste shortcuts are sent through the logged-in session's focused control so native browser fields and webpage renderer fields receive the same input path.

## Manual regression script

For each app:

1. Put the cursor in an empty editable field.
2. Hold fn and say: “Talkmore compatibility test for this application.”
3. Release fn and verify visible text appears within 0.5 seconds.
4. Confirm the final word “application” is present.
5. Wait for background polish without moving the cursor.
6. Confirm the menu shows the application name, insertion route, visible latency, and final latency.
7. Repeat while immediately typing after insertion; Talkmore must not overwrite the new typing.

The development build also accepts `SIGUSR1` as an fn press and `SIGUSR2` as an fn release. This makes repeatable timing tests possible without changing the production hotkey behavior.

Never press Return in chat composers, browser address fields, or Terminal during compatibility testing.

For website coverage, repeat the script in a standard text input, a JavaScript-controlled search box such as YouTube search, and a content-editable field. All three should show **Paste fallback** in Talkmore's latest compatibility summary.
