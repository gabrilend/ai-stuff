# 013-read-the-meanings — info

Reads the dictionary archive: what each character means, how it is said, and the handful of numbers that say who learns it and when.

For a general: the stroke archive knows what a character looks like and nothing about what it is for. This is the other half. It is an ordinary dictionary in XML -- one entry per character, holding English glosses in order of importance, Japanese readings split by where they came from, and some catalogue numbers.

Most of the entry is thrown away. The archive carries a few dozen references into specific paper dictionaries so a person can look a character up in a book, and nothing here is looking anything up in a book.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `013-read-the-meanings.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.read(path, wanted)` | The whole dictionary, as a table keyed by character. |

### `M.read(path, wanted)`

The whole dictionary, as a table keyed by character.

`wanted`, if given, is a set of characters to keep.

Each entry holds:   character      the character itself   meanings       English glosses, primary first   readings_on    borrowed-from-Chinese readings, in katakana   readings_kun   native Japanese readings, in hiragana   grade          the school year it is taught in, or nil   jlpt           the proficiency level it appears at, or nil   frequency      its rank by newspaper frequency, or nil   stroke_count   how many strokes the dictionary says it has   radical        its classical radical number

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `handlers.open(name, attribute_text, self_closing)` |  |
| `handlers.text(raw)` |  |
| `handlers.close(name)` |  |

## Where it sits

Used by `019-the-kanji-record`.
