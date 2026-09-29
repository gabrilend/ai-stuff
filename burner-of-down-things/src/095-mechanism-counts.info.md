# 095-mechanism-counts.lua

How often each mechanism recurs (docs/069, issue 1002d), counted from an
array of already-built lesson records (085's shape) rather than from
`output/story/lessons.md` directly — 1002b's writer is not yet built.
Feeds 1003a's `strategem_trigger.due` unchanged.

| Function | In | Out |
|---|---|---|
| `from_lessons(lessons)` | array of lesson tables (085's `build` shape) | `{[mechanism] = count}` |
