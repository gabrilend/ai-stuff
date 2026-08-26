# 1003 — Six faces agreeing what cycle it is

Produces `src/072-cross-face-synchronisation.md`.

## Current behavior

Nothing. `1002` declares the faces mesochronous and points here for why that is
enough.

## Intended behavior

**What the six faces actually have to agree about, which is much less than a
common clock edge**, and the mechanism that delivers it.

### The claim

Faces need to agree about **order**, not about time. `506`'s contract is the whole
of what one face may assume about another, and it is expressed in releases and
acquires through memory — not in cycles, not in edges, and not in any shared
notion of *now*.

So a domain crossing at each face's radial interface, plus `506`'s barriers, is
sufficient. Nothing in the machine ever asks "what is face three doing this
cycle?"

The blueprint's job is to establish that rigorously, by **enumerating every place
two faces interact** and showing each is covered:

- the six staging buffers, covered by the barriers
- the request region, covered the same way
- the pane, covered by `506`'s exclusion rule
- `504`'s arbitration, which is inside one clock domain and not a crossing at all
- `1107`'s reverse staging buffers, when training

Five sites. If the enumeration is complete, mesochronous is enough and a great
deal of power is saved.

### The crossing itself

Each face's link to the cage crosses from the face's clock to the cage's. Standard
apparatus — a synchroniser with a stated mean time between failures, or an
asynchronous queue — and the blueprint must state which and derive the failure
rate rather than assuming it is negligible. **At thirty-nine terabytes a second
crossing six times, "negligible" is a number, and it should be compared against
`1206`'s target beside `507`'s soft error rate.**

### What still needs a common time

Two things, and both are slow:

**Bring-up.** `1004` has to get all six faces into a known state together. Once.
**Telemetry.** `609`'s counters are more useful if they can be compared across
faces, which needs a shared timebase — but at microsecond resolution, not
picosecond.

A slow, free-running counter distributed from the auxiliary domain serves both,
and costs almost nothing. The blueprint should specify it and say plainly that it
is not a clock, so nobody tries to build timing paths on it.

## Symbols this must publish

The enumeration of interaction sites. Synchroniser type, depth and mean time
between failures. Crossing latency, which lands in `704`'s stage budget. Timebase
counter width and resolution. Timebase distribution path.

## Constraints this must assert

- The interaction site enumeration is complete, checked against `506`'s list.
  **Two blueprints, one list**, and a site added to one without the other is
  exactly the kind of hole that produces intermittent wrong answers.
- Synchroniser mean time between failures exceeds `1206`'s target with margin,
  at the actual crossing rate.
- Crossing latency is inside `704`'s per-stage allowance.
- Timebase resolution is coarse enough that nobody can mistake it for a clock, and
  fine enough for `609`'s comparisons.

## Suggested implementation steps

1. Enumerate the sites and show the barriers cover them.
2. Specify the crossing and derive its failure rate against the real rate.
3. Add the slow timebase and label it clearly as not a clock.

## Blocks

`1004`, `1005`, `609`.

## Blocked by

`506`, `1002`, `1107`.

## Related documents

`003` for the handoff this makes safe.
