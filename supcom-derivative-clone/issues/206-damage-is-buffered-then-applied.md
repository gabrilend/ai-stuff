# 206 — Damage is buffered, then applied

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 106, 205 |
| Blocks | 208, 310 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | A3 |

## Current behavior

Nothing. The test program `tests/020-things-that-roll-fly-and-sail.lua` names
this issue and looks for the stem `combat`; it asserts that a shot lands at the
tick its distance says and not before.

## Intended behavior

**Firing changes nothing.** A unit that has a target and a reloaded weapon
appends a **shot** to a buffer and rewrites its own `reload_at`. The shot is a
row in a flat array: shooter, target, the damage at the target's current
distance (issue 205's falloff), and the **arrival tick**. Nothing else in the
world moves when a shot is fired.

**Landing is where damage happens.** The land pass walks every shot whose arrival
tick is now, in buffer order, and applies each one to its target: the target's
current health is derived from its heal pair (issue 106), the damage is taken
off, and the pair is rewritten with the increment of now. A shot whose target is
already dead is dropped. A shot aimed at a unit inside an enforcer's sphere is
taken by the shield first (issue 211).

The split exists for two reasons, and both are load-bearing:

- **The thread pool.** The fire pass is sliced: it reads the world and writes
  only its own shooter's row and its own slice of the buffer. The land pass is
  unsliced and runs on one worker in a fixed order, because it writes other
  units' rows. Nothing sliced ever writes to a row it does not own.
- **Lockstep.** Two machines land the same shots in the same order because the
  buffer is walked from one to its length and shots are appended in unit-row
  order within a tick. Any other order would fork the match.

**Dying is a state, not an event.** The die pass, after landing, marks every unit
whose derived health is at or below zero as dead, lowers the live count, and
hands the row to issue 208 to leave bones. Nothing but the die pass ever
observes a unit to be dead, so nothing else needs to check.

The buffer is **allocated once** at world allocation, sized from the parameters,
and refuses — loudly — when it is full rather than growing, because a buffer
that grows mid-tick is an allocation on the hot path and a shot that is silently
dropped is a desync waiting to be found.

A3's working ruling is built here: a shot follows its target, so the land pass
resolves against the target's position at landing. The other reading — the
shot lands on the ground it was aimed at and hurts whatever stands there — is a
different land pass and a different shot row, and this issue is where it would
change.

## Suggested implementation steps

1. Claim `src/NNN-combat.lua` with `./new-source-file combat`.
2. Write the shot buffer as flat arrays: `shooter`, `target`, `damage`,
   `arrives`, with a count, allocated in issue 104's world. Refuse a full
   buffer by name.
3. Write `fire_pass(world)`, sliced: for each live unit with a non-zero target
   and a reload counter that permits it, append a shot and rewrite `reload_at`.
4. Write `land_pass(world)`, unsliced: walk the buffer once; for each shot
   arriving now, derive the target's health through the timer pair, subtract,
   rewrite; drop shots on dead targets; compact the buffer by moving the last
   row into the freed slot only for shots that have landed.
5. Write `die_pass(world)`, unsliced: mark dead rows, lower the live count, and
   call issue 208's `leave`.
6. Register all three in the tick's dispatch table (issue 105) in the order
   fire, land, die, after the aim pass.
7. Write the failure text a test prints when a shot lands early or late: the
   shot's row, its arrival tick, and the tick it was checked at.

## Related documents and tools

- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [the tick and the timers](../docs/003-the-tick-and-the-timers.md) — the heal pair and the pool's rule
- [other players](../docs/011-other-players.md) — why order is everything
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **A3.** Tracking or ballistic; the working ruling is tracking, and the land
  pass is where the alternative would be built.
