# 903 — Difficulty without cheating

| | |
| --- | --- |
| Phase | 9 — An Opponent |
| Blocked by | 901 |
| Blocks | 904 |
| Reads | [roadmap](../docs/015-roadmap.md) |
| Open questions | none |

## Current behavior

Nothing. The measuring bot (issue 901) is cheap, deterministic and dull on
purpose, and a person who played against it would learn its one route in a
match. It has exactly the access a person has — a snapshot in, commands out —
and that is the property this issue keeps.

## Intended behavior

**An opponent built to be played against, whose difficulty comes from decision
quality and from nothing else.** It gets no extra mass, no extra energy, no
faster construction, and no view of the field a person does not have; it reads
the same snapshot through the same function and its commands leave through the
same door. That is not discipline; it falls out of the design. There is no
path in the program by which a bot could be given more, short of writing one,
and this issue does not write one.

Difficulty is therefore **a row in a dispatch table** of decision styles, each
a different set of rules over the same situations the measuring bot reads:

- how far along a route it looks before committing — a low level draws
  straight lines, a high level walks the heightfield and draws a route that is
  seen from as little ground as possible
- whether it answers a scout's report at all, and how quickly
- whether it stacks anti-air on the ground its planes go defensive over
- whether it waits to place an energy building until a hydrocarbon is found
- how it weighs a ridge against a trough — the measuring bot always takes the
  trough; a hard opponent takes the ridge where the ridge sees the trough

The higher rows are the ones that use what the game's design offers: the
sightline, the shared timer, the report. A person who loses to the top row
should be able to say which dune it took and why that was right.

It is a different program from the measuring bot, in a different file, and it
is kept that way: a bot tuned to produce balance numbers wants to be cheap and
dull, and one tuned to be played against wants to be varied and occasionally
wrong in the way a person is wrong — which means it draws from its named
stream to choose among good moves rather than always the best one, at a rate
the row sets.

## Suggested implementation steps

1. Claim `the-opponent`, separate from `the-bot`, with the same export shape:
   `think(snapshot, team)` and a `LEVELS` table as data.
2. Write the route planner that walks the heightfield: for a candidate route,
   count the cells from which its points can be seen, using the sightline
   module through the snapshot's copy of the field, and prefer the route seen
   from least.
3. Write the rows as rule sets, sharing the snapshot readers from issue 901.
4. Write the "occasionally wrong" draw from the `opponent` stream, so that the
   same seed plays the same game, and a different seed plays a different one.
5. Add a line to `input/` naming the level, and hook the opponent into the
   headless runner behind it.
6. Test: the opponent behind team two beats the measuring bot behind team one
   at every level above the lowest, over a hundred seeds; and two runs of one
   seed are one hash.

## Related documents and tools

- [Roadmap](../docs/015-roadmap.md) — phase 9
- [The dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md)
  — what the route planner reads
- `tests/027-an-opponent.lua`

## Still open

- Whether "occasionally wrong" should be a draw among good moves, as written, or
  a delay — the opponent seeing the right move and acting on it a few ticks
  late. A delay is more like a person; a draw is easier to reason about.
- The question raised in issue 901 about whether a snapshot is ever narrowed to
  a team's own eyes applies doubly here: a hard opponent that knows the
  enemy's roster is not cheating by the program's rules, but a person may feel
  that it is.
