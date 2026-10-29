# 501 — the speech source

phase 5, the monologue booth

**Depends on:** 101

## Current behavior

No speech exists. The owner chose synthesised speech (2026-10-28). No engine is installed: `/usr/bin/piper` is the gaming-mouse tool; only espeak-ng's runtime library is present. Which engine to install is open question 8 in docs/open-questions.md.

## Intended behavior

A monologue's audio is synthesised from its text by a local speech engine installed under `libs/`, one voice per cast member (a `voice` field on `cast{}`), written as a WAV into the run folder. A monologue that names an `audio` file uses it instead. Lines are synthesised in parallel on the CPU thread pool.

## Suggested implementation steps

1. Answer open question 8 (which engine).
2. An install script for the engine and a few voice models into `libs/`.
3. The synthesis call; test that a sentence gives a WAV of plausible length.

## Related documents

- docs/datapath-monologue.md
- docs/open-questions.md
