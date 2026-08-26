# 103 — The line the brush took

## Current behavior

Done. `src/014-the-path-language.lua` reads the six instructions the archive
uses, `src/015-flatten-the-curves.lua` chops the curves into short lines and
measures them, and `src/020-test-the-ink.lua` runs both over every stroke of
every character in the joined set.

The sweep passes with nothing broken, nothing degenerate, and nothing outside
the archive's own box. Run it for the current counts.

The archive was surveyed before the parser was written rather than after, and
it settled three things the plan had left as guesses: no path contains more
than one subpath, no path uses exponent notation, and the only instructions
present are the move and the cubic curve — in both cases and in both spellings.
A hundred and thirty-five paths begin with a *relative* move, which the format
defines as absolute anyway; it makes no numerical difference, because the brush
starts at the origin and adding to zero is the same as replacing it.

## Intended behavior

**A stroke becomes a run of short straight lines with known lengths and
directions**, which is the form both the canvas and the stroke measurement need.

Two files, because they are two different problems. One reads a small language.
The other does geometry.

**The path language.** KanjiVG uses exactly six commands — `M m C c S s` — and no
others. That is worth stating as a fact rather than writing a general SVG parser:
there are no arcs, no quadratics, no closepaths and no line commands in this
archive, and a parser that accepts them would be accepting things that will never
arrive and would hide the day one did. An unknown command is an error naming the
character it came from.

The parser must get two things right that a careless one gets wrong:

- **`S`/`s` is smooth-continuation.** Its first control point is not written down;
  it is the reflection of the previous curve's second control point through the
  current position. Get it wrong and the character comes out with kinks at every
  smooth joint. Where a smooth curve follows something that was not a curve, the
  reflected point is the current point itself.
- **Numbers run together without separators.** `c2.45,0.57,5.23,0.8` is
  comfortable, but `-1.5-2.3` is two numbers and `.5.5` is also two numbers. The
  number scanner has to end a number at a minus sign that is not an exponent and
  at a second decimal point.

**The flattening.** Cubic curves become polylines by subdivision that stops when
the curve is flat enough to be a line at the resolution being drawn — flatness
measured as how far the control points sit off the chord. Uniform subdivision
either wastes points on straight sections or corners on tight ones, and kanji
strokes have both in the same stroke.

What comes out is not only points. `docs/004` needs to measure strokes and
`docs/003` needs to taper them, so the flattener also returns cumulative arc
length, the tangent at each point, and the straight-line distance from first
point to last. Arc length divided by that distance is how curved the stroke is,
and it is the cheapest useful description of a stroke's shape.

## Suggested implementation steps

1. **`src/014-the-path-language.lua`** — tokenise and parse into a segment list.
   Every segment is absolute by the time it leaves, so nothing downstream needs to
   know that lowercase means relative.

2. **`src/015-flatten-the-curves.lua`** — de Casteljau subdivision with a flatness
   test, plus the measurements above.

3. **Test against the archive itself, not against invented paths.** Every path in
   KanjiVG is parsed and flattened, and the check is that nothing errored, every
   stroke produced at least two points, and every point landed inside the
   109-by-109 box the archive draws in. A stroke outside the box means the
   reflection rule or the relative-coordinate accumulation is wrong, and it is the
   one bug in this area that produces plausible output for most characters.

## Related

`docs/002` — where the `d` strings come from. `104` — what consumes the runs.
