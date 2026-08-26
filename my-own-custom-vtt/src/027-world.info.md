# 027-world

Everything true at one instant, as flat arrays. The only place a fact lives —
everything else holds a copy or a filtered view, and knows it.

This file is storage and nothing else. It does not validate (035), does not
serialise (037), and has no opinion about geometry (029). Keeping them apart is
what lets a bug in one of them have a side.

## The blocks

`things`, `walls`, `regions`, `vertices`, `lights`, plus a `string_pool`. Each
starts with its index-0 sentinel already claimed.

Also: `min_x`/`min_y`/`max_x`/`max_y`, the map's extent — not a constraint on
where anything may stand, but what the fog grid is sized from and what a renderer
frames the view with. And `tick`, the beats since the world started running.

## The records

**`struct thing`** — 44 bytes, no padding. One record for a player's character, a
goblin, a coffee cup, a door leaf, a torch, a tree.

| Field | Type | Meaning |
| --- | --- | --- |
| `x`, `y` | `wcoord` | Position, in 1/1024 metre. |
| `scope` | `uint32_t` | Who commands it. 0 means nobody. |
| `region` | `uint32_t` | The deepest region containing it. 0 is open ground. |
| `kind` | `uint32_t` | Into the ruleset's catalogue. Never interpreted here. |
| `sheet` | `uint32_t` | Into the ruleset's storage. Never read here. |
| `sight_range` | `uint32_t` | 0 means it does not see — a coffee cup's normal state. |
| `sprite_category` | `uint32_t` | Into this world's string pool. 0 means it wears nothing. |
| `sprite_seed` | `uint32_t` | The other half of the picture's description. |
| `facing` | `wangle` | A full turn is 65536; wraps by overflowing. |
| `radius` | `uint16_t` | How much space the body takes. |
| `sight_arc` | `wangle` | 32768 is everything ahead. |
| `flags` | `uint16_t` | Below. |

The last two are what a thing is WEARING, and they are stored rather than looked
up on purpose. The ruleset could supply a category — it already turns a kind into
a description — but then a saved world would be a set of coordinates that needs a
particular Lua file, in a particular version, to mean anything visual. Written
down, the file regenerates every picture in it with nothing else loaded. Two
things of one kind with different seeds wear different pictures, which is the
whole point of a generated appearance layer and is unreachable while a kind is
all a thing has.

There is no second record type, and there will be pressure to add one. It arrives
as "props do not need a sight cone" — true, and not a reason. A cup with
`sight_range` 0 costs four bytes and buys the property that the code moving a cup
**is** the code moving a goblin, which is what makes a commander who owns a
tavern require no new code at all.

**`struct wall`** — 24 bytes. Two endpoints, `door` (the thing it is the leaf of,
0 for plain wall), and flags.

**`struct region`** — 16 bytes. `first_vertex` and `vertex_count` into the shared
vertex pool, `parent` (0 for top level), `name_offset`. Boundaries are closed —
the last vertex joins the first and is not repeated.

**`struct light`** — 20 bytes. The `thing` that carries it, radii, arc, colour.
Colour is one of very few appearance fields in the world, and it is here because
light *shape* affects what is visible.

## The flags

| Bit | Constant | On a body | On a wall |
| --- | --- | --- | --- |
| 0 | `BLOCKS_SIGHT` | Sight does not pass through | Sight does not cross |
| 1 | `BLOCKS_MOVEMENT` | Bodies cannot walk through | Bodies do not cross |
| 2 | `THING_HIDDEN` / `WALL_ONE_WAY` | Never sent to anyone who does not command it | Blocks only from the segment's left |
| 3 | `THING_EMITS_LIGHT` | Has an entry in the lights block | — |
| 4 | `THING_MOBILE` | Expected to move; a hint, not a permission | — |

The first two are **shared constants, not parallel definitions**. An earlier
draft numbered them differently for bodies and walls, which produces a curtain
you cannot walk through and a wall you can see past, with nothing obviously wrong
in either file. A test asserts they agree.

They are separate bits because the interesting cases are where they disagree: a
chasm blocks movement and not sight, a curtain the reverse, a portcullis blocks
movement and lets sight through. One "solid" flag would delete all three.

## The functions

`world_init` / `world_release`. `world_add_thing`, `_wall`, `_region`, `_vertex`
(which takes its coordinates, since a boundary is a run of consecutive indices),
`_light` — each returns an index, or 0 on failure.

`world_thing(_const)` and friends reach a record. **Valid only until the next
allocation of that kind.** A bad index reads as the empty record.

`world_*_count` returns records in use, including the sentinel.

Predicates — `thing_blocks_sight`, `thing_blocks_movement`, `thing_is_hidden`,
`thing_can_see`, `wall_blocks_sight`, `wall_blocks_movement`, `wall_is_one_way` —
exist so nobody tests a flag bit by hand. A bit tested by hand in forty places is
a bit tested wrongly in one of them.

`world_copy` is exact, and is what the rollback ring does at the head of every
turn. No encoding, no endianness, no field walk — it never leaves the process.
The versioned file writer is a separate, slower, more careful thing.
