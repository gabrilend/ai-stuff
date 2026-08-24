# 303 — Towers Put Guards on the Ground

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 105, 201, 301 |
| Blocks | 304, 305, 306 |
| Reads | [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md) |
| Open questions | B10 |

## Current behavior

A tower is a point that shoots. The ground around it is perfectly safe, so a lone
strong body can stand next to a tower and hit it with impunity as long as it
out-heals the arrows.

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

**A guard is stamped at spawn with its tower's stone upgrades** — `tower_mask[lane]`
for a lane tower, `base_tower_mask` for a base tower. Stamped, not read live, for
the same reason a wave unit is; the *tower* reads live. Those two rules sit next
to each other in the same file and each needs a comment saying why it is not the
other one.

So slotting into stone buys **bodies as well as arrows**. What stops that
dominating is already in this issue and in 304: **guards are leashed.** A stone
upgrade buys a better wall; it cannot buy a step forward. **If leashing is ever
loosened, this is the rule that breaks first** — say so above the leash check.

See [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md).

## Still open

How many guards per tower, and how fast a felled guard is replaced. This matters
more now than it did: guard count is a multiplier on every stone upgrade, so it
is not only a question about how hard a tower is to walk past.
