# 035-targeting

What a body decides to hit, and the grid that makes deciding affordable.

## What it is for

The ranking, cheapest test first:

1. an enemy soldier **already attacking me**
2. the **lowest-health** enemy soldier within acquisition range
3. an enemy **structure** within weapon range
4. nothing — keep walking

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `make_grid(world)` | | The spatial grid, allocated once. |
| `rebuild_grid(world)` | | — Empties every bucket and drops every living body back in. |
| `for_each_near(world, x, y, radius, visit)` | | — Calls `visit(id)` for every living body in range. |
| `choose(world, id)` | | — Runs the whole ranking for one body. |
| `target_is_alive(world, id)` | | Whether the stored target is still the body it thought it was. |
| `sweep_attackers(world)` | | — Rebuilds "who is swinging at me" and `incoming_dps`. |
| `hostile(a, b)` | two team numbers | Whether they are enemies. |

## Lowest health, not nearest

The most consequential line in the file. A rank that spreads its damage across
everything in front of it kills nothing and dies anyway; a rank that concentrates
removes an enemy from the fight and lowers the incoming damage for everybody behind
it. **Focus is how a smaller force beats a larger one**, and this design gives a
player no way to arrange it by hand — so the brain has to do it.

Structures rank below soldiers deliberately. A soldier that walks past a defended
tower to chew on the tower is a soldier that dies for free, and a frontline made of
those never moves.

Rule 1 outranks rule 2 on purpose: a body that ignores whoever is hitting it in
favour of a wounded target further away turns its back on a fight it is already in,
and two bodies doing that walk past each other swinging at strangers.

## The grid

Every body asking every other body how far away it is would be a million distance
checks a tick. Instead the map is cut into square cells, every living body is
dropped into its cell once per tick, and a query reads the ring of cells around it.

**Rebuilt from scratch every tick** rather than maintained incrementally. A grid
updated as bodies move is a grid that is wrong the first time somebody forgets to
update it, and being wrong looks like soldiers ignoring an enemy standing next to
them — the hardest possible bug to attribute.

**The ring is sized from the radius asked for**, not fixed at three by three. A
body's acquisition range is not a constant: a Longbow adds to it, Longbows stack,
and a body carrying two of them reaches further than the cell size. An earlier
version refused any radius wider than one cell — the refusal was right to exist, but
refusing was the wrong answer to a question the upgrade table is entitled to ask.

The buckets are **truncated rather than replaced**, so a match allocates its grid
once and never allocates for it again. Replacing them would produce a few thousand
short-lived tables a second, which turns a smooth frame rate into a periodic hitch.

## Ties, and why they are broken carefully

Exact ties use **reservoir sampling** from the team's own tie stream: the nth
equally-good candidate replaces the incumbent with probability 1/n. That gives a
uniform choice among the tied while advancing the stream a **fixed** number of times,
which is what keeps a replay reproducible.

## Why `sweep_attackers` rebuilds rather than updates

A body that changes target has to *decrement* the old one's incoming figure, and a
decrement that gets missed leaves a body permanently believing it is under fire with
nothing to correct it. A full rebuild cannot drift.

## The generation check

`target_is_alive` compares the target's generation against the one stored when it
was chosen. Without it, a body whose target died would keep swinging at whoever
moved into that slot next — possibly a friend, possibly across the map — and the
symptom would be a soldier attacking nothing at all.
