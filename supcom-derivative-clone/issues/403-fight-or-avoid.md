# 403 — Fight or avoid

| | |
| --- | --- |
| Phase | 4 — The Cloud |
| Blocked by | 106, 107, 401 |
| Blocks | 404, 406, 407 |
| Reads | [the cloud](../docs/007-the-cloud.md) |
| Open questions | E5 |

## Current behavior

Nothing. Planes reach the cloud through issue 402 and sit there. The round
counter exists as a periodic effect from issue 401 and fires, and nothing
listens. `tests/022-the-cloud.lua` asserts that a weaker side goes defensive
when a round fires and that the stronger side's planes do not.

## Intended behavior

The cloud fights in **rounds, on a counter.** When the `cloud-round` effect
fires, `round_pass` does three things in a fixed order, and the order matters
because a plane that decides to leave this round does not fight it.

**First, posture.** Each side's **air strength** in the cloud is the sum of its
in-cloud planes' `strength` fields. Each plane compares its own side's sum to the
other's: weaker, and it leaves for `defensive` (issue 404); stronger, and its
mission becomes `intercepting` with a target chosen below; equal, and it stays
and fights. That is the vision's "if they don't have good air combat abilities
compared to their foes, then they'll avoid combat. If they do, then they'll seek
out enemy planes." The comparison is by sums so that ten weak planes are a
match for three strong ones, which is what makes production matter in the air.

**Second, pairing.** The planes still in the cloud are paired off: the first of
one side with the first of the other, by array order, and so on until one side
runs out. Unpaired planes sit out. A plane that arrived since the last round —
its `round_joined` is the current increment — sits out too, so that a plane
cannot be born into a fight.

**Third, resolution.** Each pair draws one double from the `cloud-round` named
stream. The first plane wins if the draw is below its strength over the sum of
both strengths; the loser takes the round's damage. Damage is **buffered**, not
written: the round appends a shot to issue 206's list with an arrival tick of
now, and the land pass applies it in order. Two machines that pair the same
planes and draw the same stream land the same shots.

A plane's strength is **copied at birth** from its team's upgrade table (issue
407), which is E5's working ruling. A plane built before an upgrade fights
without it.

## Suggested implementation steps

1. Add `strength` (integer) and `round_joined` (integer) to the unit record in
   `the-world`; both zero for anything that is not a plane.
2. In `the-cloud`, export `side_strength(world, team)`: the sum over in-cloud
   planes, by array walk.
3. Export `round_pass(world)`: return at once unless the `cloud-round` counter
   fired this tick; then posture, pairing, resolution, in that order. Register it
   as the row named "the cloud" in `the-tick`'s `SYSTEMS`.
4. Posture writes each plane's `mission` through a three-row table keyed by the
   sign of the strength difference: weaker, equal, stronger. No branch.
5. Pairing builds two flat arrays of ids in array order and walks them together.
6. Resolution opens the `cloud-round` stream once per match through
   `random-streams` (issue 107) and draws once per pair. It appends shots through
   `combat` (issue 206); it never touches a health pair directly.
7. Set `round_joined` in the `to-cloud` row when the mission flips to
   `in-cloud`.
8. Update the companion with the three steps and the posture table.

## Related documents and tools

- [The cloud](../docs/007-the-cloud.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — the round counter, the named streams
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — buffered damage
- `tests/022-the-cloud.lua`

## Still open

- E5: where air strength comes from — a per-team upgrade table bought with
  energy is the working ruling, and a plane copies its team's total at birth.
- Whether strength should be compared by sum or by average. Sum is chosen so
  that numbers matter; the proving ground will say whether it makes the cloud
  a pure production race.
- Whether an unpaired plane should still take a draw against nobody, so that a
  lone survivor does not sit in perfect safety. The working ruling is that it
  sits out.
