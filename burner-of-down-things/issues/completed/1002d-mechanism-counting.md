# 1002d — Mechanism counting

The fourth piece of 1002.

## Current Behavior

Built. `src/095-mechanism-counts.lua`'s `from_lessons(lessons)` counts an
array of already-built lesson records (085's shape) — not
`output/story/lessons.md` itself, since 1002b (the append-only writer) is
not yet built (strategems/build-to-the-shape-not-the-neighbor.md — its
second example). Checked by `tests/096-checking-mechanism-counts.lua`,
which also proves its real counts feed 1003a's `strategem_trigger.due`
(088) unchanged. The day 1002b exists, its reader can parse `lessons.md`
into the same array of lesson records and hand it here unchanged.

## Intended Behavior

A growing list of mechanisms the machine counts (not judges) from
`lessons.md`, so recurrence is counted plainly — what 1003 reads to decide
when to draft a strategem.

## Suggested Implementation Steps

1. The mechanism-list reader over `lessons.md`. Deferred: reads an array
   of lesson records instead, until 1002b's writer exists to parse
   `lessons.md` into that same shape. 2. The count-by-mechanism-text
   function. Done: `095-mechanism-counts.lua`'s `from_lessons`. **Test:**
   the same mechanism in two cases counts two. Done.

## Blocked by

- 1002b
