# 503 — The case under the light

## Current behavior

Nothing frames a scene; the world runs to the picture's edges. A hall (`502`)
names exhibits but says nothing about the case they stand in.

## Intended behavior

**The case is words first, and only becomes drawn if the pictures show it has
to.** The owner's direction:

> if the design demands it. Trust the model, try to let it be as minimally guided
> as possible. Use the densest vocabulary possible to express the specified
> requirements, but let it express itself otherwise.

So:

1. **A few dense words per hall** for its display — *glass vitrine, spot-lit,
   dark gallery*; *tank glass, blue glow*; *open plinth*. Placed after the
   subjects, so the exhibits stay the point of the sentence. The model draws the
   case its own way.
2. **Nothing added to any mask or field.** In both routes of `416`, the case is
   part of the generated area. A drawn frame is a set of extra lines in a picture
   whose whole point is which lines are in it — a box around 口 is 回.
3. **A drawn frame only if the first real runs show the model leaving the case
   out, or putting its edges across the strokes.** Then a faint frame layer
   outside the character's bounding box, its weight a knob in
   `docs/balance-updates.md`, and the test that it never touches a stroke pixel.

**The label is still refused.** A case has a printed label; text and lettering
are among the four refusals no museum may lift (`412`).

## Suggested implementation steps

1. **A `case` field on each hall row** in `502` — a short phrase.
2. **`025` writes it** after the subjects.
3. **Look at the first runs** of `416` in a few halls; record in this issue
   whether the case appeared, and only then decide step 3 above.

## Related

`502` — the halls. `416` — the routes the case words travel through. `412` — the
refusals.
