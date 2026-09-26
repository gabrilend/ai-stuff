# 206 — Phase 2 demo

## Current Behavior

No demo.

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
