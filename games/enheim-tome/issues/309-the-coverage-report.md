# 309 — The Coverage Report

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 208, 301 |
| Blocks | — |
| Reads | [the tracing mode](../docs/005-the-tracing-mode.md) |
| Open questions | — *(was question 9; answered)* |

## Current behavior

The size of the remaining work is unknown and can only be guessed.

## Intended behavior

A report of how far the campaign has got. **It is the only honest measure**, and
every figure in the documents about scale is an estimate from three sample crops
waiting to be replaced by it.

### It does not measure coverage

Coverage is **always one hundred percent**. The city is subdivided rather than
filled in, so there is never any undefined ground — see
[the fence network](../docs/004-the-fence-network.md).

What it measures instead is **how finely the city is divided and how well it is
named**, which is a different question and the one that actually matters.

### What it reports

| | |
| --- | --- |
| places | how many regions the graph cuts the painting into |
| named | and how many of those have a name |
| the coarsest places remaining | the largest regions still undivided — where the work obviously is |
| buildings placed | and how many places have none yet |
| houses listed | |
| intersections named | out of junctions that exist |
| membership | places with no district; districts with no quadrant |
| natural character stated | per place, and how many still have none |
| **what remains** | all of the above as work left rather than work done |

That last line is the point. "1,840 places named" is a number; "roughly 160 left,
about a week at this rate" is a reason to sit down.

**The coarsest-remaining list replaces what used to be a map of untraced ground.**
Since everything is always covered, the way to see where the work is is to ask
which regions are still enormous.

### Rates, not just totals

If it can see when things were added, it can say how fast the campaign is moving
and therefore when it would finish. That converts a two-thousand-item backlog
from a wall into a schedule, which over a year of evenings is the difference
between continuing and stopping.

### It replaces the estimates in the documents

The scale table in
[the places of the city](../docs/003-the-places-of-the-city.md) is explicitly
marked as estimates to be replaced by this tool's output. **Documents reference
this rather than restating numbers**, so a page cannot go stale while looking
authoritative.

### Where it lives

**The tracing mode only.**

How finely the city has been divided is a fact about the project, not about the
world. A player should meet a city, not a completion figure — and since coverage
is always complete, there is nothing a player could even be told that would not
be an artefact of the authoring.

## Suggested implementation steps

1. Walk the network and count everything in the table above.
2. Sort places by area to produce the coarsest-remaining list.
3. Print as text, and exit non-zero if asked to enforce a threshold, so it can sit
   in a test run.
4. Record a dated line per run into `tmp/shared-memory/`, so rate can be computed
   from history without adding timestamps to the network itself.
5. Have it runnable standalone from a script as well as from inside the mode —
   checking progress should not require entering the editor.

## Related documents and tools

- [The tracing mode](../docs/005-the-tracing-mode.md)
- [The places of the city](../docs/003-the-places-of-the-city.md)
