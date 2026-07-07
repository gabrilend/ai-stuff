# 704b — Production Tick & Throughput (goods over time)

> **Phase:** 7 — Economy & Settlement Management
> **Parent:** 704.
> **Depends on:** 704a (the workshop model & throughput math), 701 (inputs/
> outputs), 702 (goods land in the stockpile).
> **Blocks:** 708 (the demo runs ticks).
> **Concern:** data generation (simulation). Pure and headless — no UI.

Time passing. 704a said how much a workshop *can* make; this sub-issue makes it
actually happen, tick by tick, into the stockpile. "Generates goods over time"
made literal.

## Current Behavior

None of this exists yet. The workshop model (once 704a lands) is static: it can
report a throughput number, but nothing advances time or moves goods.

## Intended Behavior

- **Advance production one tick** — for every placed workshop: ask the stockpile
  (702) whether its input resources/goods are available; if so, consume them and
  emit its output goods at the rate 704a computes; write both the consumption and
  the production to the stockpile ledger with **workshop provenance**.
- **Input starvation is explicit, not silent.** If a workshop cannot get its
  inputs this tick, it produces nothing and the reason is recorded — a warning,
  not a swallowed no-op. (Warnings-as-errors: a starving lumber shop is a signal
  the player wants to see, not hide.)
- **Per-workshop independence within a tick.** Workshops do not depend on one
  another inside a single tick, so a tick is a *batch of independent resolutions*
  — naturally one coroutine per workshop, resolved by a thread/coroutine pool
  (shared stockpile memory). Never resolve them in a hand-rolled sequential loop
  when they can be resolved in parallel; the batch shape is the point. Assign the
  per-workshop result memory first, then let the pool fill each slot.
- **Deterministic.** Same workshops + same stockpile state + same tick → same
  outputs. This keeps 708's demo and the tests reproducible.

## Suggested Implementation Steps

1. Implement the single-workshop resolution: check inputs via 702's
   affordability query, consume, produce at 704a's rate, ledger both.
2. Make starvation return an explicit "starved, here's why" result rather than a
   silent zero.
3. Wrap the set of workshops as independent coroutines resolved by a pool;
   collect their results into pre-allocated slots. Share the stockpile; guard the
   deposit door so concurrent deposits stay consistent.
4. Provide **advance-N-ticks** on top of advance-one-tick for the demo and
   tests.
5. Write the `.info.md` and a test: seed a stockpile with inputs, run several
   ticks, assert goods accumulate at the expected rate; then starve a workshop
   and assert the explicit starvation result and zero production.

## Files (proposed, by role)

- an `economy/production-tick` module (single-workshop resolve, the pooled batch
  tick, advance-N-ticks) and its `.info.md`.
- a production-tick test covering accumulation and starvation.

## Design notes worth keeping

- The tick is where the "never sequential when it can be parallel" discipline
  earns its keep: a settlement with many workshops is a batch, and a batch is a
  pool of coroutines over shared memory.
- Keep this module free of any UI and of any market logic. It only turns inputs
  into goods over time; who *spends* those goods is 705's business.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md).
- Parent 704; siblings 704a (the model), 704c (the speed bonus applied to the
  rate this tick uses).
