# Walking The Surface Graph

The little guys do not have velocities. They occupy a surface, they choose an
adjacent surface, and they take a fixed amount of time to get there. Everything
smooth about them is the renderer's doing.

## The step

A walking body holds three things beyond its stance: where it came from, where
it is going, and how far through the journey it is.

| Field | Meaning |
| --- | --- |
| `from_cell`, `from_layer` | the surface it left |
| `intent_cell`, `intent_layer` | the surface it is arriving at |
| `progress` | zero at the moment it left, one at the moment it arrives |

Each tick, `progress` advances by `speed × dt`. When it reaches one, the stance
becomes the destination, `progress` resets, and the body decides again.

The body's **drawn** position is the two surfaces interpolated by `progress`.
That interpolation is the entire smoothing, it happens in the renderer, and the
simulation never reads it. A body is either at one surface or at another; it is
never between them as far as anything that matters is concerned.

This is why the two spatial questions have simple answers. "Which cell is this
body in" is its stance, which is exactly one cell, always. "Who is near it" is a
lookup in that cell's bucket. A body with a continuous position would be in two
cells at once for half of every step, and every question about it would need a
tie-breaking rule.

## Vertical steps look wrong unless the arc is added

Interpolating a step up one layer in a straight line makes the body slide up a
diagonal, which reads as a body ascending an invisible ramp rather than climbing
a step. The fix is an arc: the interpolated height gets a small hump added,
peaking at the middle of the step.

A cosmetic hack, applied entirely in the renderer, worth mentioning only because
it is the kind of thing that gets deleted by somebody tidying up who does not
know why it is there — and then the little guys look wrong and nobody can say
what changed.

## Deciding where to go

The `decide` pass gives a walker one of a small set of intents, each of which is
a row in a table rather than a branch in a function:

| Intent | What it means |
| --- | --- |
| `wander` | pick an adjacent surface, weighted against turning around |
| `errand` | head for a specific distant surface, following a path |
| `idle` | stay put and do something else. See [idling](015-idling-and-being-idle-together.md). |
| `approach` | head for another body |
| `flee` | head away from another body |
| `engage` | a duel has started. See [fencing](017-fencing.md). |

Wandering is weighted against reversing because an unweighted random walk on a
graph spends most of its time going back and forth across the same two cells,
which looks broken rather than aimless. The weight is a number in the creature
table, and setting it to make reversal impossible is worse — a body in a dead end
must be able to turn around.

## Errands and how far a body will look

An errand needs a path, and a path needs a search. The search is A-star over the
surface graph, with the straight-line distance in cells plus the difference in
layers as the estimate.

Two things bound the cost:

**A path is computed once and stored**, as a list of surfaces the body walks
down. It is recomputed only when the destination changes or the stone does. A
body that pathfinds every tick is a body that costs a hundred times what it
should to do the same thing.

**The search gives up.** After `search_budget` surfaces examined, it stops and
returns nothing, and the body falls back to wandering — and *says so*, in the
headless report, as a count of abandoned searches. A search that quietly failed
and left a body standing still is a body that looks stuck for no reason, and the
count is how anybody finds out it is happening at all.

The component label from
[the movement rule](004-standing-somewhere-and-going-elsewhere.md) is checked
first. If the destination is in a different component, there is no path and the
search is never started. One comparison saves the entire budget.

## Bodies wider than one cell

A dinosaur occupies a square of cells rather than one. `striding` is the same
step, with the enterability check applied to every cell of the footprint at the
destination instead of one, and the stance being the footprint's centre.

Everything else is identical, which is the point of it being a separate row of
[the locomotion table](012-locomotion-is-a-dispatch-table.md) and not a flag: the
row shares the step machinery by calling it, not by being it.

## Related documents and tools

- [Standing somewhere and going elsewhere](004-standing-somewhere-and-going-elsewhere.md) — the four answers a step asks for
- [Locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md)
- [Idling and being idle together](015-idling-and-being-idle-together.md)
