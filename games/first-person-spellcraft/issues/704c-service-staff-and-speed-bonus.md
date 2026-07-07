# 704c — Service Staff & the Production-Speed Bonus

> **Phase:** 7 — Economy & Settlement Management
> **Parent:** 704.
> **Depends on:** 704a (multiplies the per-worker rate it computes), 704b (the
> tick reads the multiplier).
> **Blocks:** 708 (the demo shows the with/without-staff difference).
> **Concern:** data generation (simulation).

The last production knob, straight from the vision: "the player can also hire
service staff, to care for their essentials. this gives them a speed bonus in
their production, as they don't have to worry about personal chores." Workers who
must do their own chores lose time to them; service staff take those chores off
their hands, and that reclaimed time is the speed bonus.

## Current Behavior

None of this exists yet. Workers (once 704a/704b land) always work at their raw
rate; there is no notion of chores, chore overhead, or service staff.

## Intended Behavior

- A **chore-overhead** model: without service staff, each worker loses a fraction
  of every tick to personal chores, so their effective rate is *below* their raw
  rate. This overhead is a tuning knob, not a hardcoded literal.
- A **service-staff pool**: how many service staff are hired, and a **coverage
  lookup** — how many workers one service-staff frees from chores. A staffed
  worker pays no chore overhead; an unstaffed one still does.
- A **production-speed multiplier** derived from coverage: the ratio of workers
  whose chores are covered determines how much of the lost chore-time is
  reclaimed. Fully covered → full speed; uncovered → the base chore penalty.
- This multiplier **slots into the seam 704a left** in compute-a-workshop's-
  throughput, so the bonus shows up everywhere throughput is read — the tick
  (704b) and the UI preview (707) both get it for free, from one definition.
- **Upkeep tension.** Service staff are not free; they draw upkeep (paid from the
  stockpile, in a resource type per 701). The player trades ongoing cost for
  throughput — another explicit lever, not a pure win.

## Suggested Implementation Steps

1. Add the chore-overhead fraction to the tuning/config file and apply it as the
   gap between a worker's raw rate and their unstaffed effective rate.
2. Model the service-staff pool and the coverage lookup (how many workers per
   staff).
3. Compute the production-speed multiplier from covered-worker ratio and wire it
   into 704a's compute-throughput seam.
4. Charge service-staff upkeep against the stockpile each tick (704b), with
   explicit provenance in the ledger.
5. Write the `.info.md` and a test comparing a workshop's throughput with zero
   staff vs full coverage, asserting the bonus equals the reclaimed chore-time,
   and that upkeep is actually drawn.

## Files (proposed, by role)

- an `economy/service-staff` module (the pool, coverage lookup, speed multiplier,
  upkeep charge) and its `.info.md`.
- a service-staff test comparing staffed vs unstaffed throughput and checking
  upkeep.

## Design notes worth keeping

- The bonus is *reclaimed lost time*, not bonus-on-top. Comment this at the
  multiplier: staff can at most bring a worker up to their raw rate, never past
  it, because all they do is remove the chore penalty. Whoever re-tunes needs to
  know the ceiling is the raw rate.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md).
- Parent 704; siblings 704a (the rate the bonus multiplies), 704b (the tick that
  applies it and charges upkeep).
