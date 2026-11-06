<!-- made by scripts/build-info-pages from the comments in 012-soldier-mind.lua; change the comments and rebuild, not this page -->
# 012-soldier-mind


The small mind that fights for every soldier without a hand on it. It
writes the same intent record a person's keys and mouse write (forward,
side, guard, swing, u_delta, dodge), so the rules cannot tell a mind from a
person, and a headless battle is a whole battle.

The mind is a handful of states in a table. It is deliberately a little
slow (a reaction delay) so it can be beaten, and it never backsteps while
fatigued, so minds do not trip themselves on purpose.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.slot_position` | `battle, s` | Where the soldier's place in its battalion's formation is now: the battalion's origin is the middle of its front rank, slots run across to the right and back by rank. |
| `STATES.march` | `battle, s, m, i` | Keep to the formation slot as the battalion advances; engage an enemy that comes near; a skirmisher throws first when the enemy is a battalion length or two away. |
| `STATES.engage` | `battle, s, m, i` | (no comment in the source) |
| `STATES.recover` | `battle, s, m, i` | Stand and breathe; guard only when a blow is coming, because the guard itself costs stamina. |
| `STATES.harry` | `battle, s, m, i, dt` | The harry perk: strike, then the battalion steps back together. |
| `STATES.fall_back` | `battle, s, m, i` | A skirmisher, having thrown, slips back through the loose formation. |
| `M.think` | `battle, s, dt` | (no comment in the source) |

## Tables of rows

| Name | What it is |
| --- | --- |
| `AIM` | U positions a mind aims for, by side. |
| `STATES` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `safe_forward` | `battle, s, forward` | A fatigued soldier never wishes a backstep big enough to count as one. |
| `walk_toward` | `battle, s, i, tx, ty, arrive` | Sets the wish to walk to a point, relative to where the soldier faces. |
| `threatened` | `s` | The lock is winding up a swing aimed at this soldier. |
| `decide_guard` | `battle, s, m` | Once per enemy swing seen, the mind decides whether to guard against it. |
| `choose_side` | `battle, s` | Most attacks are stabs. Otherwise a slash, from the side opposite the last one when there was one, because that is where the momentum is. |
| `nearest_within` | `battle, s, radius` | (no comment in the source) |
