<!-- made by scripts/build-info-pages from the comments in 009-the-u.lua; change the comments and rebuild, not this page -->
# 009-the-u


Where the sword rests, and who it is pointed at.

The U: picture a letter U drawn around the locked enemy. The weapon's place
on it is one number, u, from -1 (top of the left arm) through 0 (bottom of
the bend) to +1 (top of the right arm). The arms make slashes from their
side; the bend makes a stab, and the bend is wide because most attacks are
stabs: a battalion has no room for wide slashes.

The lock: the U is always drawn around the nearest enemy. When a different
enemy becomes nearest, the lock takes half a second to move to it, and it
moves before the next attack, so the enemy cannot tell which way you are
about to look.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.side_of` | `u, config` | Which part of the U the weapon is on: "left", "bend" or "right". |
| `M.shape` | `u` | The point on the U for drawing: lateral from -1 (left) to 1 (right), and lift from 0 (bottom of the bend) to 1 (top of an arm). The arms rise steeply, as a U's arms do. |
| `M.move` | `s, delta` | (no comment in the source) |
| `M.update_lock` | `battle, s, dt` | No enemy near: no lock. No lock yet: the first takes hold at once. A lock held: a nearer enemy takes it only after the switch time, and a pending switch that is overtaken by a third enemy starts its clock again. |
| `M.turn` | `battle, s, dt, toward` | Turns the body toward an angle at the turn rate. Players and minds turn by the same rule; free look moves only the player's eyes, not the body. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `nearest_enemy` | `battle, s` | (no comment in the source) |
