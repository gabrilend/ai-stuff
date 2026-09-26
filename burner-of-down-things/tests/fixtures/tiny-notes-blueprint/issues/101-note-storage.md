# 101 — Note storage

Notes are kept in one plain text file so a person can read it without the
program.

## Current Behavior

Nothing is built yet.

## Intended Behavior

A module `src/store.lua` returning a table with three functions.

A **note** is a table: `id` (integer, 1 and up), `date` (string,
`YYYY-MM-DD`), `tags` (array of lower-case strings), `text` (string).

The file holds one note per line: id, date, tags joined by commas, text —
separated by single tab characters. A line that does not have that shape is
skipped when loading.

| Function | In | Out |
|---|---|---|
| load(path) | file path | array of notes in file order; an empty array when the file does not exist |
| save(path, notes) | file path; array of notes | writes every note, replacing the file |
| next_id(notes) | array of notes | one more than the highest id, or 1 for none |

## Suggested Implementation Steps

1. load and save. Test: save two notes, load them back, every field equal.
2. next_id. Test: 1 for none; 8 when the highest id is 7, whatever the order.
3. A missing file loads as no notes. Test: load a path that does not exist.

## Acceptance

```sh
luajit tests/101-note-storage.lua
```

## Blocked by

None

## Covers

- src/store.lua
