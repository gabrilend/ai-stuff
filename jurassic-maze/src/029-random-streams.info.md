# 029-random-streams

Named seeded generators. The determinism guarantee everything else rests on.

Read this page rather than the source.

## What it is for

There is no global generator and nothing takes a number from the clock. Each
system draws from its own named stream, so the sequence a given system sees from
a given seed is stable no matter what else in the project is edited.

That is not a theoretical nicety. It is the difference between "here is a seed,
the ball gets stuck on layer four" being a bug report anybody can reproduce and
it being a story about something that happened once.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new(seed, name)` | integer, string | one stream |
| `make_set(seed)` | integer | every stream the project uses, keyed by name |
| `names()` | — | the list of stream names |

## A stream

| Method | Arguments | Returns |
| --- | --- | --- |
| `:next_raw()` | — | the next 31-bit non-negative integer. Everything else is built on it. |
| `:next_float()` | — | a double in [0, 1) |
| `:next_below(limit)` | integer | an integer in 1..limit |
| `:next_between(low, high)` | integers | an integer in low..high inclusive |
| `:chance(p)` | double | true with probability p |
| `:pick(list)` | array | one element |
| `:shuffle(list)` | array | the same list, shuffled in place |

It also carries `name`, `state`, and `count` — how many times it has advanced.
The count is used by nothing; it is here because it is occasionally the fastest
way to find out which system is burning luck it should not be.

## The streams `make_set` builds

`terrace`, `carve`, `braid`, `stair` for the generator; `spawn`, `idle`,
`meeting`, `duel`, `wander_ball`, `wander_guy`, `wander_dino` for the
simulation; `burn` for phase seven; and `camera`.

**`camera` must exist and the simulation must never read it.** A viewer drawing
from a simulation stream would make the world depend on whether anybody was
watching, and two runs of one seed would diverge based on whether somebody
pressed a key. A grep in `tests/052-layering.lua` enforces it.

## Three things that are not knobs

- **The shift triple 13, 17, 5** is Marsaglia's. Changing any of the three
  silently turns this into a generator with a dramatically shorter period.
- **Zero is xorshift's fixed point** and produces zeros forever. It is redirected
  rather than left as a trap, because it is reachable only when a seed happens to
  equal a stream name's hash, and would be utterly baffling to debug.
- **`shuffle` walks downward.** The version that walks upward and draws from the
  whole range is the common mistake and is not uniform. There is a
  ten-thousand-sample test.

`next_below` has a real modulo bias and it is accepted deliberately: at these
limits it is under one part in ten million, and rejection sampling would make the
number of generator steps depend on the values drawn — which would make a
recorded run depend on them too.
