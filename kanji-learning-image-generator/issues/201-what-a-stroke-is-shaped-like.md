# 201 — What a stroke is shaped like

## Current behavior

A stroke is a run of points. Points do not say what a stroke *is*.

## Intended behavior

**One measurement function, returning the handful of numbers that decide both
what a stroke looks like in the field and what object gets laid along it.**

The measurements are tabulated in `docs/004`. What matters here is where each
one comes from and which are untrustworthy.

**Direction** is the angle of the line from the first point to the last, bucketed
into the five classes calligraphy already uses — horizontal, vertical,
falling-left, falling-right, rising. The buckets are not equal in size, because
the classes are not equally common or equally wide: a stroke a few degrees off
horizontal is still a horizontal stroke, and Japanese horizontals are written with
a deliberate slight rise, so the horizontal bucket has to be generous on one side
and is asymmetric by design.

**Length** is end-to-end distance as a fraction of the canvas. **Travel** is arc
length. Their ratio is curvature, and it is the cheapest description of shape
there is: a ratio near one is a straight stroke, and well above one is a bend.

**Hookedness comes from the calligraphic class, not from geometry**, and this is
the one place where the archive knows something measurement cannot. A hook is a
short flick at the end of a stroke. It barely moves the endpoint, it barely
changes the arc length, and it is invisible to every statistic above — but a
hooked vertical and a plain vertical are different strokes to a reader and want
different objects laid along them. `kvg:type` states it (`docs/002`), so it is
read rather than inferred, and a stroke with no class recorded is reported as
unmeasurable in that one respect rather than assumed straight.

**Place** is which ninth of the frame the stroke's midpoint falls in. Coarse on
purpose: the scene grammar wants *low and to the left*, not coordinates, and a
finer grid would produce distinctions the prompt cannot express anyway.

**Weight** is this stroke's share of the character's total arc length. It is what
`docs/004` sorts by when deciding which strokes are structural enough to name in
the prompt, and it is a better answer than raw length because a long curling
stroke occupies more of the composition than a straight one of the same span.

## Suggested implementation steps

1. **`src/021-the-shape-of-a-stroke.lua`**, measuring one flattened stroke and
   returning one table. It takes the calligraphic class as an argument rather than
   reaching for the record, so it can be tested on a shape somebody made up.

2. **The direction buckets are a table, not a chain of comparisons** — a list of
   ranges with a name each, scanned in order. Adding a class later is adding a row.

3. **Test against characters whose answers are known by construction.** 一 is one
   horizontal. 川 is three verticals. 人 is one falling-left and one falling-right.
   十 is one horizontal and one vertical. If those four do not come out right the
   buckets are wrong, and they are four assertions that need no judgement.

4. **Print the distribution over the whole archive.** Every stroke in KanjiVG,
   measured, counted by class, next to the count of what `kvg:type` says it is.
   Where geometry and the archive disagree systematically, the buckets are wrong;
   where they disagree on scattered individual strokes, the archive is describing
   something geometry cannot see, which is the expected and interesting case.

## Related

`docs/004` — the table of measurements and what consumes them. `103` — the runs
of points this measures.
