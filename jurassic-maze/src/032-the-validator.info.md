# 032-the-validator

Refuses a broken maze and counts what is merely interesting.

Read this page rather than the source.

## What it is for

Every generated maze comes through here before anything else sees it, and its
findings split into two kinds. **A warning is an error here**: anything genuinely
acceptable is *counted*, which is a number somebody can compare against last
week's, rather than a message in a log that is ignored the first time and
invisible the second.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `validate(root, store, params, report)` | | the report, filled in. **Raises** on anything that makes the maze not a maze. |
| `describe(report)` | a report | it as lines of text |

## What raises

| | Because |
| --- | --- |
| a column with a hole in it | the generator makes none, so something else did. This check takes a flag rather than being deleted when a golem starts making them in phase seven. |
| a floor cell not standing on its own height | the height field and the stone have gone out of step |
| a rim cell that is floor | the rim is the only thing between a body that has gone wrong and an array index that is not there |
| the floor in more than one mutually reachable piece | bodies pile up in whichever piece they spawned in, and from a camera two hundred cells away that looks exactly like a maze working |

## What it counts

`surfaces`, `floor_cells`, `surface_pieces`, `wall_top_pieces`, `pits`,
`ledges`, `diameter`, `fill_fraction`.

Two of those are worth explaining.

**`wall_top_pieces`** is around a thousand on any maze and always will be. Every
wall top is a surface, and a wall top surrounded by taller and shorter walls is a
piece of one cell. A wall you can climb onto is not a wall.

**`diameter`** is not a correctness question at all. It is the number that says
whether the maze is interesting: one whose longest path is short is mostly plaza,
and no amount of looking at a screenshot says that as quickly as one integer.
Two breadth-first sweeps, which is exact on a tree and an underestimate on a
graph with cycles — close enough for a number that exists to be compared against
itself.
