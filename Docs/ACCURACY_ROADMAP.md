# Accuracy and speed roadmap

Talkmore is deliberately English-only for this phase. The goal is one excellent automatic experience rather than a matrix of languages and model controls.

## Current recognition decision

The preferred Apple-silicon engine is FluidAudio's Parakeet Unified English 0.6B streaming model at its 320 ms tier. Its published same-set benchmark reports 2.37% aggregate word error rate and approximately 10x real-time throughput, while retaining punctuation and capitalization. The other published tiers trade more delay for small accuracy or efficiency differences, so 320 ms best matches push-to-talk insertion.

Talkmore downloads only the files required by that tier—approximately 610 MB—and runs them locally through Core ML. Apple Speech prepares in parallel and is selected automatically while the download is incomplete, if model loading fails, or on a supported non-Apple-silicon Mac. Users do not choose a model.

FluidAudio is Apache-2.0 and is integrated as a pinned package dependency. The downloaded model is CC-BY-4.0. FluidVoice was reviewed for product ideas only: because its application source is GPLv3 and Talkmore is MIT, no FluidVoice application code was copied or adapted.

## Implemented accuracy layers

- **Streaming English ASR:** Parakeet Unified receives ordered microphone buffers and publishes low-latency partial text; finalization drains the remaining audio before insertion settles.
- **Trailing-word protection:** Talkmore prefers a completed transcript available inside the fixed 330 ms release budget and does not let an ordinary partial result end that budget early.
- **Apple first-word hints:** on the fallback path, opening audio is buffered until app vocabulary and personal-dictionary hints are active.
- **Deterministic personal dictionary:** exact local replacements handle names, acronyms, products, and technical spellings without adding inference delay.
- **Automatic correction learning:** Talkmore watches only its settled insertion, requires the same correction twice, excludes unrelated typing and its own polishing, expires evidence after 30 days, and never saves audio.
- **Conversational structure:** explicit sequential English ideas, points, options, reasons, steps, items, or examples become numbered lists. Conservative intent checks preserve ordinary ordinal prose.
- **Asynchronous polish:** optional Apple Intelligence cleanup stays off the visible hot path and applies only if replacing the text remains safe.

## Measurement work still required

1. Create a Talkmore-owned, opt-in audio fixture corpus covering short phrases, accents, names, technical terms, list dictation, background noise, and words spoken at key release.
2. Report word error rate and p50/p95 release-to-insert latency on the same fixtures across representative M-series Macs and the Apple fallback.
3. Measure model download, compiled disk size, peak resident memory, thermal load, and battery impact.
4. Add real-app smoke checks for native fields, Dia/Chrome/Safari website fields, Electron editors, terminals, Mail, Claude, ChatGPT, and YouTube search.
5. Evaluate custom-vocabulary acoustic boosting only if the fixture corpus proves deterministic replacement and Apple hints insufficient; it adds another model and should earn that cost.

## Acceptance gates

An accuracy change is ready only when it:

- improves or preserves word error rate on the same fixture corpus;
- preserves the 330 ms hard trailing-result budget and sub-0.5-second warm insertion target;
- reports p50 and p95 latency rather than a single best run;
- keeps audio and transcript processing on-device;
- documents download size, disk use, memory, and energy for model changes; and
- includes automated policy tests plus manual checks in common native apps and website editors.

## Sources

- [FluidAudio repository and integration documentation](https://github.com/FluidInference/FluidAudio)
- [FluidAudio ASR benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md)
- [Parakeet Unified English Core ML model card](https://huggingface.co/FluidInference/parakeet-unified-en-0.6b-coreml)
- [FluidVoice project reviewed for product behavior](https://github.com/altic-dev/FluidVoice)
