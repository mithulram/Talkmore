# Security policy

## Supported version

Talkmore is currently an open beta. Security fixes are made on the latest `main` branch; older commits and unofficial binaries are not supported.

## Report a vulnerability privately

Do not open a public issue for a vulnerability involving microphone capture, Accessibility permissions, input monitoring, clipboard handling, local dictation history, unsafe text replacement, arbitrary code execution, credential exposure, or privacy claims.

Use GitHub’s **Report a vulnerability** flow on the repository Security tab. Include:

- the affected commit;
- macOS and hardware version;
- clear reproduction steps;
- impact and any required permissions;
- a minimal proof of concept with private content removed.

Please allow a reasonable period for investigation and a coordinated fix before public disclosure.

## Scope

The supported product is source built directly from this repository. Talkmore currently publishes no signed binary, update service, backend, browser extension, or cloud API. Third-party forks, repackaged downloads, and modified builds are outside this policy.

## Security design

Talkmore intentionally has no network transcription, account system, analytics SDK, or cloud storage. Microphone, Speech Recognition, Accessibility, and Input Monitoring are powerful macOS permissions; the app requests them only for its documented push-to-talk and insertion behavior.
