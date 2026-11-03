# 1003b — The draft form

The second piece of 1003.

## Current Behavior

Built. `src/111-the-strategem-drafts.lua`'s `draft_text(mechanism,
lessons)` writes the house strategem form: title (`Strategem (draft):`),
a paragraph saying it is a draft, a `Mechanism:` line and the mechanism
quoted, then the hand-written strategems' own sections in their order —
What it means, The shape, Examples in this project, When not to use it.
The examples are filled from the recurring lessons, one entry each (case,
ledger lines, what happened) and a line saying how often and in which
cases. `draft_due(lessons_path, strategems_folder)` reads `lessons.md`
(085's reader), counts (1002d), asks 1003a's trigger which mechanisms are
due, and writes their drafts. `machine strategems`
(`115-the-strategem-commands.lua`, docs/012) runs it. Checked by
`tests/112-checking-the-draft-form.lua`: one lesson drafts nothing, a
second of the same mechanism drafts one, it has the house sections in the
house order, and it names both lessons as examples.

Decision: the machine writes only what it knows for certain — the
mechanism and its examples. What it means, the shape and when not to use
it say "Not yet written" until the person (or, later, a drafting turn)
writes them; a template that invented that prose would be a mood dressed
as a strategem.

## Intended Behavior

The draft, in the house strategem form (rao-chat's *other people's
software as a rubric* is the model): what it means, the shape, the
examples (with their lessons), when not to use it.

## Suggested Implementation Steps

1. The strategem template matching the two hand-written strategems' own
   shape. 2. Filling it from the recurring lessons. **Test:** a draft
   from two lessons names both as examples. Done (`draft_text`,
   `draft_due`).

## Blocked by

- 1003a
