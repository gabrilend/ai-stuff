# 201 — Showing notes

Notes as lines a person reads in a terminal.

## Current Behavior

Nothing is built yet.

## Intended Behavior

A module `src/show.lua` returning a table with two functions, working on
notes as defined in 101.

| Function | In | Out |
|---|---|---|
| line(note) | a note | the id right-aligned in four columns, two spaces, the date, two spaces, the text; when the note has tags, two spaces and the tags in square brackets separated by spaces |
| list(notes) | array of notes | every note's line joined by newlines; `(no notes)` for an empty array |

Example: id 3, date 2026-09-26, text "fix the #bike", tags {bike} gives
`   3  2026-09-26  fix the #bike  [bike]`.

## Suggested Implementation Steps

1. line. Test: the example above, and a note with no tags (no brackets).
2. list. Test: two notes give two lines; none gives `(no notes)`.

## Acceptance

```sh
luajit tests/201-showing-notes.lua
```

## Blocked by

- 101

## Covers

- src/show.lua
