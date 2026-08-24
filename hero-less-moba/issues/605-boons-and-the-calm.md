# 605 — Boons, and the Calm They Are Chosen In

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 105, 401, 402, 601, 606 |
| Blocks | 607 |
| Reads | [boons and the challenge](../docs/015-boons-and-the-challenge.md) |
| Open questions | A8c |

## Current behavior

A challenge monster dies and the phase returns to normal. Nothing is paid for
having killed it beyond the personal resource of the last blow.

## Intended behavior

**A boon is payment for slaying a challenge monster, not for surviving a surge.**

When both of a challenge's monsters are dead, the phase moves to **the calm** — a
phase in which nothing spawns and **every soldier still on the field turns
around and walks back to its own base**, where it leaves the game. Nobody fights
on the way. It lasts thirty seconds to a minute. In that window:

- **Each player chooses a boon from three offered.** One per player, three per
  team.
- **The chest gets re-placed.** Everything dumped out when the surge ended is
  still sitting there doing nothing.

Then spawning resumes.

**It happens twice, not three times** — after the Pillar Orc and after the Field
Dragon, never after the Eternal Golem, which is never slain. **Six boons per
team** over a full match.

### What a boon is

An instance with `is_boon = 1`, **no slot**, and an `owner` — the only instance
kind that has one. OR-ed into all three `lane_mask` entries when the masks
rebuild, and skipped entirely by the surge's dealing pass.

So a boon applies to all three lanes, cannot be moved, survives every surge
unscattered, and **belongs to the player who chose it** rather than to the team.

Why the calm exists, why a boon paid for the kill is different from one handed
out when the monster appears, and why the frontline reset it causes is a
structural statement about what a match is, are all in
[boons and the challenge](../docs/015-boons-and-the-challenge.md).

**One line from there is worth repeating here as a build instruction:** if the
calm is ever shortened for pacing, the boon choice stops being a choice and
becomes a thing you click through.

## Suggested implementation steps

1. Add the calm as a phase-table row in issue 601: nothing spawns, all slots
   legal, a fixed duration in ticks that is a balance value **from the first
   commit**, because it will be changed several times and can only be found by
   watching people use it.
2. Write the **walking home** behaviour by reusing the leashing state from issue
   304 — reverse `facing`, leash to the team's own library, refuse to acquire,
   leave the game on arrival. Do not write a sixth brain state.
3. **Recompute push depths at the end of the calm.** It is the one moment in a
   match where the frontline moves backwards for everybody at once, and the
   incremental maintenance from issue 102 cannot follow it.
4. Write the boon catalogue as a data table under `assets/` with its own
   validator, sharing the upgrade kind record's shape.
5. On entering the calm, draw **three offers per player** from the `boon` stream
   into the snapshot. Per player, not per team — so two teammates can be offered
   the same boon and have to decide between them who takes it.
6. Write `choose_boon`. A player who does not choose before the calm ends gets
   the first of their three. **Never nothing** — a player who looked away should
   not be permanently behind their teammates.
7. Extend `rebuild_masks` to OR every `is_boon` instance into all three lane
   masks, and confirm the surge dealing pass skips them. Test across both surges.
8. Keep a permanent list of each player's boons on screen. A boon nobody can look
   up is an unexplained change in how strong their soldiers are.

## Related documents and tools

- [Boons and the challenge](../docs/015-boons-and-the-challenge.md)
- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)

## Still open

**How long is the calm?** Long enough to read three options and re-place a chest,
short enough that a match does not sag. **The only phase in the game whose entire
purpose is to be comfortable**, which makes it the easiest one to ruin by
trimming.

**A8c — what if one team's monster dies long before the other's?** The challenge
ends when *both* are dead, so the faster team waits. Their reward for finishing
first is a free push up the center while the enemy is still busy — which may be
enough, or may feel like a punishment for winning.

**Are boons balanced against each other?** Three offers means a player picks the
strongest, so unlike a handed-out boon there is no averaging. The catalogue has to
be flat enough that the choice is about fit rather than about which one is best.
