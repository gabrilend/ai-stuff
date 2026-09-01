# Games That Creatures Play

A game is a small set of roles, a rule for swapping between them, and an ending.
It is not intelligence and it is not planning. It is a state machine shared by
two or more bodies, and the fact that it reads as play is a property of the
watcher rather than of the creatures.

## The shape of a game

Every game is one record, held by the game table, referencing its participants by
id and generation, exactly like [a duel](017-fencing.md) — which is itself a game
under this description, with two roles and a violent ending.

| Field | What it is |
| --- | --- |
| `kind` | which game |
| `participants` | body ids and their generations |
| `roles` | one small integer per participant |
| `clock` | how long it has been running |
| `state` | which phase of the game |

The `decide` pass asks a body's game, if it has one, what it wants; the game
answers with an intent. So a body in a game is steered by the game instead of by
its own wandering, and it is released back to itself when the game ends.

## Chase

Two roles: one is **it**, the other is not.

The one that is it heads for the other. The other heads away, preferring surfaces
out of sight. When they end up in the same cell, the roles swap and a short
`grace` interval runs during which neither may tag, so that the swap does not
immediately swap back.

Ends when the clock exceeds `chase_seconds`, or when the two are separated by
more than `give_up_distance`, or when either participant fails its generation
check.

The braided loops in the maze are what make this work at all. On a perfect maze
with no loops there is exactly one route between any two rooms, so a chase is a
straight line with a known outcome, and the pursued creature is cornered every
time. See [carving the maze](003-carving-the-maze.md) — the `braid` knob exists
for this.

## Hide and seek

One **seeker**, the rest **hiders**.

The seeker idles for `count_seconds`, facing a wall, while the hiders each run
the hiding search from [the habitat](019-dinosaurs-in-a-habitat.md). Then the
seeker wanders, checking sight on its cadence. A hider that is seen is out and
joins the seeker. Ends when everyone is found or when the clock runs out.

Nothing here knows it is playing hide and seek. There is a timer, a search for
surfaces without sightlines, and a rule that changes a role when a sight check
passes. The name is ours.

## Follow the leader

One **leader**, wandering. The others hold an errand to the surface the body in
front of them occupied a moment ago, which produces a line that snakes through
corridors behind the leader.

The trailing positions come from a small ring buffer of the leader's recent
stances rather than from each body pathfinding to a moving target — a moving
target means a path recomputed every time it moves, which is every step, which is
the pathfinder running constantly for a result that is thrown away.

## Why games are a table and not a subclass

Adding a game is adding a row and a function. The `decide` pass does not know how
many games there are, and no game can affect another. A game that turns out to be
boring is deleted by removing its row, and nothing else in the project mentions
it.

The alternative — a creature brain with a branch per game — grows a branch every
time, and every branch is reachable from every other, so removing one means
proving it was not depended upon.

## Related documents and tools

- [Dinosaurs in a habitat](019-dinosaurs-in-a-habitat.md)
- [Fencing](017-fencing.md) — a game with two roles and a worse ending
- [Carving the maze](003-carving-the-maze.md) — the loops these need
