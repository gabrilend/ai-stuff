# 604 — A Game Is Roles And An Ending

| | |
| --- | --- |
| Phase | 6 — The Habitat |
| Blocked by | 103, 403, 601, 602, 603 |
| Blocks | 707 |
| Reads | [games that creatures play](../docs/020-games-that-creatures-play.md) |
| Open questions | none |

## Current behavior

Creatures wander and hide and nothing happens between more than two of them.

## Intended behavior

A game is a small set of roles, a rule for swapping between them, and an ending.
It is not intelligence and it is not planning — the fact that it reads as play is
a property of the watcher.

One record per game, participants by id and generation, exactly like
[a duel](completed/501-a-duel-is-a-record-not-two-flags.md), which is itself a game under
this description with two roles and a violent ending. The decide pass asks a
body's game what it wants and the game answers with an intent, so a body in a
game is steered by the game and released back to itself when it ends.

Three games, detailed in
[the document](../docs/020-games-that-creatures-play.md):

- **Chase** — one is it, roles swap on contact, with a `grace` interval so the
  swap does not immediately swap back. **Requires the braided loops** from issue
  105: on a maze with no loops there is one route between any two rooms, so the
  pursued is cornered every time and there is no game.
- **Hide and seek** — a seeker counts facing a wall while hiders run issue 603;
  a hider that is seen joins the seeker.
- **Follow the leader** — trailing bodies head for surfaces the body ahead
  occupied a moment ago, taken from **a small ring buffer of the leader's recent
  stances** rather than by pathfinding to a moving target. A moving target means
  a path recomputed every time it moves, which is every step, which is the
  pathfinder running constantly for a result thrown away.

A table, not a subclass hierarchy. Adding a game is a row and a function; the
decide pass does not know how many there are; a boring game is deleted by
removing its row and nothing else mentions it.

## Suggested implementation steps

1. Write the game store as flat arrays with a free list, like the duel store, and
   generalise the duel into a row of it if that turns out to be clean — but not
   before, because a generalisation with one instance is a guess.
2. Write the game table: `kind`, `start`, `decide`, `tick`, `ended`.
3. Write the three games.
4. Write formation: a game starts when enough willing participants are in one
   neighbourhood, through the meet pass.
5. Count games started, ended by each reason, and mean duration.
6. Test: a chase on a maze with `braid` at zero ends by cornering every time; the
   same chase with braiding runs to the clock. That contrast is the clearest
   demonstration in the project that a generator knob decides a behaviour.

## Related documents and tools

- [Games that creatures play](../docs/020-games-that-creatures-play.md)
- [The maze is a spanning tree over rooms](completed/105-the-maze-is-a-spanning-tree-over-rooms.md)
