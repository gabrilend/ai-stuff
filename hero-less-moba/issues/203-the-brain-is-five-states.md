# 203 — The Brain Is Five States

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 201, 202, 204 |
| Blocks | 206, 304, 504, 606 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

Soldiers walk in a straight line to the end of the lane and never stop for
anything.

## Intended behavior

A soldier's `state` field indexes a **dispatch table of behaviour functions**,
one per state, each returning the next state. There is no chain of conditionals
deciding what a soldier is doing; the soldier already knows, and the table says
what knowing that means.

**1 — Walking.** Advance. Each tick, ask whether anything hostile is within
*acquisition range*, a radius deliberately wider than weapon range so that
soldiers commit to a fight slightly before they can reach it. If yes, take a
target and go to closing. If the next node carries an enemy structure and no
enemy soldier is nearer, take the structure.

**2 — Closing.** Keep advancing toward the target until it is inside weapon
range, then go to fighting. Recheck the target's generation every tick; if it
died, drop back to walking rather than walking into empty air.

**3 — Fighting.** Stop moving. Swing when the cooldown allows. Heroes check
ability cooldowns here. If the target dies, return to walking **on the same
tick** rather than idling for one. An idle tick per kill is invisible on any one
soldier and adds up to a visibly limp frontline across a wave.

**4 — Leashing.** Guards only. Walk back toward the leash node, refusing to
acquire anything on the way.

**5 — Dying.** One tick of bookkeeping: pay every player on the killer's team, decrement the
wave's living count, free the slot.

Every transition gets a comment naming what each path leads to. The condition and
its comment are edited as one unit; changing one without the other leaves a lie
in the file.

## Suggested implementation steps

1. Write the five behaviour functions and the table that indexes them.
2. Wire the retarget, move, and attack passes to consult the state rather than
   each re-deciding what a soldier is up to.
3. Give acquisition range its own catalogue field, separate from weapon range,
   and a comment explaining that the gap between them is what makes soldiers
   commit rather than dance at the edge.
4. Make the fighting-to-walking transition happen within the tick, not on the
   next one. Write a test that counts idle ticks across a wave's worth of kills
   and asserts zero.
5. Write a test per state that puts a soldier in it artificially and asserts the
   transition it produces.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- Issue 204, which supplies the target the states depend on
