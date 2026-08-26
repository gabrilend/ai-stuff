# 024-the-scene-grammar — info

Decides what the picture is of.

For a general: `022` decided where the darkness goes. This decides what the darkness *is*. It answers four questions about a character, in an order where each answer narrows the next: what world is this, who is in it, what is each individual line, and which way round is the light.

What comes out is a table of facts and contains no prose. `025` turns facts into a sentence. Keeping those apart is what lets the wording be rewritten without touching the reasoning, and the reasoning to be tested without reading any English -- so the tests for this file assert that a river lands in the water world, not that it produced a good-sounding phrase.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `024-the-scene-grammar.lua` and
run the sweep again.*

## Invocation

```
luajit src/024-the-scene-grammar.lua --spread
```

## What it offers

| | |
|---|---|
| `M.biomes()` | Every world there is, in order. |
| `M.score(record, measured, settings)` | How much evidence there is for each world, and which wins. |
| `M.scene(record, store, settings, options)` | One record in, one scene out. Or nil and a reason. |
| `M.spread(store, settings)` | Which worlds the whole set lands in. |

### `M.score(record, measured, settings)`

How much evidence there is for each world, and which wins.

Scoring rather than branching. Three kinds of evidence, weighted differently because they are differently trustworthy:

  a piece of the character   strongest -- it is what the character was                              actually built out of   the primary gloss          next -- the sense the character is normally                              used in, and the archive orders them   a later gloss              weakest -- a secondary sense, or a translator's                              second attempt at the same one

### `M.scene(record, store, settings, options)`

One record in, one scene out. Or nil and a reason.

Returns nil when nothing scores, and that refusal is the point. A default world would mean some unknown share of the output is a generic landscape with no relationship to its character -- and every one of those pictures would look perfectly fine, so nobody would ever find them. It is the most dangerous fallback available in this project.

### `M.spread(store, settings)`

Which worlds the whole set lands in.

A distribution nobody looks at is a trigger list nobody knows is thin. If four thousand characters land in three worlds, the lists need widening, and that is invisible from any single character.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `component_box(record, component, measured)` | Where a piece of a character actually sits, as a box. |
| `box_place(box)` | A box, as a phrase about where it is in the frame. |
| `sound_halves(record)` | Which pieces are inside the half of the character chosen for its sound. |
| `main(argv)` |  |

## Where it sits

Used by `025-the-words-the-machine-reads`, `027-test-the-meaning`.
