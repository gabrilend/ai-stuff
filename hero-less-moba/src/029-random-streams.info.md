# 029-random-streams

Named seeded generators. The determinism guarantee everything else rests on.

## What it is for

Randomness here is **never global and never taken from the clock.** The world
holds a small set of named streams, each a seeded generator that advances only
when its own system asks it to.

If every random call came out of one stream, a cosmetic change to how tower guards
choose where to wander would shift every later draw from the chest, and no two runs
of the "same" match would agree about anything. With separate streams the draw
sequence for a given seed is stable no matter what else in the project is edited.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new(seed, name)` | integer, string | One stream. |
| `make_set(seed)` | integer | Every stream the simulation uses. |

## A stream

| Method | Arguments | Returns |
| --- | --- | --- |
| `:next_raw()` | — | The next 31-bit non-negative integer. Everything else is built on it. |
| `:next_float()` | — | A double in [0, 1). |
| `:next_below(limit)` | integer | An integer in 1..limit. |
| `:shuffle(list)` | array | The same list, shuffled in place. Fisher-Yates. |

It also carries `name`, `state`, and `count` — the last being how many times it has
advanced, which is occasionally the fastest way to find out which system is
burning luck it should not be.

## The streams `make_set` builds

| Stream | Shape | Used for |
| --- | --- | --- |
| `draw` | one per team | Which upgrade comes out of the chest. |
| `deck` | one | The shared sequence both teams draw from, built once. |
| `wander` | one | Where a tower's guards choose to patrol. |
| `tie` | one per team | Breaking exact ties in target selection. |
| `boon` | one | Which boons a player is offered after a challenge. Not yet used. |
| `surge` | one per team | The deal order when the chest is dealt across a surge. Not yet used. |

`tie` is per-team for the same reason `draw` is. A shared tie stream makes each
team's luck depend on how often the *other* team had a tie to break — a coupling
nothing in the design asked for, which shows up as an unexplainable asymmetry in a
match nobody touched.

## The generator, and what it is not

xorshift32, through LuaJIT's `bit` library. It is **not** cryptographic and does
not need to be. What is asked of it is that it be *the same every time*, which is
a much weaker property than being unpredictable — the two are often confused.

Two details that are not knobs:

- The shift triple **13, 17, 5** is Marsaglia's. Changing any of the three turns
  this into a generator with a much shorter period.
- A **zero state is xorshift's one fixed point** and produces zeros forever. It is
  reachable only if a seed happens to equal a stream name's hash, which is rare
  and would be baffling, so it is redirected rather than left as a trap.

`next_below` has a real modulo bias and it is accepted deliberately: with limits
never larger than a few hundred against a 2^31 span the bias is under one part in
ten million, and rejection sampling would make the *number of generator steps*
depend on the values drawn — which would make a replay depend on them too.
