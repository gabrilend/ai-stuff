<!-- made by scripts/build-info-pages from the comments in 013-ranged.lua; change the comments and rebuild, not this page -->
# 013-ranged


Volleys and the shield wall: the commander's two hands.

A volley is thrown by every soldier of a contingent not already fighting.
Every dart flies the same arc, because everyone trained the same way and
nobody can see how far the enemy is: it lands three battalion lengths ahead
of its thrower. Only the trained-arc perk lets a contingent pick range 1, 2
or 3. The commander chooses when to throw, not how far.

A dart that lands near an enemy joins the hit-resolution order at its parry
step, with the shield wall's large bonus against thrown weapons.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.engaged` | `battle, s` | Fighting already: its lock is within engage range. |
| `M.ready` | `battle, team` | (no comment in the source) |
| `M.set_range` | `battle, team, range` | Only a contingent with the trained arc may change its range. |
| `M.volley` | `battle, team` | Throws, if the cooldown allows. Returns the number of darts thrown. |
| `M.throw_single` | `battle, s, ex, ey` | A skirmisher's throw from the front rank, straight at an enemy. |
| `M.step` | `battle, dt` | Darts fly; those whose flight is over land, and the list is compacted in place so its order (and so the landing order) is the order thrown. |
| `M.position` | `battle, d` | Where a dart is now, for drawing: along the line, lifted on the one arc. |
| `M.commander` | `battle, team, dt` | The commander's mind, for a side no person commands: throw when the enemy is about where the arc lands; raise shields while the enemy's darts fly. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `launch` | `battle, s, ex, ey` | (no comment in the source) |
| `land` | `battle, d` | The nearest standing enemy of the thrower within the hit radius takes it, unless a shield turns it aside. |
| `front_gap` | `battle, team` | The distance between this side's nearest battalion and the enemy's. |
