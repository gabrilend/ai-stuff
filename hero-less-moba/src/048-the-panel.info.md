# 048-the-panel

The board down the side of the screen: what the team holds, where it is sitting, and
everything the game has refused to do.

## What it is for

The screen's job, in order of how much a player looks at it: the three lanes and where
the frontlines are; the chest; the slots; the phase; the refusals. The lanes are
[the renderer's](047-the-renderer.info.md) job. Everything else is this file's.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load(renderer)` | | — Fonts, the hot-region list, the refusal log. |
| `draw(world, camera, frame, team_id, held_kind, mouse_x, mouse_y, speed, paused)` | | — The whole panel. |
| `hit_test(x, y)` | | What is under a screen point, or nil. |
| `note_refusal(text)` | | — Adds a line to the refusal log. |
| `panel_left()` | | Where the panel starts, so the viewer knows which clicks belong to the map. |

## An upgrade doing nothing should be visually annoying

Unplaced upgrades are drawn large, bright, and at the top, with the count in the team's
own colour — because an upgrade in the chest is a decision nobody has made yet and the
interface should say so. A chest nobody is emptying is the single most common way a
team throws a match it was winning.

The moment it is placed it becomes a small pip in a lane row. Quieter, because now it
is working.

## The hot-region list

Everything drawn that can be clicked records its rectangle as it is drawn, and
`hit_test` walks that list **backwards** so whatever was drawn last — and is therefore
on top — answers.

One layout, two readers, no chance of them disagreeing about where a chip is.

| Kind | Means |
| --- | --- |
| `chest_chip` | An unplaced upgrade. Pick it up. |
| `slot_pip` | A placed upgrade. Click to recall it. |
| `drop` | A lane's bodies or stone slot. Drop onto it. |

## A lane row

The lane's name, its pressure track, and its **two** slots — bodies and stone — as
separate drop targets, because they are genuinely different purchases.

Stone and soldiers are not symmetric investments and the panel does not pretend they
are. A lane upgrade makes every body you spawn into that lane stronger, and the enemy
reduces its value by killing those bodies faster than you make them. A stone upgrade
makes your towers stronger and **there is no play the enemy can make that reduces its
value at all** — the only thing in the whole game that can dislodge it is a siege-surge.

The pressure track is nine cells from this team's end to the enemy's, in the two teams'
colours. The same read as the map's push bars, in a place the eye is already looking.

## Every refusal is loud

Refusals arrive at the bottom, in the colour of a warning, and fade over several
seconds — long enough to read without looking away from the lane you were watching.
Only the last handful are kept; a refusal older than the ones below it has already been
read or already been missed.

## One team's board and never the other's

On a networked match the enemy's chest is not on the machine at all. The prototype lets
you switch which team you are watching, which a real match would never offer — so it is
**marked on screen as a development affordance**, and nobody should mistake it for a
feature.
