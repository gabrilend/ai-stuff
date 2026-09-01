# 033-moving

Four answers to whether a body may move, and the component labels.

Read this page rather than the source, and read
[standing somewhere and going elsewhere](../docs/004-standing-somewhere-and-going-elsewhere.md)
before either.

## What it is for

**One function, called by every kind of creature.** A dinosaur, a ball and a
stone golem get the same answer to the same question, because the maze has to
mean one thing.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `step(Stone, store, cell, layer, direction, drop_limit, body_height)` | | one of four answers, plus the destination cell and layer |
| `pack(store, cell, layer)` / `unpack(store, packed)` | | a stance as one integer, so a visited set is a flat array rather than a table of tables |
| `label_surfaces(Stone, store)` | | which connected piece each surface belongs to; also the count and the sizes |
| `count_ledges(Stone, store, label, main, drop_limit)` | | steps down a body cannot climb straight back, over the reachable maze only |
| `is_pit(Stone, store, cell, layer, drop_limit)` | | whether a body standing here could leave at all |
| `DIRECTIONS`, `CLIMB_LIMIT`, `BLOCKED`, `FLAT`, `STEP_UP`, `STEP_DOWN`, `ANSWER_NAMES` | | |

## The four answers

| Answer | When |
| --- | --- |
| `FLAT` | the neighbour has a surface at the same layer |
| `STEP_UP` | the neighbour has a surface one layer up, with headroom |
| `STEP_DOWN` | the highest surface below is within the asker's `drop_limit` |
| `BLOCKED` | anything else |

`CLIMB_LIMIT` is one and is not a knob. `drop_limit` is per creature, because
falling is not climbing: a body may go down further than it can come up.

`body_height` is checked against headroom even though nothing in the project has
a ceiling over it yet, so it has never once returned anything but the right
answer. It is written now because a check that was never written is far harder to
add than one that was written and always passed — and
[the delve](../docs/021-the-delve.md) is a dungeon.

## Labels are mutual, not one-way

`label_surfaces` joins two surfaces when a body can step from **either to the
other**, which reduces to their layers differing by no more than the climb limit.

One-way was tried and is wrong in a way worth recording. A body may drop two
layers and climb one, so a pit is reachable from the terrace above it and the
terrace is not reachable from the pit; a flood fill over that relation gives
different answers depending on which surface it started from. Those are not
components, they are the result of an arbitrary choice, and a validator built on
them reports a maze as broken or whole depending on array order.

Falling is not travel. Where it strips a body of its way back is counted
separately, by `count_ledges`.

## The graph is never stored

There is no adjacency list anywhere in this project. Neighbours come out of four
columns and a handful of bit operations, which is cheaper than the cache miss
reading a stored list would have cost — and a stored graph would be a second copy
of the maze to invalidate every time a golem walks through a wall.
