# 045-terminal-viewer

The world as text.

## What it is for

Not a stepping stone to be discarded now that there is a real window. It is kept,
permanently, for four reasons: it is faster to debug in, it works over a connection
where nothing graphical does, its output can be piped to a file and diffed against
yesterday's, and — the one that matters most — it keeps the viewing layer honest by
existing as a **second consumer of the same snapshots**.

Two viewers means neither one can quietly become part of the simulation. The moment
somebody moves a decision into the graphical viewer, this one starts disagreeing with
it, and the disagreement is the alarm.

It reads snapshots. It writes nothing. Exactly like the other one.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `draw(world, frame, team_id)` | | The whole text view, as a string. |
| `draw_field(world, frame, width, height)` | | The map and everything on it. |
| `draw_lanes(world, frame)` | | The lane-pressure read, as three bars. |
| `draw_chest(world, frame, team_id)` | | One team's chest and slots. |

## The characters

| | Team 1 | Team 2 |
| --- | --- | --- |
| wave unit | `o` | `x` |
| hero | `H` | `X` |
| guard | `g` | `q` |
| tower | `T` | `Y` |
| library | `L` | `R` |

Plus `.` for lane ground, `,` for a connector, `_` for rubble, and `M` for a challenge
monster, which is on nobody's team.

The connector gets its own mark because it is the only ground in the game that belongs
to no lane, and a reader who cannot tell it apart cannot see why the middle is a place
a body can leave.

## The lane bars

One character per milestone, 0 through 8, read from team 1's end. `=` is team 1's
reach, `#` is team 2's, `*` is ground both claim, and a space is ground neither holds.

Drawn from **push depth** rather than from anything geometric, because push depth is
what the simulation actually runs on. A lane where the enemy sits one pace past your
first tower is in less trouble than one where they are inside your base, even though
the base is physically nearer.

## Layering

Ground, then stone, then bodies — later plots win. So a soldier standing on a tower is
drawn as a soldier, which is the thing that is about to change.

## One team's chest, never the other's

The enemy's chest is not drawn, ever, and on a networked match it would not be in the
frame at all.
