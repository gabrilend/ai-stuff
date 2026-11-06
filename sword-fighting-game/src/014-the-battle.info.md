<!-- made by scripts/build-info-pages from the comments in 014-the-battle.lua; change the comments and rebuild, not this page -->
# 014-the-battle


One battle: the field, the two contingents, and the tick that runs every
rule in one fixed order. Nothing in the tick iterates a hash table, and
strikes are resolved in soldier-id order, so a seed and a script decide the
whole battle on every run and on every machine.

The battle is laid out in its own frame: the player's contingent always
deploys along the southern edge and pushes north. Which compass direction
that is on the campaign map is the campaign's business (016).

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.new` | `opts` | opts: config, catalogue, streams, region (name), enemy_wing ("straight", "left", "right"), perks = { [1] = list, [2] = list } of { name, be_affected }, person (true when a person drives the player's soldier). |
| `M.tick` | `battle, player_intent` | One fixed step, always in this order. `player_intent` is the person's intent for the player's soldier, or nil to let its mind drive it. |
| `M.lines_touched` | `battle` | Whether any two enemies have come within engage range: the moment the round drops into the front rank. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `COUNTERS` | The counters the receipt reads. Every one starts at zero; a name not here cannot be counted, so a typo in a counter is caught by the first test. |
| `WING` | How the enemy deploys, by how its push meets ours: head on, or toward a wing. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `new_counters` | nothing | (no comment in the source) |
| `deploy` | `battle, team, facing, front_y, shift` | Lays one contingent's battalions side by side, facing the enemy. |
| `pick_player` | `battle` | The player stands in the front rank of the middle battalion, left of centre. |
| `nearest_battalion` | `battle, b` | A battalion with nobody standing no longer draws anyone toward it. |
| `advance_one` | `battle, b, dt` | The origin wheels toward the nearest enemy battalion and walks on until it meets it; then it holds, and its soldiers fight. With no enemy battalion left standing it holds where it is. |
| `advance_formations` | `battle, dt` | (no comment in the source) |
| `check_break` | `battle` | A contingent with a quarter or fewer standing breaks; past the time limit the battle is a draw (outcome 0). |
| `face` | `battle, s, dt` | With a lock, the body turns toward it; without, toward its battalion's facing. |
| `take_intent` | `battle, s` | What the intent asks that is not movement: the guard, the U, a swing. |
| `count_down` | `s, dt` | (no comment in the source) |
