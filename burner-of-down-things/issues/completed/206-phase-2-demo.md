# 206 — Phase 2 demo

## Current Behavior

Built: `issues/completed/demos/phase-2-demo` and `phase-2-demo.lua`. Surveys kiln, rao-chat, wow-chat-2026's `src/` and a copy of this machine into scratch cases and prints them side by side (files, lines, languages, links, the most leaned-on file, entry points, compile units, outside dependencies, timing, ledger head), then surveys the AzerothCore source at 1, 2, 4 and every thread with bars. Columns are padded by characters, not bytes, so the `…` marks line up.

## Intended Behavior

`issues/completed/demos/phase-2-demo`: opens one case per project it can
find — kiln, rao-chat, wow-chat-2026's `src/`, and a copy of this machine —
surveys each, and prints them side by side: files, lines, languages, the
likely foundations and entry points, the outside dependencies. Then surveys
the largest one on one thread and on all of them and prints files per second
for each. Uses phase 1's ledger to show each case's head hash.

## Suggested Implementation Steps

1. The demo script; missing example projects are named and skipped, the
   demo still runs on the ones present — and says which were missing.
2. **Test:** runs to the end through `./run-phase-demo 2`.

## Blocked by

- 205
