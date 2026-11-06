# 302 — Swings Carry Momentum

| | |
| --- | --- |
| Phase | 3 — The sword |
| Blocked by | 203, 301 |
| Blocks | 303, 304, 403 |
| Files | `src/010-swings.lua` |
| Reads | `docs/datapath-melee-hit.md` |

## Current behavior

Built in `src/010-swings.lua`, with a quick riposte request (a stab at a
third of the windup). Thick armor lengthens windups and recoveries by a
tenth. Tested in tests/033-the-sword.lua.

## Intended behavior

A swing is a record on the soldier: `kind` ("stab", "slash", "overhead"),
`side` ("left", "bend", "right", "above"), `t` (seconds since it began),
`windup`, `strike_done` (boolean), `recovery`, `momentum` (number), and
`target` (the lock when it began).

The swing kinds are a dispatch table, each row giving windup, recovery,
reach bonus, damage multiplier and stamina cost (configuration, scaled by the
weapon's multipliers). A swing may begin when the soldier is standing, not
already swinging, not staggered, and its weapon allows the kind (a
stabs-only weapon turns every swing into a stab). Starting a swing spends
stamina; at the end of the windup the swing strikes once (303 resolves it);
after the recovery the soldier may swing again.

**Momentum** is fixed at the moment of the strike:

- body part: the soldier's velocity toward its target, in cells per second,
  times the body weight knob;
- pattern part: from the previous swing's side to this one's, a table:
  opposite side (left→right, right→left) adds the flow bonus; bend after a
  side adds a small bonus; same side again adds nothing; overhead adds the
  overhead bonus. The pattern part decays if the previous swing was long ago
  (configured window).

The overhead (space) has a longer windup and recovery, extra damage, and
leaves the attacker **open** during recovery: hits on an open soldier cannot
be parried.

## Suggested implementation steps

1. Write the kinds table, swing start, swing advance (returns "strike" on the
   strike tick), and momentum.
2. Test: alternate-side swings gather more momentum than same-side swings;
   walking into the target adds momentum; an overhead leaves its swinger open.
