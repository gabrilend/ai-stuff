# 107 — Four Answers To "May I Move"

| | |
| --- | --- |
| Phase | 1 — The Stone |
| Blocked by | 101, 102 |
| Blocks | 108, 303, 306, 401, 403, 601, 702 |
| Reads | [standing somewhere and going elsewhere](../../docs/004-standing-somewhere-and-going-elsewhere.md) |
| Open questions | none |

## Current behavior

One function, four answers, called by everything. Component labels come from
`label_surfaces`.

The labelling uses **mutual** reachability, not one-way. One-way was tried and is
not well defined: a body may drop two layers and climb one, so a pit is reachable
from the terrace above and the terrace is not reachable from the pit, and a flood
fill over that relation gives different answers depending on which surface it
started from. Those are not components, they are the result of an arbitrary
choice, and a validator built on them reports a maze as broken or whole depending
on array order. Falling is not travel; where it strips a body of its way back is
counted separately by `count_ledges`.

## Intended behavior

**One function**, called by every kind of creature, that takes a stance and a
compass direction and returns exactly one of four answers.

| Answer | When |
| --- | --- |
| flat | the neighbour has a surface at the same layer |
| step up | the neighbour has a surface at `layer + 1` and there is headroom |
| step down | the neighbour's highest surface below is within the asker's `drop_limit` |
| blocked | anything else |

A dinosaur, a ball, and a stone golem get the same answer to the same question.
It is not reimplemented per creature, because the maze has to mean one thing.

The two limits are different numbers on purpose. `climb_limit` is **one layer**
and is not a knob — a wall is two layers above its corridor precisely because one
is climbable and two is not, so raising it does not make bodies more agile, it
deletes every wall in the maze. `drop_limit` is **per creature**, because falling
is not climbing: a body may go down further than it can come up, which is what
lets a maze have pits that collect bodies.

The **headroom** check is part of the answer even though nothing today has a
ceiling over it. It will always pass until [the delve](../../docs/021-the-delve.md),
and it is written now because a check that was never written is far harder to add
than one that was written and passed.

Also in this issue: **component labels**. One small integer per surface saying
which connected piece it belongs to, computed once after generation. It answers
"can this body possibly reach that one" in a comparison instead of a search, and
it is what issue 108 asserts is uniform.

The graph is **not stored**. There is no adjacency list. Neighbours are computed
from four columns and a few bit operations, which is cheaper than the cache miss
a stored list would cost, and a stored graph would be a second copy of the maze
to invalidate every time a golem changes it.

## Suggested implementation steps

1. Write `step(store, cell, layer, direction, drop_limit)` returning the answer
   and the destination layer. Fold it. Comment each of the four branches with
   what that path means for the body, not with what the code does.
2. Write the direction table — four entries of `{dx, dy}` — as a table indexed by
   direction rather than as four cases, so that iterating directions is a loop.
3. Write the headroom check as a call into issue 102's counter and nothing more.
4. Write the component labelling: flood fill over surfaces using this function,
   with `drop_limit` set to the largest any creature has, so the labels are
   optimistic. A label saying two surfaces might be connected is useful; one
   saying they are not, when some creature can make the jump, is a lie.
5. Store labels in one array indexed by cell and layer packed together.
6. Test: for a maze of random columns, the fast answer equals a slow reference
   built from a table of booleans. For a generated maze, every surface has a
   label and the labels partition the surfaces.

## Related documents and tools

- [Standing somewhere and going elsewhere](../../docs/004-standing-somewhere-and-going-elsewhere.md)
- [Locomotion is a dispatch table](../../docs/012-locomotion-is-a-dispatch-table.md) — who calls this and who does not
