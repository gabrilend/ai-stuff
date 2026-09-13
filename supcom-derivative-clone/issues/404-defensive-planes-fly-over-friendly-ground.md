# 404 — Defensive planes fly over friendly ground

| | |
| --- | --- |
| Phase | 4 — The Cloud |
| Blocked by | 112, 403 |
| Blocks | 405 |
| Reads | [the cloud](../docs/007-the-cloud.md) |
| Open questions | none |

## Current behavior

Nothing. Issue 403 writes `defensive` and `intercepting` into planes' mission
fields when a round fires, and both rows in the `MISSIONS` table raise by name.
Territory from issue 112 knows which team owns every cell. `tests/022-the-cloud.lua`
asserts that a defensive plane ends up over a cell its team owns and that an
interceptor ends up over the cell its target is over.

## Intended behavior

This is the second half of the vision's air war, and the half that makes
winning the cloud not the same as winning the air: "If only defensive planes
remain, then AA engages and can attack the enemy planes. Because the defensive
planes fly over friendly territory, where anti-air can be stationed."

A **defensive** plane picks a station: the friendly-owned cell nearest to where
it is, found by walking the territory in array order and keeping the closest
cell whose owner is its team. It flies there at flight height and stays,
re-picking only if the cell changes hands under it. It seeks no combat. It is
still a targeting candidate for anything that can see it — but what can see it
over its own ground is its own side's guns, which do not fire on it.

An **interceptor** has a target: the enemy plane it was paired against by array
order at posture time, or, if it had none, the first enemy plane not in the
cloud. It flies toward the target's position each tick. When it comes within
one cell of the target, the pair is resolved exactly as a cloud round is —
issue 403's resolution, one draw, one buffered shot — and the interceptor then
picks its next target or, when there are none, returns. An interception is a
round of two, held wherever the target went, which is over the target's own
ground, which is where the guns are. Issue 405 fires them.

**Re-evaluation.** Every time the round counter fires, defensive planes compare
sides again, using the sums of everything airborne rather than only what is in
the cloud. A side that is no longer weaker — because the other side's
interceptors died over the guns — sends its defensive planes `returning`, and
they fly back to the cloud and rejoin it. The whole cycle is: win the cloud,
chase, be shot, lose the cloud.

## Suggested implementation steps

1. In `territory` (issue 112), export `nearest_owned(world, team, x, y)`: cell
   index and distance, by array walk, returning zero when the team owns nothing.
2. Fill the `defensive` row in `the-cloud`'s `MISSIONS`: station chosen on
   entry and stored in the plane's `target` field as a negative cell index —
   the sign says "a cell, not a unit" without a second field; step toward it;
   hold.
3. Fill the `intercepting` row: `target` holds an enemy plane id; step toward
   it; within one cell, call the resolution function from issue 403 with the
   pair; afterwards pick the next target by array order or flip to `returning`.
4. Fill the `returning` row: step toward the cloud; flip to `in-cloud` within a
   cell and set `round_joined`.
5. In `round_pass`, add a fourth step after resolution: re-posture defensive
   planes against the airborne sums, through the same three-row table.
6. Comment the negative-index convention on the `target` field where it is
   declared in `the-world`, because it will be needed again.
7. Update the companion.

## Related documents and tools

- [The cloud](../docs/007-the-cloud.md)
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — cell ownership
- `tests/022-the-cloud.lua`

## Still open

- Whether a defensive plane should station over the cell nearest to *itself*
  or nearest to the enemy — the first is safer, the second draws interceptors
  further over the guns. Nearest to itself is the working ruling.
- Whether a plane's `target` should hold a cell index by sign, or the record
  should grow a second field. The sign is chosen because zero already means
  "nothing" for both.
