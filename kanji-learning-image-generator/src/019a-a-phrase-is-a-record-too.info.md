# 019a-a-phrase-is-a-record-too — info

Several characters, joined into one record that behaves exactly like a single character's.

For a general: a learner is not trying to hold 時 and 間 separately. They are trying to hold 時間, which means *time*, and that is one thing. This builds a record for a whole word out of the records for the characters in it, in the same shape, so that everything downstream keeps working without being told that anything changed.

Numbered to sit beside `019`, the store it extends, rather than after it.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `019a-a-phrase-is-a-record-too.lua` and
run the sweep again.*

## Invocation

```
luajit src/019a-a-phrase-is-a-record-too.lua --phrases 時間 山口
```

## What it offers

| | |
|---|---|
| `M.cells(record)` | Which characters a record covers, and which strokes belong to each. |
| `M.is_phrase(record)` |  |
| `M.build(characters, meanings, store)` | One record for a whole word. |
| `M.from_argument(text, store)` | One phrase off a command line: 時間=time,an hour |
| `M.from_input(store)` | The phrases somebody has written down in input/, if any. |
| `M.select(store, query)` | The phrases a command line asked for, or nil if it asked for none. |

### `M.cells(record)`

Which characters a record covers, and which strokes belong to each.

A single character is one cell, and saying so here rather than at every call site is what lets the field, the arrows and the scene grammar treat a word and a character as the same kind of thing. Everything asks this; nothing checks whether it was given a phrase.

### `M.build(characters, meanings, store)`

One record for a whole word.

The strokes of every character, in order, each remembering which cell it came from. The components of every character, with their stroke ranges shifted so they still point at the right strokes. And the meanings, which had to be supplied, because the archives gloss characters and not words.

### `M.from_input(store)`

The phrases somebody has written down in input/, if any.

This is where a course's vocabulary list goes, and it is the reason phrases are worth having at all -- one word typed on a command line is a demonstration, and a list of the four hundred a chapter covers is a study set.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `022-the-structure-field`, `027-test-the-meaning`, `030-make-one-kanji`, `031-make-them-all`.
