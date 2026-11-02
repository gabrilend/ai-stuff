# 030-the-world

Allocates the world once, as flat arrays.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Everything the simulation holds is a group of parallel arrays, one array per
field, allocated once before the first tick and never resized. `LAYOUT` is the
only description of those groups: the allocator builds from it, the validator
checks against it, and the snapshot's hash and the handheld port walk it.

Three rules:

- **Zero is nothing.** Slot zero of every array is never a row, so an id of zero
  means "no such thing". Every array is allocated one longer for it.
- **Nothing is nil.** Every array is zero-filled; `validate` refuses any slot
  that is not a number (a double not equal to itself included).
- **Capacity is a refusal, not a resize.** Claiming past a group's capacity
  raises, naming the group.

It also holds **the loader**: `load(stem)` finds the one `src/NNN-<stem>.lua`
beside this file and `load_asset(stem)` the one `assets/NNN-<stem>.lua`, refusing
zero or two matches by name (the test harness's rule), and keeps each module
under its path in `package.loaded` so every module asking for a stem gets the
same table. Modules that need another find this file first, by the same rule,
because a file cannot use the loader to find the loader.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `allocate(parameters)` | `field` (the dunes' shape table), `units` and `teams` (whole numbers of at least one), `seed` (a whole number; absent means zero) | a world: the field raised and validated, every group zeroed, every counter made, every stream seeded |
| `validate(world)` | a world | nothing; raises naming the group and field of a wrong type, length or slot, a live count outside the capacity, a counter that is not whole numbers, or a stream at state zero; also validates the field |
| `claim(world, group)` | a world; a pool's name | the id of a row now alive: the last released one, or the next never used; raises past the capacity, naming the group |
| `release(world, group, id)` | a world; a pool's name; a live id | nothing; zeroes every field of the row and stacks the id for reuse; raises on a row that is not alive |
| `counter_at(world, row)` | a world; a row of `COUNTERS` | the counter table that row names |
| `load(stem)` | a stem | the module in `src/NNN-<stem>.lua`, loaded once |
| `load_asset(stem)` | a stem | the table in `assets/NNN-<stem>.lua`, loaded once |
| `LAYOUT`, `SCALARS`, `COUNTERS`, `TYPES` | | the layout, below |

## Data structures it owns

The world is a table:

| Field | Type | Holds |
| --- | --- | --- |
| `tick` | integer | the tick about to run; the number of ticks run so far |
| `seed` | integer | the match seed |
| `field` | table | the field record from the dunes |
| `rule` | table | a copy of `assets/NNN-the-rules.lua` |
| `layout` | table | `{groups = LAYOUT, counters = COUNTERS, scalars = SCALARS}`, so a module holding a world can walk its layout without loading this file |
| one table per group | table | `capacity`, the kind's scalars, and one foreign array per field |
| `claim` | table | the claim counter, a `timers` counter with `increments_to_claim` |

Types: `integer` is an `int32_t` array, `double` a `double` array, each
`capacity + 1` long.

Kinds of group, and the scalars each carries beside its fields:

| Kind | Scalars | Meaning |
| --- | --- | --- |
| pool | `count`, `top`, `released` | rows are claimed and released; ids are stable while alive; `count` is live rows, `top` the highest row ever claimed (walkers go from one to it), `released` the height of `free`, the stack of released ids reused last-released first |
| fixed | none | every row exists for the whole match |

The groups:

| Group | Kind | Capacity | Fields |
| --- | --- | --- | --- |
| `unit` | pool | `units` | `alive`, `kind`, `team` (integer); `x`, `y` (double); `domain` (integer); `altitude` (double); `health`, `health_at`, `reload_at`, `pattern`, `leg`, `mission`, `target`, `damage`, `falloff` (integer); `eye`, `profile` (double); `shield`, `shield_at`, `eaten` (integer); `eat_share`, `strength` (double); `in_round` (integer); `goal_x`, `goal_y` (double) |
| `cell` | fixed | the field's cells | `owner`, `claim_by`, `claim_began`, `improvement` (integer) |
| `team` | fixed | `teams` | `mass`, `energy`, `thorns` (double); `energy_level` (integer) |
| `stream` | fixed | the names in `random-streams`' `STREAMS` | `state` (integer, never zero) |

The counters (`COUNTERS`): each row is a `path` from the world to the counter,
the rule holding its period in `seconds`, and `extra` integers copied from the
rules.

| Counter | Period | Extra |
| --- | --- | --- |
| `world.claim` | `claim_seconds` | `increments_to_claim` from `claim_increments` |

Groups and fields other issues need -- patterns, shots, bones, factories, the
command queue and so on -- are added here by the issue that builds them, under
the names the tests document gives.
