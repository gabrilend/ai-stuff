# 1005 — Does it close

Produces `src/074-timing-budget.md`.

## Current behavior

**Done.** `src/074-timing-budget.md` exists with both corners done and the reason
stated: a setup failure is a machine that will not run fast, a hold failure is a
machine that does not work at any speed, and hold gets worse at the corner the
setup check does not visit.

Six constraints. **`C-074-6` answers `070`'s question in the negative**: the core's
path does not fit a face cycle, so the two domains cannot be merged and `072`'s
crossing stays.

The coincidence worth naming is in `C-074-5`: `025`'s peak temperature is a hot
spot number, and the hot spot is inside `045`'s multiplier array, which is also
where the critical path is. **The hottest transistors are the slowest ones and
they are the ones that matter**, so the budget uses the local temperature and not
the die average.

**The clearest unresolved conflict in the project is now visible.** This blueprint
publishes what the thermal margin would buy in clock; `027` publishes what the
same margin would buy in removing a refrigeration plant. **Both stake a claim on
it and neither knows about the other's.**

**The logic delay is a `given`** from a cell `045` has not laid out, and
everything here rests on it.

## Intended behavior

**The critical path in each clock domain, itemised, with the margin left over** —
the blueprint that says whether the frequencies everything else assumes are real.

### The paths

| domain | expected critical path |
|---|---|
| face logic, 1.4 GHz | inside `605`'s multiplier-accumulator cell |
| core array, 1.2 GHz | `502`'s bitline, sense amplifier and output |
| radial link | `702`'s driver, bond, receiver, per-tile deskew |
| spout | `903`'s driver and `904`'s intra-tile skew |

For each: the logic delay, the wire delay, setup and hold, clock skew from `1002`,
jitter from `1001`, on-chip variation, and the margin remaining. **Every term
derived from the blueprint that owns it**, so that a change anywhere shows up here.

### The temperature and voltage corner

Timing must close at the **slow** corner: highest temperature from `306`, lowest
voltage after `404`'s droop, slowest process. Closing at nominal and discovering
the corner later is the ordinary way to lose fifteen per cent of a clock.

`306`'s peak junction temperature is a hot spot number, and the hot spot is inside
`605`'s multiplier array — which is also where the critical path is. **The hottest
transistors are the slowest ones and they are the ones on the critical path.**
That coincidence is not accidental and the budget must use the local temperature
rather than the die average.

### The two questions this must answer

**Can the core run at the face clock?** `1001` asks it. Closing `502`'s path a
hundred and sixty-seven picoseconds faster would remove a clock domain and a
crossing. This blueprint says whether it is possible.

**What does the thermal margin buy?** `005` reports about sixty kelvin of headroom
and suggests spending some on clock. Power goes roughly as the cube of frequency
near the top of the range, so the blueprint must produce the curve — frequency
against junction temperature against margin — and say where it runs out. That
curve is a deliverable in its own right, because it is how anybody decides what
speed grade to build.

### Hold, which is where machines actually die

Setup failures show up as a machine that will not run fast. **Hold failures show
up as a machine that does not work at any speed**, and they get worse at the fast
corner rather than the slow one, so a budget that only examines the slow corner
misses them entirely. The blueprint must do both corners and say so.

## Symbols this must publish

Per domain: logic delay, wire delay, setup, hold, skew, jitter, variation, cycle
time, and margin. At both corners. Local temperature used for each path.
Frequency-against-temperature curve. The core-at-face-clock verdict.

## Constraints this must assert

- Every domain's critical path plus its uncertainty is under its cycle time, at
  the slow corner.
- Every domain's hold requirement is met at the fast corner.
- The local temperature used for the face path equals `306`'s peak, not its
  average. A cross-blueprint check that catches the most common optimistic error.
- Frequencies used here equal the ones `1001` generates and `605`, `502` and `702`
  assume. **Four blueprints, one set of numbers.**

## Suggested implementation steps

1. Get each path from its owning blueprint rather than estimating it.
2. Budget at the slow corner with the local temperature.
3. Do the fast corner for hold, separately, and say why.
4. Answer the core-clock question.
5. Produce the frequency curve and hand it to `1303`.

## Blocks

`1303`, `1005` is cited by `306` and `605` in return.

## Blocked by

`306`, `404`, `502`, `605`, `702`, `903`, `1001`, `1002`.

## Related documents

`005` for the margin this decides how to spend.
