# 035-commands

The one door every player action comes through.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Every player action is a command, and there is one way in (`queue`) and one way a
command takes effect (`apply_due`, the tick's first row). Nothing takes effect the
instant it is issued, so a command from another machine that arrives before its
tick is indistinguishable from one issued here.

A command the door will not take is a **named refusal**: returned as a sentence
and written into the world's refusal ring, for a viewer to show where it
happened. A verb may refuse when it is applied, too, and that goes into the same
ring. Refusals are never repaired.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `queue(world, command)` | a world; a command table | nothing when taken; a refusal sentence otherwise |
| `apply_due(world)` | a world | how many commands stamped for this tick were applied, in the order queued; each leaves the queue. Raises if a command for an earlier tick is still queued: a tick ran without the door. |
| `refusals(world)` | a world | the ring's refusals, oldest first, each `{tick, team, verb, reason}` (`verb` empty for an unknown one) |
| `unpack(world, row)` | a world; a queue row | the command table that row was queued from |
| `VERBS` | | verb name to apply function `(world, command)`, returning nothing or a refusal |
| `ARGUMENTS` | | verb name to the list of its argument names, in slot order |
| `NAMES`, `NUMBER` | | the verbs sorted by name, and each name's number in the world's arrays |

The command table: `verb` (a name), `tick` (a whole number, not before the
world's), `team` (1 to the number of teams), `player` (a whole number, or absent
for zero), and each argument the verb names, as a number.

The refusals, in the order they are asked:

- no verb by that name;
- a tick that is not a whole number, or that has already run;
- a team outside the match;
- a player that is not a whole number;
- an argument the verb names that is missing or not a number;
- a full queue.

## Data structures it owns

The verbs:

| Verb | Arguments | Does |
| --- | --- | --- |
| `noop` | none | nothing; a lockstep batch may be empty |
| `set-energy-level` | `level` | presses one of the energy menu's four buttons for the team through `energy-menu.set_level` (issue 302); refuses any other button by number, with the menu's reason |
| `move` | `truck`, `x`, `y` | points the team's command truck at a land cell (`command-truck.move`, issue 210); refuses a row that is not the team's truck, and a cell that is not land |
| `launch` | `truck`, `heading` | launches the team's truck's plane on a compass heading in degrees from north (`command-truck.launch`, issue 210); refuses a row that is not the team's truck, and a plane still reloading, naming the tick the next launch is allowed |

The queue and the ring are groups in the world's layout (`command`, a queue, and
`refusal`, a ring); see the world's companion for their fields. The verb is
stored as its number, its place in the sorted list of names; logs and refusals
carry the name.
