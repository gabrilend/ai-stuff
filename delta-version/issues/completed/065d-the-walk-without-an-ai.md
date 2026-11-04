# Issue 065d: The Walk Without an AI

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: 065a, 065b, 065c
**Blocks**: 065g

## Current Behavior
`scripts/reading-walk.lua <project>` walks the map in index order (building it
first when the RAM tier has none, which happens after every reboot). Choices
and their letters are tabled in `scripts/reading-walk.info.md`.

## Intended Behavior
At each stop: position, file and line, chapter, name and kind, description
(marked when it came from a comment or is missing), and how many uses and
recorded reasons there are. The reader picks a letter: next, more (uses), why
(reasons, or "no alternative was recorded here"), code (the stop's own lines),
skip (prints the summary, then moves on — "yeah yeah…" typed in is the same),
skip the rest of the file (every remaining summary), back, quit. Showing more
of a stop keeps it on screen without redrawing it. Choices are a table of
letter → action, each returning the next stop.

A walk that began at the first stop and passed the last is called complete;
one begun partway says where it started; one quit early is paused. A receipt
line counts stops shown, skipped, and uses, reasons and code looked at.

`--choices=LETTERS` takes choices from a string, one letter each, and quits
when they run out, so a test or demo can drive the walk with no person and
cannot hang.

## Suggested Implementation Steps
1. Stop screen; choice table; scripted choices.
2. Tests: complete walk, skip summary, partway start, file skip, "yeah yeah",
   no-reason message.
