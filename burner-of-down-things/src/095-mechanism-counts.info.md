# 095-mechanism-counts.lua

How often each mechanism recurs (docs/069, issue 1002d), counted from an
array of lesson records (085's shape). For the lessons file itself:
`from_lessons(lesson.read("output/story/lessons.md"))` (085's reader).
Feeds 1003a's `strategem_trigger.due` unchanged.

| Function | In | Out |
|---|---|---|
| `from_lessons(lessons)` | array of lesson tables (085's `build` shape) | `{[mechanism] = count}` |
