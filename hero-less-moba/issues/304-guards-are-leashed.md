# 304 — Guards Are Leashed

| | |
| --- | --- |
| Phase | 3 — Things That Stand and Hold |
| Blocked by | 203, 303 |
| Blocks | 305 |
| Reads | [guard towers and their guards](../docs/007-guard-towers-and-their-guards.md) |
| Open questions | none |

## Current behavior

Guards wander a random walk inside their leash using the wander stream, close on
anything that comes near, and walk home refusing to acquire the moment they drift past
it. They never advance with a wave and never follow a retreating enemy.

They are also outside everything a line does: no formation, no cohesion budget, and
they never fall back.

## Intended behavior

The **leashing** state, entry 4 in the brain's dispatch table. A guard enters it
the moment its target dies or it finds itself outside the leash radius, and while
leashing it walks back toward its `leash_node` **refusing to acquire anything on
the way**.

The refusal is the important half. A guard that leashes home but re-acquires the
first enemy it passes never gets home; it oscillates at the edge of its radius,
which looks broken and is broken.

A guard will engage anything that comes inside its acquisition range while it is
patrolling. It will not follow that thing out. The net effect is a bubble of
dangerous ground around each tower, whose edge is a hard line rather than a
gradient.

Wave units, heroes, and monsters have `leash_node = 0` and can never enter this
state. The check is an integer comparison, not a flavour test — a soldier with a
leash node leashes, whatever it is. That keeps the door open for a hero or a
monster that should be leashed later without adding a special case now.

## Suggested implementation steps

1. Write the leashing behaviour function and wire it into the brain's table.
2. Write the two entry conditions: target died, or distance from `leash_node`
   exceeds the leash radius.
3. Write the exit condition: back within a smaller inner radius. **Use a
   different radius for leaving and returning.** One radius produces a guard that
   flickers between states at the boundary; two produce a guard that commits.
   Comment this, because a single radius looks simpler and is wrong.
4. Suppress acquisition entirely while leashing, and say why in a comment.
5. Write a test: bait a guard to the edge of its leash with a fast soldier, then
   kill the bait, and assert the guard returns home without being distracted by a
   second soldier placed on its path.

## Related documents and tools

- [Guard towers and their guards](../docs/007-guard-towers-and-their-guards.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — the
  five brain states
