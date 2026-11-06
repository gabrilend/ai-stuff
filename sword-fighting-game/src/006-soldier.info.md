<!-- made by scripts/build-info-pages from the comments in 006-soldier.lua; change the comments and rebuild, not this page -->
# 006-soldier


One body on the field. Every soldier, the player's included, is the same
flat record; the player is a soldier with a hand on it. The fields are
listed in this file's .info.md page with their types.

The derived numbers (armor after thickness, walking share, awareness) are
worked out once here, when the soldier is made or refreshed after a perk,
and never per tick.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.new` | `catalogue, config, unit_name, fields` | `fields` gives id, team, battalion, slot_x, slot_y, x, y, facing. |
| `M.become` | `s, catalogue, config, unit_name` | Takes on a unit type: its weapon, health, armor and traits. Used when a soldier is made and when a perk converts it. |
| `M.refresh` | `s, config` | Recomputes the derived numbers from the unit type and the perks laid on the soldier (extra_armor, thick_override, perk_traits). |
| `M.fatigue` | `s` | (no comment in the source) |
| `M.can_act` | `s` | Standing, alive, and not reeling: able to start a swing or a guard. |
| `M.forward` | `s` | The unit vector the soldier faces, on the map. |
| `M.right` | `s` | The unit vector to the soldier's right. Map y grows southward, so the right of a soldier facing east (0) is south (0, 1). |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `trait_set` | `list` | (no comment in the source) |
