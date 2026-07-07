# 704a — Building & Worker-Slot Model (the room-vs-throughput math)

> **Phase:** 7 — Economy & Settlement Management
> **Parent:** 704.
> **Depends on:** 701 (inputs/outputs are resource types & goods).
> **Blocks:** 704b (the tick reads this model), 704c (the bonus multiplies this
> model's rate).
> **Concern:** data generation (simulation).

The static shape of production: what a workshop *is*, and the math that turns
"how crowded is it" into "how efficient is each worker." No time passes in this
sub-issue — that is 704b. Here we define the records and the curve.

## Current Behavior

None of this exists yet. There are no workshops, building-types, worker slots,
or any relationship between crowding and efficiency.

## Intended Behavior

- A **building-type dispatch table**, keyed by building-type id (lumber shop,
  etc.). Each entry: the input resources/goods it consumes, the output goods it
  produces, its **base per-worker rate**, and its **footprint / capacity** (how
  much room the building has, hence how many workers before they crowd).
- A **workshop record**, one per placed building: its building-type, its worker
  count, and everything derivable from those.
- The **room-per-worker** derivation and the **tradeoff curve**, which is the
  whole point of the vision line "the fewer, the better... but throughput is
  lower":
  - room-per-worker = the workshop's room divided among its assigned workers.
    More workers → less room each.
  - per-worker efficiency *rises* as room-per-worker rises (spread out = better),
    following a tunable curve.
  - **total throughput = worker count × per-worker efficiency × base rate.**
  Because per-worker efficiency climbs as workers drop while worker count falls,
  the product has a **sweet spot**: a small crew in a big room can out-quality a
  packed one, but a packed one can out-*volume* a sparse one. The player is meant
  to feel this tension. Model it as an explicit, inspectable function, not an
  emergent accident.
- A **compute-a-workshop's-throughput** function that returns the total for a
  given workshop. This is the function 707 calls for its preview and 704b calls
  each tick — one definition, no second copy.

The building-type table means "what does a lumber shop consume and produce" is a
row lookup, not an if/else over building kind. Adding a new workshop type is
adding a row.

## Suggested Implementation Steps

1. Author the building-type dispatch table with the vision's lumber shop as the
   first row (inputs, outputs, base per-worker rate, footprint).
2. Define the workshop record (building-type + worker count).
3. Implement room-per-worker and the per-worker-efficiency curve. Keep the
   curve's constants in the tuning/config file, not inline literals — they are
   knobs, and turning them belongs in `docs/balance-updates.md`.
4. Implement compute-a-workshop's-throughput = worker count × per-worker
   efficiency × base rate (the service-staff multiplier from 704c slots in here
   later; leave the seam).
5. Write the `.info.md` and a test that sweeps worker count from 1 up to
   capacity and confirms the throughput curve has the intended sweet-spot shape
   (rising then falling, or diminishing — whatever the tuned curve dictates), and
   that a sparse workshop beats a packed one on per-worker efficiency.

## Files (proposed, by role)

- an `economy/workshops` module (building-type table, workshop record, the room
  math, compute-throughput) and its `.info.md`.
- a throughput-curve test that sweeps worker counts and asserts the tradeoff.

## Design notes worth keeping

- Put a comment on the efficiency curve explaining the two directions it trades:
  *fewer workers* buys per-worker room (quality) at the cost of total volume;
  *more workers* buys volume at the cost of room. Whoever re-tunes it later needs
  to know both ends are intentional.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md).
- Parent 704; siblings 704b (the tick), 704c (the staff bonus).
