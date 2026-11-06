# 303 — A Hit Is Resolved In One Order

| | |
| --- | --- |
| Phase | 3 — The sword |
| Blocked by | 102, 203, 204, 302 |
| Blocks | 304, 305, 501, 601 |
| Files | `src/011-hit-resolution.lua` |
| Reads | `docs/datapath-melee-hit.md` |

## Current behavior

Built in `src/011-hit-resolution.lua` as a list of steps; the causes of a
critical are a list too, credited in order. The resolution takes the swing
as it was when it struck (see issue 305). The damage and fall step is shared
with volleys. Tested in tests/033-the-sword.lua.

## Intended behavior

When a swing strikes, resolution runs these steps in order, and each step
either ends the resolution or passes on:

1. **Reach** — the target must be alive, within the weapon's reach plus the
   kind's reach bonus, and within the attacker's striking arc (in front of
   it). Otherwise: a miss.
2. **Parry** — if the target is guarding, standing, not open, and not hit
   from behind (more than 135 degrees off its facing), it rolls its parry
   chance (204) plus its shield bonus. Success: no damage, both spend
   stamina, the attacker staggers briefly. The riposte trait answers a
   successful parry with an immediate stab.
3. **Flank** — the attacker's bearing from the target, compared with the
   target's facing: more than 90 degrees off is a flank.
4. **Critical** — critical when any of: momentum at or above the critical
   threshold; a flank (a flanked solid connect is always critical); the
   attacker has the always-critical trait; a roll of the attacker's critical
   chance. The cause is recorded (momentum, flank, trait, chance) for the
   statistics.
5. **Damage** — weapon damage for the kind × kind multiplier × (critical
   multiplier when critical) × (1 − armor rating × armor percent per point,
   capped).
6. **Effect** — health falls; the target staggers; at zero health it falls,
   releases its cell, and is counted.

Every resolution emits an event (miss, parry, hit, critical, fall) onto the
battle's event list, which the view reads to draw sparks and dents and the
counters read for the receipt.

## Suggested implementation steps

1. Write the resolution as a list of step functions run in order.
2. Test: a guarded fresh target parries nearly always; an exhausted one
   rarely; a flanked hit is always critical; armor lowers damage by its
   percentage; a hit from behind cannot be parried.
