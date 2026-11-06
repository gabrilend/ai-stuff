<!-- made by scripts/build-info-pages from the comments in 015-perks.lua; change the comments and rebuild, not this page -->
# 015-perks


Perks taken in the command phase, laid on a contingent when its battle is
set up. Each perk names an effect, and the effects are rows in a table;
a new kind of perk is a new row, plus a catalogue entry that names it.

A perk that affects "a certain amount of guys" converts soldiers from the
back ranks first. The player always chooses whether to be one of them; if
the perk converts nobody of the player's kind, the player is just a normal
soldier and is not asked.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `EFFECTS.convert_units` | `battle, team, perk, choice` | The player first if they chose to be affected, then from the back ranks. |
| `EFFECTS.swap_weapon` | `battle, team, perk` | Only base swordsmen trade weapons; converted units keep their own. |
| `EFFECTS.add_trait` | `battle, team, perk` | (no comment in the source) |
| `EFFECTS.add_armor` | `battle, team, perk` | (no comment in the source) |
| `EFFECTS.thicken` | `battle, team` | (no comment in the source) |
| `EFFECTS.unlock_ranges` | `battle, team` | (no comment in the source) |
| `EFFECTS.crit_chance` | `battle, team, perk` | (no comment in the source) |
| `M.apply` | `battle, team, taken` | `taken` is the list of { name = perk name, be_affected = boolean } in the order the perks were picked. An unknown perk or effect is an error. |
| `M.times_taken` | `taken, name` | (no comment in the source) |
| `M.offer` | `catalogue, taken, stream, count` | The perk cards for a command phase: drawn without repeats from the perks this side has not used up. |
| `M.asks_player` | `catalogue, name` | Whether a perk asks the player "be one of them?": only the ones that convert a number of soldiers. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `EFFECTS` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `base_swordsmen` | `battle, team` | The soldiers a conversion may take: base swordsmen of the team, back ranks first, then by id, so the same perk always takes the same soldiers. |
| `each_soldier` | `battle, team, fn` | (no comment in the source) |
