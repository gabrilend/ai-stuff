# 303 — The canvas sent to the voices

phase 3, the relay through rmail

## Current behavior

Versions reach files on kuvalu (203). The voices cannot see them.

## Intended behavior

A publisher in the blitter's list writes each new version as the body of
`outbox/the-canvas` in the guide mailbox, with the to-voices headers
(`docs/canvas-format.md`: `canvas`, `size`, `mode`, `project`, `written`),
under one `to:` line per voice, by temporary name and rename. kuvalu is the
author, so every edit travels, and each voice's `inbox/the-canvas` always
holds the newest version. A voice that was offline gets only the newest one
when it is reached.

When the tell-the-voice setting is on, the body ends with a `cuts:` section
(`docs/canvas-format.md`, "Cuts"), listing the words each voice cut since its
previous turn landed, taken from the blit's change report (106). All three
voices get the same body, and each reads its own lines.

The `project:` header comes from `input/blitter`: the project being worked
on and its current commit, read from that project's git checkout on kuvalu
at each version. Changing the project is changing one setting.

## Suggested implementation steps

1. The publisher, using the canvas writer (102).
2. Test with the stand-ins (305): each receives the canvas, and receives
   edits as it changes.
3. Count versions handed to rmail in the goodbye receipt.

## Related documents

- `docs/datapath-round-trip.md`, step 1
- `docs/rmail-constraints.md`, "A living message"

## Blocked by

106, 203, 301.

## Blocks

305.
