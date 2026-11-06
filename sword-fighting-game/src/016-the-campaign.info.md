<!-- made by scripts/build-info-pages from the comments in 016-the-campaign.lua; change the comments and rebuild, not this page -->
# 016-the-campaign


The map the rounds add up to: a grid of regions, each a kind of ground and
an owner. The front is the region the next battle is pushed from; the
player picks a compass direction from it, and the battle is fought in the
neighbour that way. Winning there takes it; losing gives ground back toward
home. A battle won in the enemy's home wins the match; a battle lost with
the front at the player's home loses it.

Region coordinates count from 0: column across, row down. Row 0 is the
enemy's side (north), the last row the player's.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.new` | `config, catalogue, stream` | (no comment in the source) |
| `M.region` | `map, col, row` | (no comment in the source) |
| `M.target` | `map, dir` | The region a push in this direction would be fought in, or false when it leads off the map. |
| `M.legal_pushes` | `map` | (no comment in the source) |
| `M.is_home` | `map, team, region` | (no comment in the source) |
| `M.enemy_push` | `map, stream, straight_weight` | The enemy commander's direction: weighted toward heading straight for the player's home (south, as the enemy sees the map). Its choice decides whether it meets our push head on or toward a wing. |
| `M.resolve` | `map, dir, winner` | Updates the map after a battle pushed in `dir` ended with `winner` (1, 2, or 0 for a draw, which changes nothing). Returns the match result: false while it goes on, else the winning team. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `WING_OF` | Which wing the enemy comes at, given its push. Head on is straight. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `step_from` | `col, row, dir` | The neighbour one region away in a compass direction. Compass vectors are unit length; rounding the diagonals gives the corner neighbour. |
