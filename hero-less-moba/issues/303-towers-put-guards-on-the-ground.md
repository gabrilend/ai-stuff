# 303 — Towers Put Guards on the Ground

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 105, 201, 301 |
| Blocks | 304, 305, 306 |
| Reads | [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md) |
| Open questions | B10 |

## Current behavior

Towers put guards on the ground up to a cap, and **only while no enemy stands
inside the command radius** — the inversion is the mechanic. The timer is held rather
than reset while the ground is contested, so one body touching the edge of the circle
cannot shut a tower down permanently.

A guard is stamped from its tower's slot and re-stamped when that slot changes.

## Intended behavior

Each tower keeps a small standing patrol. On a timer, if it has an empty guard
slot, it puts a soldier on the ground at its own node.

A guard is an **ordinary soldier record** with `flavour = 3` — same store, same
brain, same combat. Two fields make it a guard:

- `leash_node` is set to the tower's node.
- `facing` is 0 while patrolling, so the move pass wanders it inside the leash
  radius using the `wander` random stream instead of advancing it along the lane.

Guards are **area denial**. They are the reason a lone hero cannot walk up to a
tower and start chewing, and the reason the ground *around* a tower is dangerous
rather than just the tile the tower stands on. Without them, towers are a damage
tax on passing waves and nothing more.

They do not advance with a wave and do not chase a retreating enemy down the
lane. That is issue 304.

When a tower is felled, **its living guards die immediately.** They do not
survive their tower. A patrol with nothing to patrol is a wandering pocket of
soldiers with no purpose, and cleaning them up is cleaner than explaining them.

## Suggested implementation steps

1. Add the guard-slot array and the guard timer to the structure record, and the
   guard archetype to the unit catalogue.
2. Write the guard spawn into the spawn pass, guarded on an empty slot.
3. Write the wander behaviour: pick a point inside the leash radius from the
   `wander` stream, walk to it, pick another. Using a stream and not the clock is
   what keeps guard motion out of the replay's way.
4. Wire the tower-felled path to kill its guards, and note in the comment that
   this is deliberate rather than convenient.
5. Write a test: a single strong soldier standing next to a tower is engaged by
   guards, and cannot fell the tower without dealing with them.

## Related documents and tools

- [Guard towers and their guards](../docs/007-guard-towers-and-their-guards.md)
- The `wander` stream from issue 105

## Settled

**A guard is stamped, like everything else — and unlike a wave unit, it is
re-stamped when its tower changes.** It carries its own copy of
`tower_count[lane]`, or `base_tower_count` for a base tower. Nothing in the swing
path holds a reference to a tower.

**Clear, then re-stamp.** When an upgrade arrives at or leaves a lane's towers,
every guard in that lane has its counts **cleared and rebuilt from what the tower
now holds** — not patched with a delta. A rebuild from current truth cannot
drift; an incremental adjustment can, and will, in whichever direction nobody
wrote a test for. Sweeps are rare and small, so the slower one is free.

**The switch happens at a wave spawn.** An upgrade queued to move somewhere else
keeps applying where it is until the next wave spawns, then moves; the guards at
both ends are swept on that same tick, which is also the instant that stamps the
outgoing wave.

**A wave unit is never swept and a guard always is**, and both call sites want a
comment, because from either one the other looks like a bug. A wave unit walks
away from its lane; a guard stands at its tower for life, so a guard whose tower
changed and whose numbers did not is something a player can see and be right to
call broken.

**During a siege-surge a tower has nothing on it**, so its guards have nothing
either, and no new guards are produced at all.

So slotting into a lane's towers buys **bodies as well as arrows**. Two things
stop that dominating. **Guards are leashed** — a tower upgrade buys a better
wall and cannot buy a step forward; if leashing is ever loosened, this is the
rule that breaks first, so say so above the leash check. And **the purchase is
reversible** — move the upgrade out and the guards are ordinary again on the next
wave, which is what stops stone being the unlosable side of the trade.

**Guards are replaced only while the command radius is clear**, up to a cap that
stone upgrades can raise. See issue 304 and the tower document.

See [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md).

## Still open

How many guards per tower, and how fast a felled guard is replaced. This matters
more now than it did: guard count is a multiplier on every stone upgrade, so it
is not only a question about how hard a tower is to walk past.
