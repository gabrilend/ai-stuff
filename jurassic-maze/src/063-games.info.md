# 063-games

Roles, a rule for swapping between them, and an ending. Nothing knows it is
playing.

Read this page rather than the source, and read
[games that creatures play](../docs/020-games-that-creatures-play.md) before
either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(...)` | | at world creation |
| `new_store(capacity)` | | the game store |
| `begin(world, kind, players)` | | a game, or nil |
| `maybe_start(world, bodies, a, b)` | | the meet-table entry; sometimes a game |
| `decide(world, bodies, id, kind)` | | what a body in a game does |
| `flee(world, bodies, id, kind, from_id)` | | away from something |
| `pass(world, dt)` | | clocks, role swaps and endings |
| `finish(world, g)` | | one action |
| `CHASE`, `HIDE`, `FOLLOW`, `NAMES`, `MAX_PLAYERS` | | |

## The three games

**Chase** — two players, one is it. It heads for the other; the other looks for
cover, and runs if there is none. On contact the roles swap, with a grace
interval so they do not swap back on the next tick while the two of them are
still standing next to each other.

**Hide and seek** — a seeker counts, facing a wall; the hiders find cover once
and then stop asking. A hider the seeker can see is found and joins the seeking.

**Follow the leader** — the followers head for surfaces the leader occupied a
moment ago, taken from a small ring of its recent stances. Pathfinding to a
*moving* target means recomputing every time it moves, which is every step,
which is the pathfinder running constantly for a result that is thrown away.

## Not generalised with the duel store, and why

This is the third store of the same shape — flat arrays, a free list,
participants held by id and generation, a clock. Generalising it with
`060-duels.lua` was considered and not done: a duel is always two bodies and has
an outcome, a game is up to six and has roles that swap, and merging them makes a
store whose entries are two different things with a discriminator — which is the
shape that gets one of the two wrong later.

Three instances is enough to see the pattern and not enough to be sure where the
seam is.

## Two counters that were the same bug twice

Every place that sends a body somewhere goes through `Walking.send_to`, and a
failed search there is counted **per caller**. That breakdown is what found both
of these, and a bare total would not have.

- **A wide body drew its destinations from the floor at large.** A three-by-three
  animal fits in the plazas and essentially nowhere else, and those plazas are
  mostly not connected to each other — so most destinations were somewhere it
  could never reach. Fifty-eight thousand failed searches a minute. It now draws
  from its own enclosure, which is labelled once at world creation.
- **A follower already standing on the trail cell** got a path of length zero,
  and zero was being treated as failure. Forty-six thousand a minute, all from
  one call site, all of them a body being told to go where it already was.
