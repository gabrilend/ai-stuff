# 047-command-truck

The one unit a command moves: it walks where it is pointed, launches its plane
on a compass heading, and dies in one shell.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The command truck is a unit like any other: a land row in the unit arrays, with
the catalogue's health of one tank shell, so it dies to one hit with no code
here. What sets it apart is the command door (`commands`), where `move` and
`launch` are the two verbs that name a unit, and both name a truck. The door
first asks `owned_by`: the row must be a live truck of the commanding team.

**Moving** is being handed a fresh one-leg pattern: from where the truck stands
to the destination, appended to the world's pattern store, with the truck's
`pattern` and `leg` rewritten. The move pass (issue 204) walks it like any
pattern and holds the truck at its end; nothing there knows the truck is
special. A second move replaces the first. The destination must be a land cell
on the field.

**Launching** puts the truck's plane in the air: a unit of kind `PLANE` (the
helicopter, A8's working ruling of one plane that scouts and shoots) spawned at
the truck, for the truck's team, on the `heading` mission, with its goal the
point where the heading leaves the field. Headings are compass degrees: nought
is north, up the picture toward row zero, and ninety is east. What the plane
then does is issue 406's.

A launch is allowed by a pair, as everything periodic is: the world's launch
counter, `world.launch`, fires once a `launch_seconds` (a rule), and each team
holds `launch_at`, the increment from which its truck may launch again. A launch
writes the counter's next increment there. The pair lives in the team arrays,
not the unit row, because there is one truck per player and every tank would
otherwise carry a column of zeros. A launch too soon is refused, naming the tick
the next one is allowed (`next_launch_tick`). A world with no room for the plane
refuses the launch rather than failing mid-tick.

`trucks_alive` counts a team's live trucks, for the match's ending rule (A2's
working ruling: a team with none has lost).

The refusals the viewer shows: "is not a command truck", "is not your truck",
"is not a land cell", "still reloading its plane; the next launch is allowed at
tick N", and "no room for another unit".

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `move(world, id, x, y)` | a world; a truck; a position | nothing, or a refusal |
| `launch(world, id, heading)` | a world; a truck; compass degrees | nothing, or a refusal |
| `trucks_alive(world, team)` | a world; a team | how many live trucks it has |
| `owned_by(world, id, team)` | a world; a row; a team | nothing when the row is that team's live truck, or why not |
| `next_launch_tick(world, team)` | a world; a team | the tick from which its truck may launch again |
| `KIND`, `PLANE` | | `"command-truck"`, and the kind it launches, `"helicopter"` |
| `MISSIONS`, `MISSION` | | the plane's missions in the truck document's order (`heading`, `hunting`, `striking`, `returning`), and each name's number, which a plane row's `mission` holds |

## Data structures it owns

None of its own. It appends to `world.pattern`, writes a truck's `pattern`,
`leg` and `waited`, a plane's `mission`, `goal_x` and `goal_y`, and the team's
`launch_at`, and reads the launch counter `world.launch`.
