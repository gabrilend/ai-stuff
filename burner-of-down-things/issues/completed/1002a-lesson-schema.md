# 1002a — The lesson schema

The first piece of 1002.

## Current Behavior

Built. `src/085-the-lesson.lua`'s `build(fields)` checks every field
(`case`, `ledger_lines`, `what_happened`, `mechanism`) is present and that
`mechanism` reads as a short, single-line sentence (at most 20 words).
This is the shape check alone; 1002c's mood-vs-mechanism judgement (a bare
value word like "bad" is not a mechanism) tightens it further. Checked by
`tests/086-checking-the-lesson.lua`.

## Intended Behavior

A lesson: its case, the ledger lines it draws on, what happened, and a
**mechanism** in a short fixed form (`a builder grading its own work
passes itself`) — not a mood (docs/069).

## Suggested Implementation Steps

1. The schema as a Lua table. Done: `085-the-lesson.lua`'s `FIELDS`. 2. The
   fixed-form check on `mechanism` (a short sentence, not a paragraph).
   Done: length and single-line checks; the mood-vs-mechanism judgement
   itself is 1002c. **Test:** a lesson missing any field is refused,
   naming which. Done.

## Blocked by

- 1001
