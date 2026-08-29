# 032-the-world

The world: flat arrays for every body and every structure, allocated once.

## What it is for

The world is one table of **flat arrays**, not an array of tables. Every soldier's
health lives in one contiguous array, every soldier's lane in another.

Two reasons, and the second is the one people forget. The usual one: the move pass
touches four fields out of thirty and should not drag the other twenty-six through
the cache. The specific one: **slicing a flat array across a pool of workers is a
pair of integer bounds, and slicing an array of tables is a pointer chase.**

The map is the exception and is an array of structs, because it is built once,
never written to again, and read by name rather than swept in bulk. So is the
structure array — the argument for flat arrays is about sweeping thousands of
things, and there are twenty structures.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `create(parameters, map, stream)` | | The world record. |
| `allocate(world)` | | A fresh soldier id, generation bumped. |
| `release(world, id)` | | — Frees a slot, clearing **every** field on it. |
| `begin_decay(world, id, span)` | ticks | — Takes a body off the field without taking its slot. |
| `revive(world, id, health)` | | — Puts a decaying body back, intact. |
| `give_body(world, id, row)` | archetype row | — Copies a catalogue row into a body's slot. |
| `raise(world, name, detail)` | | — Records an event for this tick. |
| `empty_counts(kind_count)` | | One integer per upgrade kind, all zero. |

It also exports named constants for states (`STATE_WALKING` … `STATE_RECOVERING`),
flavours (`FLAVOUR_WAVE`, `FLAVOUR_HERO`, `FLAVOUR_GUARD`, `FLAVOUR_MONSTER`),
phases, and `SOLDIER_CAPACITY`.

## The world record

| Field | Type | Meaning |
| --- | --- | --- |
| `tick` | integer | Ticks since match start. |
| `phase` | integer | 1 normal, 2 surge, 3 challenge, 4 calm, 5 over. |
| `winner` | integer | 0 while running; the winning team, or **3** for a draw. |
| `soldier` | struct of arrays | Every walking body. |
| `structure` | array of records | Towers and libraries. |
| `wave` | array of records | Every wave ever spawned; they accumulate. |
| `team` | array[2] | Chest, slots, push depth, deck index. |
| `stream` | table | The named generators. |
| `pending_damage` | double[] | One slot per body, cleared every tick. |
| `pending_structure_damage` | double[] | Kept separate so neither can index into the other by an arithmetic mistake. |
| `free_slot` | integer[] | The free list. |
| `high_water` | integer | The highest slot ever used — every sweep runs to here, not to capacity. |
| `soldier.decaying` | integer[] | Ticks of decay remaining; 0 for everything alive and everything gone. |
| `soldier.zone` | integer[] | The zone this body has reached, counted from its **own** team's end: 0 at its own library, 31 at the enemy's. What push depth is taken from. |
| `capacity` | integer | How many soldier slots exist. Written down rather than left as the length of one of the arrays, so anything allocating a parallel array asks the world how big it is rather than asking one of its fields. |
| `event` | array | Raised this tick, cleared at the top of the next. |

## The soldier arrays

Grouped as **identity** (`alive`, `generation`, `team`, `flavour`, `owner`,
`archetype`, `wave`, `assigned_team`), **place** (`lane`, `node_from`, `node_to`,
`path_index`, `progress`, `x`, `y`, `facing`, `milestone`), **body** (`health`,
`health_max`, `damage`, `armour`, `range`, `acquire_range`, `speed`, `cooldown`,
`cooldown_max`, `reach`), and **mind** (`state`, `incoming_dps`, `target`,
`target_generation`, `target_structure`, `leash_node`, `wander_node`, `guard_of`).

`upgrade_count` is **one flat array per kind**, not one table per body, so that the
sweep re-stamping a lane's guards touches one kind across many bodies — a walk down
one array.

## Nil is not an option

Every array is filled to capacity with the integer zero at creation. A field that
might be empty holds zero, which is a sentinel with a meaning; nil would be a
question about whether some earlier code did its job, and that question belongs to
[the map validator](031-map-validator.info.md) at load time.

## Three rules worth knowing before you touch it

**`release` clears every field, and that is not tidiness.** A slot that kept its old
target, upgrade counts, or leash would hand them to the next body that moves in,
and that body would behave like a ghost of the last one — the single most confusing
class of bug this design can produce.

**`allocate` refuses rather than growing.** Running out of slots means something is
spawning without bound. A silent reallocation would move every array out from under
any worker holding a slice of one.

**A death goes through `begin_decay` first, and `release` two seconds later.** In
between, the body is not alive and its slot is not free: nothing can be allocated
over it, its generation counter has not moved, and every reference to it is still a
valid reference to it. `revive` undoes the death by clearing one number.

`alive` is the flag everything in the simulation already tests, which is why the
decaying state is expressed by clearing it rather than by a new condition each pass
would have to learn — targeting, the frontline queue, push depth, the grid and the
brain all exclude a decaying body with no change at all. That is the payoff of having
one flag everything agrees on, and it is the reason the flag is where it is.

`release` still decrements the living count when it is handed a body that is somehow
still alive — a match being torn down, a test freeing a slot directly — and does not
when the body left the field two seconds ago. See issue 210.

**`generation` is what makes recycled slots safe.** A stale id can be detected
instead of pointing at a stranger who moved in after the original died.
