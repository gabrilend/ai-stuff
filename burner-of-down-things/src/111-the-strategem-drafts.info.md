# 111-the-strategem-drafts.lua

Strategems drafted from recurring lessons (docs/069, issue 1003): for every
mechanism counted in two or more lessons of `output/story/lessons.md`
(1003a's trigger), a draft in the house strategem form (1003b) in
`strategems/drafts/`, one file per mechanism, whose examples are rewritten
in place on a further recurrence (1003c). Only the person's promotion
script moves a draft into `strategems/` (1003d); nothing else here writes
outside `drafts/`, and a kept strategem is never touched again.

A **draft**: `# Strategem (draft): <Mechanism>`, a paragraph saying it is a
draft, `Mechanism: <text>` (the line `known` reads back), the mechanism
quoted, then the hand-written strategems' own sections in their order —
What it means, The shape, Examples in this project (one entry per lesson:
case, ledger lines, what happened; then how often and in which cases), When
not to use it. The three prose sections say `NOT_YET_WRITTEN` until the
person (or a later drafting turn) writes them.

| Function | In | Out |
|---|---|---|
| `draft_due(lessons_path, strategems_folder)` | the lessons file; the `strategems/` folder | writes new drafts, refreshes changed examples; `{drafted, updated, kept}` (paths; `kept` = strategems the person kept whose mechanism has recurred, left untouched) |
| `draft_text(mechanism, lessons)` | a mechanism; its lesson records | the whole draft |
| `with_examples(text, lessons)` | a draft's text; its lessons | the same text with only the examples section replaced |
| `examples_text(lessons)` | lesson records | the examples section's body |
| `name_for(mechanism)` | a mechanism | its file name: its words, lower case, joined by dashes, `.md` |
| `mechanism_of(text)` | a draft's or kept strategem's text | its `Mechanism:` line, or nil (hand-written strategems) |
| `known(strategems_folder)` | the `strategems/` folder | `{[mechanism] = {path, kept}}` for drafts and kept strategems |
| `promote(strategems_folder, name)` | the folder; a draft's file name | moves it to `strategems/<name>`, retitled `Strategem:`; refuses a missing draft, a name with a `/`, or a strategem already kept under that name. Returns the new path and the sections still not written |
