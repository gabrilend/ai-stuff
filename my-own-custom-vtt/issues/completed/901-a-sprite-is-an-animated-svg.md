# 901 -- A sprite is an animated SVG

**Phase:** 9, the sprite studio
**Blocked by:** phase 8 complete.
**Blocks:** everything else in phase 9.
**Documents:** [the sprite studio](../../docs/017-the-sprite-studio.md)

## Current behaviour

**Done.** `082-sprite` makes one, writes it as an animated SVG, and reads it back
with a reader that shares no code with the writer.

The reader recovers each field from the drawing rather than from a restatement of
the struct: the shape from the element, the palette slot by matching the fill
against the palette, the offsets and radii by running the geometry backwards, and
the motion from what the animation actually does — translate along y is a bob,
along x is a walk. Nothing in the file says "this layer uses the accent", so a
writer that put the wrong colour on a layer is caught rather than agreed with.

The round-trip test runs three thousand sprites across six categories and compares
every field of every layer. Two outside tools open the output: `xmllint` calls it
well-formed and ImageMagick rasterises it, for all five motions.

One thing the format forced back onto the generator: the two lowest bits of the
blue channel carry the palette slot number, so that no two slots can ever hold the
same colour. Without it the fill-to-slot match would be ambiguous on some seeds
and not others.

Still is written as the absence of an animation element and read back as the
absence of one — the one case where the file says something by not saying
anything, and it has its own test.

## Intended behaviour

One self-contained **animated SVG** per sprite. Four things follow, each
load-bearing:

**It is not a .png**, which is the requirement from the vision stated as a file
format.

**It is watchable as it stands.** Open it and the goblin walks. That matters more
than it sounds: a rater shown a still frame of an animation is rating an
illustration, and a project about motion cannot be judged by somebody blind to
motion.

**It is text**, so it diffs, and the encoder is string-writing rather than a
compression format. Nothing is borrowed to produce it.

**The renderer can use it directly** — scale, tint, recolour a layer, compose —
because vector parts survive being transformed and a raster sprite does not.

### The encoder is ours

Writing SVG is writing strings. A borrowed encoder would be a dependency to
install on every machine, for a format that is text.

More importantly: a borrowed encoder converts your errors into somebody else's
silence. Ours gives a loud failure in code we can read.

### The round trip is not negotiable

Write an independent reader, in the test, that parses back what was written and
compares. Where an outside tool can open the output, run that too.

**Two independent readers is proof; one is an opinion.**

### The same description gives byte-identical output

Seeded from the description itself. That is what lets a test assert on bytes
instead of on somebody squinting, and what makes every rating in the pool
reproducible rather than a memory.

## Suggested implementation steps

1. Define the sprite description: layers, palette slots, animation states,
   anchor points.
2. Write the encoder: a document, a viewbox, one group per layer, and SMIL
   animation for the states.
3. Make it deterministic — no clock, no ambient randomness.
4. Write the round-trip test.
5. Write the companion `.info.md`.
