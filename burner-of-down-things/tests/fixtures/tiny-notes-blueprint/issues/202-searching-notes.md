# 202 — Searching notes

Finding notes by a word in their text.

## Current Behavior

Nothing is built yet.

## Intended Behavior

A module `src/search.lua` returning a table with one function, working on
notes as defined in 101.

| Function | In | Out |
|---|---|---|
| find(notes, word) | array of notes; a word | the notes whose text contains the word, ignoring case, as plain text (no pattern characters), in their order |

## Suggested Implementation Steps

1. find. Test: "CHAIN" finds "fix the bike chain"; "a.b" finds only text
   holding a literal "a.b".

## Acceptance

```sh
luajit tests/202-searching-notes.lua
```

## Blocked by

- 101

## Covers

- src/search.lua
