# 031-map-validator

Refuses a malformed path graph, once, at load.

## What it is for

This is where every "is this field really filled in?" question in the project goes
to be asked. The movement loop runs a thousand times a tick and has **no nil checks
in it**; that is only safe because this file has already established there is
nothing there that could be nil. Every check here is a question the simulation is
thereby allowed to stop asking.

**It refuses rather than repairs.** A validator that quietly patched up a bad map
would mean the map builder has a bug nobody will ever be told about, surfacing
three phases later as soldiers walking into the sea.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `check(map, parameters)` | map, parameter record | An array of complaints. Empty means sound. |
| `insist(map, parameters)` | map, parameter record | The map, or stops the program naming **every** problem. |

`insist` names every problem rather than the first, because one bad map usually
produces a family of related complaints and seeing the family is what identifies
the cause.

## What it checks

| Check | Catches |
| --- | --- |
| Every node has a neighbour | A lane emitted and never joined. |
| Every joining is mutual | A body that can walk somewhere it can never walk back from — which reads as the body being stuck, not as a map bug. |
| Each lane runs library to library | A path built backwards or truncated. |
| Each path step is a real graph edge | A body following the path array stepping between nodes that are not joined, so its position jumps. |
| All nine milestones present, and on the node that claims them | Milestone arithmetic reading the wrong place. |
| Exactly one junction per lane, and it is milestone 4 | The builder's central assumption quietly broken. |
| **The map is a mirror of itself** | The one that matters most. |
| The fraction table is symmetric, and milestone 4 is at 0.5 | A bad shape parameter, reported as a bad parameter rather than as a crooked map. |
| Every structure site stands on the right kind of node | A tower placed on plain ground. |
| Every node reachable from team 1's library | A connector built between the wrong pair of junctions. |

## The mirror check, and why it is first among equals

The mirror is the reflection about the junction diagonal, which swaps x and y.
Under it **every lane maps onto itself with its milestones reversed**, because each
lane's bend sits on that diagonal and is therefore its own reflection.

An asymmetric map hands one team a shorter walk, and nothing else in the project
would ever notice. Players would simply lose more often on one side and never learn
why.

## A note on tolerance

Comparisons use a tolerance of 0.0001 paces rather than equality, because the
mirror checks compare doubles that went through different arithmetic to reach the
same place.
