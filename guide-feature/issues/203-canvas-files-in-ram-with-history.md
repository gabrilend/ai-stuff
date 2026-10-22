# 203 — Canvas files in RAM, with history

phase 2, the canvas for viewers

## Current behavior

The blitter keeps versions in memory and publishes only to its log (107).

## Intended behavior

A publisher in the blitter's list writes each new version, with its marks,
to `tmp/shared-memory/canvas/current` (temporary name, then rename) and to
`tmp/shared-memory/canvas/history/NNNNNN`, never rewritten. The blitter
reads bases back from the history instead of holding every version in
memory.

At start the folder is emptied of the previous run, unless the owner decides
the history should survive a restart (`docs/open-questions.md`, 6).

## Suggested implementation steps

1. The publisher, using the canvas writer (102).
2. The blitter's base lookup reading from history.
3. A test that runs a replay and checks the history has every version with
   no gaps, and that `current` equals the last.

## Related documents

- `docs/canvas-protocol.md`, "On kuvalu: files"

## Open questions

- Keep the history across restarts? (`docs/open-questions.md`, 6)

## Blocked by

107, 201.

## Blocks

204, 206, 303, 801, 802.
