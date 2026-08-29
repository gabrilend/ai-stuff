# 309 — The Coverage Report

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 208, 301 |
| Blocks | — |
| Reads | [the tracing tool](../docs/005-the-tracing-tool.md) |
| Open questions | **9** — whether the game ever shows this too |

## Current behavior

The size of the remaining work is unknown and can only be guessed.

## Intended behavior

A report of how far the campaign has got. **It is the only honest measure**, and
every figure in the documents about scale is an estimate from three sample crops
waiting to be replaced by it.

### What it reports

| | |
| --- | --- |
| blocks traced | and how many are unnamed |
| buildings placed | and how many blocks have none yet |
| houses listed | |
| intersections named | out of junctions that exist |
| membership | blocks with no district; districts with no quadrant |
| events written | per block, and per house — see [805](805-one-event-per-block.md) |
| fraction of the painting fenced | area inside any block, over the whole image |
| **what remains** | the above, expressed as work left rather than work done |

That last line is the point. "1,840 blocks traced" is a number; "roughly 160
blocks left, about a week at the current rate" is a reason to sit down.

### Rates, not just totals

If it can see when things were added, it can say how fast the campaign is moving
and therefore when it would finish. That converts a two-thousand-item backlog
from a wall into a schedule, which over a year of evenings is the difference
between continuing and stopping.

### It replaces the estimates in the documents

The scale table in
[the places of the city](../docs/003-the-places-of-the-city.md) is explicitly
marked as estimates to be replaced by this tool's output. **Documents should
reference this rather than restating numbers**, so that a page cannot go stale
while looking authoritative.

### Where it lives

**Working ruling:** the tracing tool only.

If the game showed it, *how much of the city has been defined* would become
something the player sees — which for a game about coming to know a city might be
a feature rather than a leak. Undecided; see open question 9.

## Suggested implementation steps

1. Walk the network and count everything in the table above.
2. Compute fenced area from the block polygons, against the painting's total.
3. Print as text, and exit non-zero if asked to enforce a threshold, so it can sit
   in a test run.
4. Record a dated line per run into `tmp/shared-memory/`, so rate can be computed
   from history without adding timestamps to the network itself.
5. Have it runnable standalone from a script as well as from inside the tool —
   checking progress should not require opening the editor.

## Related documents and tools

- [The tracing tool](../docs/005-the-tracing-tool.md)
- [Open questions](../docs/012-open-questions.md) — question 9
