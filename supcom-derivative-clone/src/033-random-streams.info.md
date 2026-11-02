# 033-random-streams

Every random draw names its stream.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

There is no global random generator. A random use opens a stream by name, seeded
from the match seed and that name alone, so the same seed gives the same
sequence in every stream on every machine, and adding a name disturbs no other
stream. The world holds its streams as rows of one array, so the hash covers
them and a replay resumes them. The dunes use no stream; their noise is a hash of
position.

The generator, in the exact steps the handheld's box must match (all arithmetic
on thirty-two-bit patterns through the `bit` library):

1. **Seeding.** `state = (seed mod 2^32) xor 0x9e3779b9`. For each byte `b` of the
   name in order: `state = rotate_left(state xor b, 7)`, then
   `state = state + 0x7f4a7c15` wrapping. Then four times:
   `state = step(state xor 0x2545f491)`. A state of zero is refused.
2. **A step** (Marsaglia's xorshift): `state ^= state << 13`,
   `state ^= state >>> 17`, `state ^= state << 5`.
3. **A draw** steps once and reads the state as an unsigned number `u`.
   `next_integer` returns `floor(u * below / 2^32)`, with `below` a whole number
   from 1 to 2^21 so the product is exact; `next_double` returns `u / 2^32`.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `seed_state(seed, name)` | a whole seed; a name | the stream's starting state |
| `open(seed, name)` | a whole seed; a name | a stream table `{name, state}` |
| `next_integer(stream, below)` | a stream table; a whole number 1 to 2^21 | a whole number in `[0, below)` |
| `next_double(stream)` | a stream table | a double in `[0, 1)` |
| `draw(world, name, below)` | a world; a stream's name; as above | the next whole number from the world's stream of that name; an unknown name is refused by name |
| `draw_double(world, name)` | a world; a stream's name | the next double from it |
| `STREAMS` | | the names, in the order of the world's rows |
| `ROW` | | each name's row |

## Data structures it owns

`STREAMS`: `roster-hurt`, `cloud-round`, `report-order`. A new random use appends
a name; it never inserts one, because a row's place is part of the hash.
