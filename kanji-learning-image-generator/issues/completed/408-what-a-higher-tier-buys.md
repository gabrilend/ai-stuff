# 408 — What a higher tier buys

## Current behavior

Done. `src/048-what-a-higher-tier-buys.lua`, including the GIF encoder.

```
luajit src/048-what-a-higher-tier-buys.lua --owed
luajit src/048-what-a-higher-tier-buys.lua --do-the-work
```

**No quantiser was needed and that is worth saying**, because writing one is the
obvious next step and it is a whole apparatus plus a source of banding. These
frames are made of exactly two things — a grey picture, and arrows in one colour
over it — so the palette is built to be exactly those two things and each pixel
is placed in it directly. No nearest-colour search, and no error at all.

**Each frame draws its arrows afresh rather than revealing them.** The arrow
layer decides where each arrow goes by what is already placed, so drawing six
and keeping the first three is a different picture from drawing three. The
second is the honest one.

**A phrase is not animated yet** and says so rather than doing it badly: a
phrase's record is built rather than read from the store, and nothing here
rebuilds one from a companion.

The compressor is checked by decoding what it wrote, with a reader written in
the test from the format description — the only test that catches a compressor
which grows its code width one entry late, which writes a file that decodes
correctly for a while and then falls apart. It decides which renderings get shown and nothing else, so the
effort spent on a good one and a bad one is identical.

## Intended behavior

**A rendering somebody liked earns a stroke-order animation.**

One frame per stroke, the character being written over the picture that hides
it. It is the most useful thing a study tool can own — the whole argument of
this project is that the writing order is the viewing order, and an animation is
that claim shown rather than described. It is also expensive enough to be worth
reserving for pictures somebody already said were good.

Effort concentrates where quality already is, and the library grows **deeper**
rather than merely wider.

**The encoder is ours**, as the picture encoder already is. GIF89a has not moved
since 1989, it is a few hundred lines, and its compression is the same family of
trick as the one already written for PNG. A borrowed encoder converts our errors
into somebody else's silence, and the round trip that proves it works is written
in the test as an independent reader — the only test that catches a compressor
which is confidently wrong.

**Elaboration extends, never regenerates.** Same description, same seed, one
parameter differing. If elaboration re-rolled, what came back would be a
different picture wearing the old one's tier, and after a few rounds every tier
in the pool would be a statement about something that no longer exists. This is
where the determinism from `302` pays off a second time.

**Promotion creates work.** Moving a rendering from 3 to 5 means it now deserves
an animation it does not have, so a re-rate emits a work order. The queue of
outstanding elaboration can be counted and worked through, which makes the
rating system the generator's task queue rather than only its curator.

**Demotion never destroys.** It stops further investment. What was already made
stays in the pool at its new tier.

## Suggested implementation steps

1. **The animation needs no diffusion model.** Every frame is the rendering with
   the first *n* strokes' arrows over it, and both halves already exist. It can
   therefore be built and tested before `404` has ever produced a rendering, by
   standing in the structure field where the rendering will go.

2. **The frame delay is in hundredths of a second** because that is what the
   format honestly represents. Anything finer is drift dressed as precision, and
   the wall should refuse it rather than round it.

3. **The work order is a file in the pool**, beside the thing that needs the
   work, because that is where everything else about a rendering already lives.

4. **Test the encoder by decoding it**, in the test file, and by opening it with
   an outside tool where the machine has one. Two independent readers is proof;
   one is an opinion.

## Related

`docs/042` — the shape. `406` — what promotes. `026` — the arrows it animates.
