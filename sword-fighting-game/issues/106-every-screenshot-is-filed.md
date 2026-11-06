# 106 — Every Screenshot Is Filed

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | 104 |
| Blocks | phase 4 demo |
| Files | `src/030-screenshots.lua`, `scripts/file-screenshots`, `development-history/` |

## Current behavior

Built: `src/030-screenshots.lua` captures with a sidecar; `./run-game`
calls `scripts/file-screenshots` after the window closes, which numbers each
picture into development-history/, stores a fingerprint beside it and writes
the notes page with what changed since the previous picture. The two written
sections of each notes page are not yet filled in. Pictures taken while
another window covered the game, or after the window manager resized it, are
black (011-016); they are kept. In progress until the open question below is
answered.

## Intended behavior

A screenshot (F12, or `--screenshot SECONDS NAME`) is captured by the engine
into tmp/shared-memory/screenshots/ with a name and the tick it was taken on,
plus a small sidecar recording the run options, the seed and the tick.

When the game exits, the run script calls `scripts/file-screenshots`, which
moves each new picture into development-history/ under the next number
(001-name.png, 002-name.png, ...) and writes beside it 001-name.info.md
with:

- **What made it** — the commit, the run options, the seed and tick.
- **What changed since the previous picture** — which source and settings
  files differ, found by comparing a fingerprint (a checksum of every file
  under src/, assets/ and config.lua) stored beside each picture with the one
  stored beside the previous.
- **What it shows** — left for the person or agent to fill in.
- **The story so far** — left for the person or agent to fill in.

Nothing is thrown away: a wrong or empty picture is filed too.

## Suggested implementation steps

1. Capture with the engine's screenshot call; write the sidecar beside it.
2. Write the filing script in Lua: next number from the folder listing,
   fingerprint by `sha1sum` of each file, diff of fingerprints.
3. Test: filing two fake pictures numbers them 001 and 002 and the second's
   notes list the file that changed between them.

## Open questions

- Should demos run the game on a tag of its own, or should screenshots be
  rendered off screen (into a canvas) so they never depend on the desktop?
