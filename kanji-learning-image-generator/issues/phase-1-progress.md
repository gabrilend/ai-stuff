# Phase 1 — The Ink

**Goal.** Two large XML files become a shape that can be drawn, and there is
somewhere to draw it. Nothing in this phase knows what a kanji means.

This is the least surprising third of the project and everything else stands on
it. It ends with a machine that can put any character's strokes onto a surface
and write that surface to disk, having no opinion at all about what the character
is for.

## Issues

| | | Status |
|---|---|---|
| `101` | The two archives | **completed** — both archives fetched, provenance recorded, settings and the two rituals in place |
| `102` | Reading a shape out of XML | **completed** — both archives read, joined, cached, and every leftover accounted for |
| `103` | The line the brush took | **completed** — every stroke in the archive parses, flattens, and lands inside the box |
| `104` | A surface that holds grey | **completed** — brush, blur, band, and a clipping bug the tests found |
| `105` | A picture on the disk | **completed** — a real compressor, checked by decompressing what it wrote |
| `106` | Numbers a machine will read | **completed** — ordered keys, and the three quiet failures tested for |

## Where the risk is

**`103`, in two specific places.** The smooth-curve command reflects a control
point that is not written down, and relative coordinates accumulate. Both produce
output that is right for most characters and subtly wrong for some, which is the
worst failure shape available — it does not announce itself, and the characters
it ruins are ruined in a way that looks like bad drawing rather than bad
arithmetic. The test that every point lands inside the archive's own box is what
catches it.

**`105`, in the compressor.** A wrong code produces a file of plausible length
that some decoders open. Round-tripping is the only test that finds it, and the
reader that does the round trip is written in the test from the format
description rather than borrowed from the writer -- a round trip through one
misunderstanding twice proves nothing.

Everything else here is ordinary work.

## What `104` turned up

**The risk was not where this file said it was.** Everything above worried about
the compressor and the path arithmetic. The bug that mattered was in a bounding
box: the rectangle of pixels a brush stroke could possibly touch was sized from
the brush width at the ends of each segment.

That is wrong exactly when a stroke flattens to a single segment, which is
exactly when a stroke is straight -- and then both of its ends are at the
tapered tips while its middle is at full width. So the box clipped the middle of
every straight stroke, and clipped it asymmetrically, because rounding down at
the top and up at the bottom take different amounts. Every horizontal and every
vertical in the archive came out thin and lopsided. Every curve was perfect.

Nothing downstream could have reported this. The characters looked like the
characters, in a slightly worse hand.

## What `101` turned up

Two assumptions that were wrong in the same way — both were about checking a
thing by looking at the part of it that is easiest to look at.

A download was to be verified by reading the start of the file. Downloads fail
at the end. And the project root was to be verified by comparing two paths as
strings, on a machine where one directory has two absolute paths. Both checks
were cheap, both were plausible, and both would have reported success on exactly
the failure they existed to catch.

## What `102` turned up

**The report earned its keep before anything used it.** The plan justified
counting the join's leftovers on the general principle that a set which shrinks
quietly is a set nobody notices has shrunk. The first run printed the list and
it began with an exclamation mark, a comma, and the digits — the stroke archive
draws the Latin alphabet and both syllabaries, which no kanji dictionary lists.
The alarming number was three ordinary numbers stacked together.

**And then two checks in a row were wrong about the world.** Nine characters
remained that plainly had English meanings — "cold", "territory" — and did not
join. They are compatibility characters: a second Unicode number for the same
character, so old Korean text survives a round trip. Establishing which ordinary
character each pairs with was attempted twice and refuted twice, once by
comparing the drawings and once by reading the archive's own label. The pairing
is not in either archive. It is now stated as a limitation instead of a fact,
which is the only outcome of the three that would have survived contact with a
reader who knew Unicode.
