# 085-the-lesson.lua

One lesson's schema (docs/069, issue 1002a) and its append-only writer
(1002b): a turning point, what happened, and the mechanism behind it,
written to `output/story/lessons.md` and never rewritten. The fuller
mood-vs-mechanism refusal (1002c) and counting mechanisms across lessons
(1002d, built already against a fixture array of lesson tables) are later
pieces; 1002d's own note says its reader can hand `append`'s file, parsed,
to `mechanism_counts.from_lessons` unchanged once that reader exists.

| Function | In | Out |
|---|---|---|
| `build(fields)` | `case`, `ledger_lines`, `what_happened`, `mechanism` | a lesson table; refuses a missing field by name, or a `mechanism` longer than 20 words or holding a newline |
| `append(path, one)` | a file path; an already-built lesson (`build`'s shape) | `one`, unchanged; appends it to `path` as one Markdown section, in a single append-mode write, making `path`'s folder first if needed — never opens `path` for reading, never rewrites what is already there |
| `FIELDS` | | the closed list of a lesson's own field names |
