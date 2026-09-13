# 604 — The energy menu is always on screen

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 302, 601 |
| Blocks | 803 |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

Nothing. The energy menu is designed in
[territory, mass, and energy](../docs/005-territory-mass-and-energy.md) as four
assignment levels, and issue 302 builds the `energy-menu` file whose `set_level`
is a command through the door. No viewer shows it, and the roster and territory
percentage are numbers no window reads yet.

## Intended behavior

**Four buttons, always on screen, and never a fifth.** The menu is not a lens.
It is the one piece of the viewer that is also an input, it sits in a fixed
strip of the window that no lens may cover, and pressing a button issues one
command: set this team's level to this button's level. That is the whole
energy economy from the player's side, and the strip is its whole surface.

What a button shows is read from the snapshot, not from the click. The button
for the level the snapshot says is current is drawn lit. A button that has been
pressed but whose level the snapshot does not yet show — the command is queued
for a later tick, as every command is — is drawn as **pending**, distinct from
lit, until the snapshot catches up. The click is intent; the snapshot is truth;
and the strip never pretends the second is the first. A refusal from the door
is drawn on the button that was pressed, in words, and stays until the next
press.

**Beside the buttons, the roster and the ground.** Three readouts, always
visible, because the economy is the game:

- builders: how many, and one bar for the whole roster's health, from the
  snapshot's roster arrays;
- engineers: the same, with the count on energy duty marked off from the count
  on build power, so that the button's consequence is visible next to it;
- territory: the team's percentage of the land, and beside it the same number
  for the enemy, because the difference is what the thorns and the infirmary
  are about.

Mass and energy totals, and their income per tick, sit under the readouts as
two small numbers with an arrow for rising or falling. A build that has stalled
for want of one of them is named in the strip, because a stall that is not
shown is a mystery the player discovers three factories later.

## Suggested implementation steps

1. Write the strip as a numbered source file with a companion: a draw function
   taking the snapshot pair and the strip's rectangle, and a press function
   taking a screen point and returning the command to issue, or nothing.
2. Read the levels from issue 302's `LEVELS` table rather than counting to four
   here, so that the menu and the rule cannot disagree about how many buttons
   there are — and so that the day somebody adds a fifth level, the strip grows
   a fifth button and the desire file's wish is visibly broken rather than
   quietly kept.
3. Draw each button's state from a table of three: lit, pending, plain. Pending
   is entered on press and left when the snapshot's level equals the button's
   or a refusal arrives.
4. Draw the roster from the snapshot's roster arrays (issue 304), the territory
   from issue 112's percentage as carried in the snapshot, and the totals and
   incomes from the economy's fields (issue 301, issue 303).
5. Route refusals for level commands to the button that issued them (issue
   601's refusal path).
6. The test: pressing a button yields exactly one command with the right level;
   the strip's draw takes a snapshot and a rectangle and nothing else; a
   snapshot with a level not in the table is an error, not an unlit strip.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the always-open menu.
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the
  four levels and what they trade.
- Issue 302 (the levels and the command), issue 304 (the roster), issue 112
  (territory as a percentage), issue 601 (the snapshot pair and the refusal
  path), issue 803 (the same menu on the handheld's buttons).
- `tests/024-watching-it-happen.lua`.

## Still open

- Whether the enemy's territory percentage should be shown at all, or only
  one's own. The fog in this game is made of sightlines, and the enemy's total
  ground is not something any unit can see. The working choice is to show it,
  and the question is written down so that it is a choice.
