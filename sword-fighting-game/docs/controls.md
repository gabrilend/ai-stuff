# Controls

Every binding is a row in the keys table of src/001-config.def.lua and can be
changed in config.lua. The scripted-input options send the same key names
through the same handlers.

## First person (one soldier)

| Input | Action |
| --- | --- |
| W / S | step forward / backstep (backstep trips when fatigued) |
| A / D | sidestep left / right (one in four trips, while guarding) |
| left shift + direction | dodge: a quick step, never into an occupied cell |
| mouse | move the sword along its U (left arm, bend, right arm) |
| left click | swing from where the sword is: slash left, stab, slash right |
| space | overhead swing |
| right click (held) | guard (parry stance) |
| left alt (held) + mouse | look around freely instead of moving the sword |
| tab | leave the front rank: return to third person |

## Third person (the whole contingent)

| Input | Action |
| --- | --- |
| left click | throw a volley at range (range 3; 1-3 with the trained arc) |
| 1 / 2 / 3 | choose volley range (trained arc only) |
| right click (held) | raise the shield wall |
| W A S D | slide the commander's camera |
| mouse wheel | zoom |
| tab | drop into the front rank (once the lines have touched) |

## Command phase (between rounds)

| Input | Action |
| --- | --- |
| click a compass arrow, or the numpad / arrow keys | choose the push direction |
| click a perk card | choose this round's perk |
| Y / N | be one of the affected soldiers, or not, when asked |
| return | begin the round |

## Any time

| Input | Action |
| --- | --- |
| F12 | screenshot, filed into development-history/ |
| escape | quit (writes the goodbye receipt) |
