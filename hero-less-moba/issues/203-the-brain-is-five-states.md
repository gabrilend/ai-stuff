# 203 — The Brain Is Five States

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 201, 202, 204 |
| Blocks | 206, 304, 504, 606 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

A dispatch table with a row per state: walking, closing, fighting, leashing,
dying, waiting and recovering. Six of the seven are built — **waiting is not**, and
nothing enters it, because it is a hero standing at its library during a calm and
heroes bought in a calm are not yet held back.

The Golem is the one body that is not the state machine: it walks, it hits what it
walks into, and it does not stop for either.

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

**5 — Dying.** One tick of bookkeeping: pay every player on the opposing team,
decrement the wave's living count, free the slot.

**6 — Waiting.** A hero bought during a calm, standing at its own library until
spawning resumes. Does not advance, does not acquire. See A17 and F24 — and note
that it is the only state where a body has nothing at stake, which makes it the
only place idle behaviour belongs.

**7 — Recovering.** A wounded body that has pulled out of the line, waiting
beside a healer or regenerating at its own tower, returning when the frontline
turns against its team. See F35 and
[standing off and falling back](../docs/022-standing-off-and-falling-back.md).

**The title of this issue is wrong and stays wrong.** It said five and there are
seven, and the two that arrived late did so for good reasons that are recorded
where they were decided. Renaming the file would take the roadmap, the tracker,
and every citation with it — see F32 for the last time this project let a name
drift and what it cost. It is on the list of renames to do in one deliberate
pass.

Every transition gets a comment naming what each path leads to. The condition and
its comment are edited as one unit; changing one without the other leaves a lie
in the file.

### What is *not* a state

Two behaviours that look like states and are not, because putting them in the
table would double it:

- **Walking home at the start of a calm** reuses **leashing**, with the leash set
  to the team's own library.
- **Standing off** — a ranged body backing away at half speed when an enemy is
  inside its reach but nearer than the maximum — is a movement rule inside
  **fighting**, not a state of its own. It is a question about where to put your
  feet while doing the thing you are already doing.

## Suggested implementation steps

1. Write the seven behaviour functions and the table that indexes them.
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
