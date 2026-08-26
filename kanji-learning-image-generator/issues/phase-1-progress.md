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
| `102` | Reading a shape out of XML | not started |
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
