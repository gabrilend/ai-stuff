# 201 — What a stroke is shaped like

## Current behavior

Done. `src/021-the-shape-of-a-stroke.lua` measures a stroke, and the report that
step 4 asked for is a mode of that same file rather than a throwaway:

```
luajit src/021-the-shape-of-a-stroke.lua --calibrate
```

**Every boundary in the file was set from that report rather than guessed**, and
the report is kept because the numbers are claims about a dataset that gets new
releases. Three things came out differently from the plan.

**Hooks are measured, not read.** The plan said geometry could not see a hook,
because a hook barely moves a stroke's endpoint. True, and the conclusion was
wrong: a hook barely moves the endpoint and swings the *direction* hard, and
direction is the easiest thing here to measure. The classes the archive labels
as hooked average a terminal turn above seventy-five degrees; the rest stay
under twenty-six, with nothing in between. The measurement agrees with the label
wherever there is one, and unlike the label it also covers the strokes the
archive left unlabelled or marked ambiguous.

**Size is measured apart from direction**, which the plan folded together. A dot
and a long sweeping stroke travel in the same direction and are not the same
thing; bucketing by angle alone would have put a bird and a river in the same
place. There is now a size — dot, short, long — beside the direction.

**A sixth direction had to be named: reversing**, for a stroke that ends left of
or above where it began. There are eight in the whole archive. Naming it rather
than folding it into a neighbour means a scene asking for an object to lie along
one is told something unusual is there.

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

**Hookedness is how far the stroke swings in its last fifth.** A hooked vertical
and a plain vertical are different strokes to a reader and want different objects
laid along them, so the distinction has to survive. It is measured rather than
read out of `kvg:type`, and `--calibrate` is what settled that: the two
populations do not overlap, and measurement also covers the strokes the archive
labelled ambiguously or not at all.

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
