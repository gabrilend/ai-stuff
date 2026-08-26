# 012-read-the-strokes — info

Reads the stroke archive: what every character is drawn with, in the order a hand draws it, and what pieces it is built out of.

For a general: this is the file that makes the whole project possible. The archive does not merely hold an outline of each character -- it holds the individual brush strokes, in writing order, wrapped in groups that say which smaller character each stroke belongs to. So the archive states outright that the character for "rest" is a person standing next to a tree, and it states which of those two was written first.

Both of those facts survive into the record this produces. The picture the project eventually describes is built out of them.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `012-read-the-strokes.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.read(path, wanted)` | The whole stroke archive, as a table keyed by character. |
| `M.component_owner(entry, stroke_index)` | Which component a given stroke belongs to, as a component table. |

### `M.read(path, wanted)`

The whole stroke archive, as a table keyed by character.

`wanted`, if given, is a set of characters to keep. Everything else is parsed and thrown away rather than skipped -- the scan is a single forward pass and there is nowhere to skip to -- but nothing is retained, which is what matters when a caller wants four characters out of six thousand.

Each entry holds:   character   the character itself   codepoint   its number   strokes     an array, in writing order   components  an array, outermost first

A stroke holds its raw path text, the calligraphic class the archive assigned it, and the index of the innermost component that owns it. A component holds the character it is, where it sits, whether it is there for its sound, and the range of strokes it covers.

### `M.component_owner(entry, stroke_index)`

Which component a given stroke belongs to, as a component table.

The stroke records the position of its group on the stack at the time it was read, which is not the position of that component in the finished array -- the array was reversed. This does the lookup by stroke range instead, taking the innermost match, which does not depend on either ordering surviving.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `finish_group(frame)` | A group has closed: record it as a component if it named one. |
| `handlers.open(name, attribute_text, self_closing)` |  |
| `handlers.close(name)` |  |

## Where it sits

Used by `019-the-kanji-record`.
