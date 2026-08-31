# 068-bitmap-font — info

A font, as pictures. Each character is eight rows of eight, drawn with dots and hashes, and turned into bytes at load time. Issue 202 needs one: text output is a loop that copies these bits into a framebuffer, and there is nothing else to it.

A computer with no operating system has no idea what a letter looks like. This is where the shapes of the letters live -- small enough to carry on the chip, and drawn in the source so a person can read them without running anything.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `068-bitmap-font.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/068-bitmap-font.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.WIDTH, M.HEIGHT` |  |
| `M.PICTURES` | the glyphs, drawn |
| `M.rows_of_picture(picture, called)` | Any picture as eight bytes, high bit leftmost. |
| `M.rows(character)` | One glyph as eight bytes. Nil for a character with no picture -- the caller decides whether that is a refusal or a box, and both callers here do de... |
| `M.table_bytes(order)` | The whole font as a flat run of bytes, in the order given -- what a payload carries, and what the drawing code indexes into. |
| `M.MISSING` | what stands in for a character with no picture |
| `M.FIRST, M.LAST` | the range a carried table covers |
| `M.contiguous_table()` | Every code from FIRST to LAST, in order, with the box where no picture exists -- so a payload finds a glyph by subtracting rather than searching. |
| `M.printable()` | Every character the font actually has a picture for, in byte order. |
| `M.show(character)` | A glyph printed back as a picture, from its bytes rather than its source. |

### In more detail

**`M.rows_of_picture(picture, called)`**

Any picture as eight bytes, high bit leftmost. `called` names it in a
refusal, since a picture on its own has nothing to be called.

**`M.rows(character)`**

One glyph as eight bytes. Nil for a character with no picture -- the
caller decides whether that is a refusal or a box, and both callers here
do decide, rather than a blank being substituted quietly.

**`M.table_bytes(order)`**

The whole font as a flat run of bytes, in the order given -- what a
payload carries, and what the drawing code indexes into.

`order` is a list of the characters, and their positions in it are what
the drawing code looks up. Anything not in the font is refused here rather
than at drawing time, so a payload cannot be built carrying a hole.

**`M.MISSING`**

A hollow box, and deliberately not a blank. A blank says the machine
printed a space; a box says it met something it has no shape for, which is
a different fact and the one worth seeing.

**`M.contiguous_table()`**

Every code from FIRST to LAST, in order, with the box where no picture
exists -- so a payload finds a glyph by subtracting rather than searching.

CONTIGUOUS IS THE WHOLE POINT. A table holding only the characters that
happen to be drawn is dense, small, and wrong to index by subtraction: the
gaps shift every later letter. That produced a screen of real letterforms
spelling something else entirely, which is this file's own failure mode --
no error, just a plausible wrong answer -- arriving from the one direction
the pictures could not prevent.

**`M.printable()`**

Every character the font actually has a picture for, in byte order. For
listing and checking; NOT for indexing -- see contiguous_table above.

**`M.show(character)`**

A glyph printed back as a picture, from its bytes rather than its source.
The check that the derivation is right, and the reason the pictures can be
trusted: what this prints is what a framebuffer will show.

## Why pictures rather than hex

The same reason the exponential's constants are computed rather than transcribed (043): a wrong hex byte in a font is a letter that looks slightly odd forever and nobody suspects the right thing. A wrong hash in a picture is visible while typing it. The bytes are derived from the pictures at load, so there is no opportunity to transcribe.

## What is missing is refused, not guessed

A character with no glyph makes the drawing refuse rather than print a blank -- a blank is a lie that says the machine printed something it could not.

## Where it sits

**Belongs to** `202`.

**Checked by** `070-test-say`.

