# 905 -- The machine grader is a heuristic, and says so

**Phase:** 9, the sprite studio
**Blocked by:** [904](904-two-ways-of-rating.md)
**Blocks:** [907](907-the-anchor-that-stops-drift.md)
**Documents:** [the sprite studio](../../docs/017-the-sprite-studio.md)

## Current behaviour

**Done.** The grader exists, it is called a heuristic everywhere, and it is now
measured rather than trusted.

`sprite_machine_tier` weighs five components — layer count, whether it moves,
palette coherence, how much of the box it fills, and how balanced the detail is —
over a hundred points, and maps that onto five tiers.
`sprite_machine_reasoning` prints the breakdown so a demo can show which
component made the call rather than announcing a number.

It watches. The motion is a field of the sprite and a declaration in the file, so
reading it is reading the animation rather than one still frame — achievable
because the format is SVG and not achievable for a raster format.

**The thresholds were measured, not chosen**, and that took a second pass. The
first four were round numbers that looked reasonable; against real output they
left tier one empty and put ninety per cent into two tiers. So `084-calibrate`
was written — a program, not a script, because the numbers are frozen and the
distribution is not. It exits non-zero when the tiers go adrift, and it has
already caught one drift: making detail layers mirrored moved every line by two
points.

**And the agreement rate is reported wherever a tier is shown.** `studio_summarise`
prints the tier table, the provenance counts, a sentence saying plainly that the
machine's tiers are a heuristic and roughly what it measures, the agreement rate,
and the human-rated fraction against its anchor. Every time, not in a footnote.

A pool with no pairs reports UNMEASURABLE and never a percentage. A pool with a
handful reports THIN. Both have tests, because a rate computed from nothing that
reads as agreement is the single most dangerous number this project could print.

## Intended behaviour

A scorer that looks at a sprite and gives it a tier — and **is honest about what
it is.**

### What it actually is

A handful of measurable properties, weighted: how many layers, whether the
palette is coherent, whether it animates at all, whether it fills its viewbox,
whether it is symmetric where its category expects symmetry.

**That is not taste.** It is a proxy for taste, and a crude one.

### Saying so is the important part

The document describing this project's studio talks about a machine grader as
though it were judging quality. It is not, and writing as though it were would be
the worst kind of dishonesty here — because the whole apparatus is built to
measure how far the machine's taste has drifted from a person's, and a grader
that is really a complexity metric will drift in a direction nobody predicted.

So: it is called a heuristic in the code, in the companion file, and in the demo.
When something better is available it replaces this, and the interface is built so
that is a substitution.

### It must be able to watch

A grader shown one still frame of a walk cycle is grading an illustration. Since
the artifact is SVG and the animation is declared in the file, "watching" means
reading the animation declarations rather than only the static shapes — which is
achievable here, and would not be for a raster format.

**A blind grader on a motion project grades nothing.**

### And it is measured, not trusted

Algorithm A produces the agreement rate for free. If agreement falls, the grader
has drifted and its ratings are suspect until re-anchored. That number is
reported where it can be seen rather than computed and filed.

## Suggested implementation steps

1. Write the scorer over the sprite description and the encoded SVG.
2. Map the score onto the five tiers, and write down the thresholds.
3. Name it a heuristic everywhere it appears.
4. Report the agreement rate wherever a tier is shown.
5. Test that it is deterministic, and that it does not give everything the same
   tier — a grader whose output has no spread is a constant wearing a function's
   clothes.
