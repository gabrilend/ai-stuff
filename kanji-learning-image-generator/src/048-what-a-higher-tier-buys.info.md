# 048-what-a-higher-tier-buys — info

A picture somebody liked earns an animation of itself being written.

For a general: the tier is not only a filter deciding which pictures get used. It is also a budget deciding how much more work each one deserves. Effort concentrates where quality already is, and the library gets *deeper* rather than merely wider.

What it buys here is the thing this project has been claiming all along and never shown: the stroke order is the viewing order. One frame per stroke, the character being written over the picture that hides it. It is the most useful thing a study tool can own, and it is expensive enough to be worth reserving for pictures somebody has already said were good.

ELABORATION EXTENDS, NEVER REGENERATES. Same picture, same seed, one thing differing -- here, how many strokes have been drawn. If it re-rolled, what came back would be a different picture wearing the old one's tier, and after a few rounds every tier in the pool would be a statement about something that no longer exists.

The encoder is ours, as the still-picture one is. This format has not moved since 1989, it is a few hundred lines, and its compression is a cousin of the one already written for PNG. A borrowed encoder turns our mistakes into somebody else's silence.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `048-what-a-higher-tier-buys.lua` and
run the sweep again.*

## Invocation

```
luajit src/048-what-a-higher-tier-buys.lua --owed
luajit src/048-what-a-higher-tier-buys.lua --do-the-work
```

## What it offers

| | |
|---|---|
| `M.palette(settings)` | The 256 colours a frame may use, as bytes. |
| `M.index_of(grey, arrow_alpha, arrow_colour)` | Which palette entry one pixel is, exactly. |
| `M.encode(frames, width, height, palette, hundredths)` | A whole animation, as the bytes of a file. |
| `M.frames_for(record, settings, background)` | One frame per stroke, each showing one more of them arrowed. |
| `M.animate(settings, entry, store)` | The animation one rendering earned, written beside it. |
| `M.owed(settings)` | Which pictures deserve work they have not had. |

### `M.encode(frames, width, height, palette, hundredths)`

A whole animation, as the bytes of a file.

frames is a list of index arrays, one entry per pixel.

### `M.frames_for(record, settings, background)`

One frame per stroke, each showing one more of them arrowed.

The background is the finished picture -- or, before there is one, the field that will produce it, which is the same shape and the same size and is what makes this buildable and testable before any picture has ever been generated.

### `M.owed(settings)`

Which pictures deserve work they have not had.

PROMOTION CREATES WORK. Moving a picture up means it now deserves an animation it does not have, so the rating system is the generator's task queue and not only its curator. Demotion never destroys: it stops further investment and leaves what was already made where it is.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `lzw(indices, count)` | The compression this format uses, which is not the one PNG uses. |
| `emit(code, width)` |  |
| `blocks(text)` | The data, cut into the short runs this format wants. |
| `two_bytes(value)` |  |
| `main(argv)` |  |

## Where it sits

Used by `035-test-the-machine`.
