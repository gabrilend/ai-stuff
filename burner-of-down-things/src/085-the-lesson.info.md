# 085-the-lesson.lua

One lesson's schema (docs/069, issue 1002a): a turning point, what
happened, and the mechanism behind it. Append-only writing (1002b), the
fuller mood-vs-mechanism refusal (1002c) and counting mechanisms across
lessons (1002d) are later pieces.

| Function | In | Out |
|---|---|---|
| `build(fields)` | `case`, `ledger_lines`, `what_happened`, `mechanism` | a lesson table; refuses a missing field by name, or a `mechanism` longer than 20 words or holding a newline |
| `FIELDS` | | the closed list of a lesson's own field names |
