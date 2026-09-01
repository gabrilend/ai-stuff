# 048-the-report

The numbers a run produces, and how they are printed.

Read this page rather than the source.

## What it is for

A table of named numbers rather than printed prose, because the headless runner,
the terminal viewer, the overnight sweep and the phase demo all consume it — and
four things reading four different formats is four things that disagree about
what a run did.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `gather(world)` | | everything worth knowing, as one table |
| `describe(r, pass_time)` | | it as lines of text |
| `as_table_row(r)` | | one tab-separated line, for the sweep |
| `table_header()` | | the header for those lines |
| `say_goodbye(root, r)` | | writes `output/goodbye` |

## What is measured, and why each one is worth a number

| | |
| --- | --- |
| never moved | one is a stuck body; forty is a broken rule |
| distance, **per kind** | a kind whose number collapses has stopped working, and in a window full of kinds that still work it is invisible |
| layers visited | whether the staircases are used at all, or everybody is milling about on the ground |
| spawns skipped | a maze whose spawn points are all blocked, arriving as a number rather than as an aquarium that slowly empties |
| largest bucket | a number that climbs means the meet pass is going quadratic, on the tick where things are already going badly |
| retired at rest | that this is a circulation rather than a run with an end |
| per-pass time | where the time goes, without a profiler |

Per kind rather than in total is the one that matters most. A total distance that
looks healthy can hide a whole locomotion row that stopped moving anything.

## Goodbye

The last thing a run does is write `output/goodbye`, with the report in it.
