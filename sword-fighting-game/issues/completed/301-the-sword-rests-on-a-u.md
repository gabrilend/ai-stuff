# 301 — The Sword Rests On A U

| | |
| --- | --- |
| Phase | 3 — The sword |
| Blocked by | 203, 202 |
| Blocks | 302, 304, 405 |
| Files | `src/009-the-u.lua` |
| Reads | `docs/datapath-melee-hit.md` |

## Current behavior

Built in `src/009-the-u.lua`. A lock is taken at once when there is none;
switching from one living lock to a nearer enemy takes the switch time.
Tested in tests/033-the-sword.lua.

## Intended behavior

**The U.** The weapon's place is one number, `u`, from −1 to +1. Picture a
letter U around the locked enemy: −1 is the top of the left arm, 0 the bottom
of the bend, +1 the top of the right arm. Mouse motion moves `u` (configured
sensitivity), clamped to the ends. The U maps `u` to the side a swing comes
from:

| u | Side | Swing |
| --- | --- | --- |
| below −(bend width) | left | slash from the left |
| within ± bend width | bend | stab |
| above +(bend width) | right | slash from the right |

The bend is wide (configuration, default 0.55), because most attacks are
stabs. The same mapping gives the view the point in space to draw the sword
at: the U's arms rise beside the target and the bend dips in front of it.

**The lock.** The U is always drawn around the nearest living enemy within
the lock range. When a different enemy becomes nearest, the switch is
pending: `lock_next` names it and `lock_timer` counts the configured half
second; when it runs out the lock moves. If the pending one stops being
nearest before then, the pending switch is cancelled. With no enemy in range
there is no lock, and the soldier's eyes follow its facing.

A soldier turns its facing toward its lock at the configured turn rate
(players turn by the same rule unless free look is held), so "the enemy
doesn't know which way you are looking" falls out of the delay.

## Suggested implementation steps

1. Write the U mapping (u → side, and u → offset for drawing) and the lock
   update.
2. Test: a nearer enemy takes the lock only after half a second; a lock
   switch that is overtaken is cancelled; u at 0 is a stab, at ±1 a slash.
