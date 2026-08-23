# Contributing to Talkmore

Thanks for helping make local Mac dictation better. Talkmore welcomes reproducible bug reports, real-app compatibility results, documentation improvements, tests, and focused code changes.

## Before opening an issue

1. Update to the latest `main` branch.
2. Read the [installation troubleshooting guide](Docs/INSTALLATION.md).
3. Confirm the behavior in TextEdit and the affected app.
4. Search existing issues so results stay in one place.

Use the bug report template and include macOS version, Mac model, app/version, recognition language, selected writing style, a safe example phrase, insertion route if visible, and release-to-insert latency. Never attach private dictation history or audio you do not intend to publish.

## Development setup

1. Fork and clone the repository.
2. Open `Talkmore.xcodeproj` in Xcode 26 or newer.
3. Build the Talkmore scheme for My Mac.
4. Run the tests before and after your change:

```sh
xcodebuild -project Talkmore.xcodeproj -scheme Talkmore test
```

The product website lives in `Website/` and requires Node.js 22.13 or newer:

```sh
cd Website
pnpm install --frozen-lockfile
pnpm run build
```

## Pull requests

- Keep each pull request focused on one problem.
- Explain user-visible behavior and any latency, memory, privacy, or permission impact.
- Add regression tests for cleanup, state, dictionary, insertion planning, or app detection changes.
- Update documentation when behavior or requirements change.
- Do not add telemetry, network transcription, or a new runtime dependency without prior discussion.
- Do not commit generated build products, signing material, personal histories, recordings, or credentials.

For behavior that affects cross-app insertion, complete the relevant rows in [the real-app checklist](Docs/REAL_APP_TESTING.md).

## Product principles

1. Initial insertion stays fast; optional intelligence happens later.
2. Audio and dictation content stay on the Mac by default.
3. A failure must not overwrite the user’s later typing or silently lose clipboard data.
4. The app remains usable on an 8 GB Apple silicon Mac.
5. Product claims must be measurable and honest.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
