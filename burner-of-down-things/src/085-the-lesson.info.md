# 085-the-lesson.lua

One lesson's schema (docs/069, issue 1002a) and its append-only writer
(1002b): a turning point, what happened, and the mechanism behind it,
written to `output/story/lessons.md` and never rewritten, and read back
(`read`) as the same records — which feed 1002d's
`mechanism_counts.from_lessons` unchanged. A mechanism that reads as a
mood rather than a mechanism is sent back (1002c, `mood_of`).

| Function | In | Out |
|---|---|---|
| `build(fields)` | `case`, `ledger_lines`, `what_happened`, `mechanism` | a lesson table; refuses a missing field by name, a `mechanism` longer than 20 words or holding a newline, or one `mood_of` finds a mood |
| `mood_of(text)` | a mechanism | nil for a mechanism; otherwise why it reads as a mood: fewer than 3 words, a verdict after a linking word (`was bad`, `were not good`), ending on a verdict (`the build failed`), or nothing but verdicts and filler. Closed word lists (`JUDGEMENT_WORDS`) |
| `read(path)` | a file `append` wrote | its lessons as `build`-shaped records, in order (`{}` for no file); each is rebuilt through `build`, so a hand-edited mood is refused, naming the lesson |
| `append(path, one)` | a file path; an already-built lesson (`build`'s shape) | `one`, unchanged; appends it to `path` as one Markdown section, in a single append-mode write, making `path`'s folder first if needed — never opens `path` for reading, never rewrites what is already there |
| `FIELDS` | | the closed list of a lesson's own field names |
