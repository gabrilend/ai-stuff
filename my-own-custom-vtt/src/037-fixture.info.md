# 037-fixture

Makes small worlds to run things against.

Phase 8 builds the real generator, which reads a description and a seed. This is
not that — it is the stand-in that exists because every phase before phase 8
needs a world to test against, and hand-writing one inside each test would mean
six copies of the same rooms drifting apart.

It is a **permanent tool**, not scaffolding. Even once the real generator exists,
a test wants a world it can predict exactly.

## The functions

| Function | In | Out |
| --- | --- | --- |
| `fixture_make_two_rooms` | world | 1 / 0 — initialises and builds, in one call |
| `fixture_build_two_rooms` | an already-initialised world | 1 / 0 |
| `fixture_capacity_hint` | six `uint32_t *` | the capacities the fixture needs |

## What it builds

Two twenty-metre rooms joined by a corridor, with a cellar under the west one, a
pillar in the middle of it, and a door across the corridor.

```
     0        20   24   30        50
  20 +---------+           +---------+
     |         |           |         |
     |    P    |           |    t    |
  12 |         +-----D-----+         |
     |         :  corridor :         |
   8 |         +-----------+         |
     | +-----+ |           |         |
     | |cellar |           |         |
   0 +-+-----+-+           +---------+
```

Every shape is there for something a later phase needs, not for prettiness:

- **The pillar** so phase 2 has something to cast a shadow around.
- **The corridor** so there is somewhere a body can be out of sight.
- **The cellar** so region nesting is exercised.
- **The door** so the flags-change mechanism has something to change.
- **A goblin with eyes and a coffee cup without**, so every test exercises the
  claim that they are the same record.
- **A torch**, so the light block is not empty.

Counts: 5 things, 18 walls, 4 regions, 13 vertices, 2 lights — each including the
sentinel at index 0.

## No seed, no variation

Nothing here is random, on purpose. A test whose fixture varies is a test that
fails intermittently, which is worse than a test that fails.

## It validates

Region boundaries are wound counter-clockwise and every body's `region` field is
set to the deepest region actually containing it, because a fixture that does not
validate is worse than no fixture — every test built on it would be testing a
broken world, and the failures would appear anywhere except here.
