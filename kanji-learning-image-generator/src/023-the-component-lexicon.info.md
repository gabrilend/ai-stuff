# 023-the-component-lexicon — info

A piece of a character in, a thing that can be drawn out.

For a general: the stroke archive states what each character is built from. The character for "rest" contains a person and a tree, and that is not our invention -- it is the character's etymology, written down by people who catalogued it. So the picture can be a traveller leaning on a trunk, and nothing had to be made up.

Turning "contains 木" into "there is a cedar in this picture" needs a dictionary of pieces. Most of that dictionary is not written here: a piece is usually a character in its own right, and the meaning archive already glosses it. What is written here is only what derivation cannot reach.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `023-the-component-lexicon.lua` and
run the sweep again.*

## Invocation

```
luajit src/023-the-component-lexicon.lua --coverage
```

## What it offers

| | |
|---|---|
| `M.name_from(phrase)` | The short name inside a describing phrase. |
| `M.is_paintable(gloss)` | Whether a gloss names something that could be in a picture. |
| `M.written_count()` |  |
| `M.look_up(component, store)` | One component, as something that can be in a picture. |
| `M.coverage(store)` | How much of the archive this lexicon can actually picture, and what it cannot. |

### `M.name_from(phrase)`

The short name inside a describing phrase.

Strips the article, then cuts at the first place the phrase stops naming the thing and starts saying more about it.

### `M.look_up(component, store)`

One component, as something that can be in a picture.

Returns nil when nothing can be found, which is a real answer -- `docs/004` turns those strokes into structure rather than into a subject, and `303` counts them so the commonest one is the next row somebody writes here.

The order is: what is written here, then the piece's own dictionary entry, then the entry for the character the piece is a squeezed form of. The last of those is why 亻 works without a row: the archive says it is a compressed 人, and 人 is glossed "person".

### `M.coverage(store)`

How much of the archive this lexicon can actually picture, and what it cannot.

Counted by appearance rather than by distinct piece, because a component in two thousand characters matters two thousand times more than one in a single rare character -- and the frequency ordering of the failures is the queue for what to write next.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `024-the-scene-grammar`, `027-test-the-meaning`.
