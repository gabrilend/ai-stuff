# 019-the-kanji-record — info

Puts the two archives together, and is the only shape the rest of the project ever sees a kanji in.

For a general: one archive knows what a character looks like and the other knows what it means, and neither knows about the other. This joins them on the character itself and hands out a single record holding both -- the strokes in writing order, the pieces the character is built from, the English glosses, the readings, and the few numbers that say who learns it and when.

It also says what did not join, and that half matters as much. One archive describes about twice as many characters as the other draws, so a plain join silently discards thousands of entries. Silently is the problem: a set that shrinks without saying so is a set nobody notices has shrunk.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `019-the-kanji-record.lua` and
run the sweep again.*

## Invocation

```
luajit src/019-the-kanji-record.lua [--dir ROOT] [--report] [--chars 木火水]
```

## What it offers

| | |
|---|---|
| `M.build()` | Read both archives, join them, and describe what did not join. |
| `M.store(options)` | The joined store, from the cache if the archives have not changed. |
| `M.select(store, query)` | Characters, chosen the way the command line asked. |
| `M.selector_names()` | The ways of choosing that exist, for a program printing its own usage. |
| `M.describe(store)` | What the join produced and what it cost, as lines of text. |

### `M.build()`

Read both archives, join them, and describe what did not join.

Returns the store. Slow -- it parses thirty megabytes -- so callers should go through M.store, which caches this.

### `M.store(options)`

The joined store, from the cache if the archives have not changed.

The cache lives in the RAM tier rather than in the repository: it is derived from two files that are themselves not committed, it is rebuildable in a few seconds, and a batch run spawns a worker per processor -- each of which would otherwise re-parse thirty megabytes to look at its own share of the set.

### `M.select(store, query)`

Characters, chosen the way the command line asked.

The query is the parsed argument table. Selectors are tried in a fixed order so that two of them given at once behave the same way every time rather than depending on which the hash happened to offer first.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `archive_stamp()` | A short string that changes when either archive does. |
| `split(line)` | One cache line's fields, including the empty ones. |
| `blank(value)` | nil written as nothing, so an absent number stays absent. |
| `write_cache(store, path)` | The store, as flat lines. |
| `read_cache(path, stamp)` | The store, read back, or nil if the file is absent or stale. |
| `is_ideograph(codepoint)` | Whether a character number is a Chinese character at all. |
| `is_duplicate_form(codepoint)` | Whether a character number is in the compatibility block. |
| `main(argv)` |  |

## Where it sits

Used by `020-test-the-ink`, `021-the-shape-of-a-stroke`, `022-the-structure-field`, `023-the-component-lexicon`, `024-the-scene-grammar`, `025-the-words-the-machine-reads`, `026-arrows-that-teach-the-order`, `027-test-the-meaning`.
