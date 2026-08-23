# Real-app compatibility testing

Talkmore uses two insertion routes:

1. **Accessibility** — direct insertion with safe in-place background polishing.
2. **Paste fallback** — broad compatibility when an app does not expose editable Accessibility attributes.

The menu-bar panel shows the route used for the most recent dictation.

## Compatibility matrix

| App surface | Technology | Accessibility audit | Voice test |
| --- | --- | --- | --- |
| Codex composer | Native/web hybrid | Editable field available | Working during development |
| TextEdit document | AppKit rich text | Editable text area available | Manual regression required |
| Apple Notes editor | AppKit rich text | Editable surface available | Manual regression required |
| Safari address/search | AppKit field | Editable field available | Manual regression required |
| Cursor composer/editor | Electron/Monaco | Editable composer available | Manual regression required |
| Terminal prompt | Terminal text surface | Automation restricted | Manual regression required |

## Manual regression script

For each app:

1. Put the cursor in an empty editable field.
2. Hold fn and say: “Talkmore compatibility test for this application.”
3. Release fn and verify visible text appears within 0.5 seconds.
4. Confirm the final word “application” is present.
5. Wait for background polish without moving the cursor.
6. Confirm the menu shows the application name, insertion route, visible latency, and final latency.
7. Repeat while immediately typing after insertion; Talkmore must not overwrite the new typing.

Never press Return in chat composers, browser address fields, or Terminal during compatibility testing.
