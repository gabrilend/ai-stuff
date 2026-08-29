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
| The right number of towers, on both sides, matching each other | An absence — the site emission was once deleted by accident and every existing check passed, because they were all about sites that were there. |
| **Each lane carries the number of bodies abreast it says it does, and is the number of formation-widths across it says it is** | The two halves of a derivation drifting apart. How many walk abreast is declared and the width is the arithmetic that gives them room; either can be edited without the other, and the only symptom is that the game plays differently. |
| The formation walking a lane fits inside it | A multiple that was right for a side lane's formation and wrong for the centre's, which is wider. |
| The centre lane holds three formations abreast | The thing the centre lane is *for*. During a challenge all three lanes' waves fight in the middle standing side by side; a centre that cannot hold them has stopped being for anything. |
| **Every milestone lands on a zone boundary** | The reason zones were built as divisions of a milestone interval rather than as a count across the lane. If it stops being true, the towers and the push measure have quietly come apart, and the symptom is a frontline reported somewhere it is not. |
| The lane's two zone arrays agree | They hold the same numbers and are kept separate so either can be moved. This is what tells somebody who moved one that they did. |
| The zones cover the lane, rising, end to end | An off-by-one in the loop that builds them. |

## Two checks that assert an absence, and why they had to

Most of the table above inspects what the builder produced. Two of them instead
state what *should* be there and complain if it is not, and both were added after
something disappeared and nothing noticed.

**The tower count.** The site emission was deleted during a refactor and everything
still worked: the map built, the validator passed, a match ran for two hundred
seconds with no towers on it. Every check was about sites that existed rather than
sites that should. A validator that only checks what it finds cannot notice an
absence, and an absence is exactly what a refactor produces.

**The lane widths.** How many bodies stand abreast is the lane's width divided by
the formation module's file spacing — two numbers in two files that can be edited
apart. When they were, a side lane went from three abreast to two and the only
symptom was that the game played differently. So the shape parameters now write down
how many bodies each lane is *meant* to carry, and this asks the formation module
whether the widths still deliver it. It borrows the arithmetic rather than repeating
it: a validator holding its own copy of a rule can only check that the copy agrees
with itself.

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
