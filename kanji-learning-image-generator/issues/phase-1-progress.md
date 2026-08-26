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
| `103` | The line the brush took | not started |
| `104` | A surface that holds grey | not started |
| `105` | A picture on the disk | not started |
| `106` | Numbers a machine will read | not started |

## Where the risk is

**`103`, in two specific places.** The smooth-curve command reflects a control
point that is not written down, and relative coordinates accumulate. Both produce
output that is right for most characters and subtly wrong for some, which is the
worst failure shape available — it does not announce itself, and the characters
it ruins are ruined in a way that looks like bad drawing rather than bad
arithmetic. The test that every point lands inside the archive's own box is what
catches it.

**`105`, in the compressor.** A wrong Huffman code produces a file of plausible
length that some decoders open. Round-tripping is the only test that finds it.

Everything else here is ordinary work.

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
