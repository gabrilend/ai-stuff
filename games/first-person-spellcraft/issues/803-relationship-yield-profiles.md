# 803 — Relationship-based yield profiles

> Phase 8. The relationship decides the reward: peace trickles, hostility pays
> only when you fight it, unclaimed hands off to a sub-mode. A dispatch table
> keyed by relationship state. Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 3).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** 801 (province), 802 (state to dispatch on).
- **Soft-depends on:** 804 / 804a / 804b for the `unclaimed` branch — the profile
  table can ship with a placeholder that errors until the sub-modes exist, per
  "prefer error messages over fallbacks."
- **Blocks:** 806 (the economy bridge asks a province for its current yield).
- **Kind:** reward model.

## Current Behavior
None of this exists yet. Provinces have relationship states (802) but a state
produces nothing. There is no link between "how you stand toward a province" and
"what it gives you."

## Intended Behavior
A **yield profile** is a function, *chosen by relationship state*, that takes a
province and an elapsed-time amount and returns a set of **resource deltas** —
and, for challenges, a **training value** for the NCP who cleared it. The
profiles live in a **dispatch table keyed by relationship state**, mirroring the
state table in 802:

- **`allied` — a passive trickle.** Peace pays "one thing or another": a steady,
  time-proportional amount of a single resource type tied to the province's
  nature (its terrain/flavour). This is the reward for kindness. Passive: it
  accrues every tick without an expedition.
- **`hostile` — event-only, a whetstone.** A hostile province yields **nothing**
  per tick. It is "a challenge to train up on": it pays out only as an event,
  when an NCP expedition overcomes its trial (805 raises that event), and its
  real product is training value + a trial log (a Phase-7 treasure type), not a
  stream of goods.
- **`unclaimed` — delegated.** The profile defers to the sub-mode the province
  settled into when monsters returned (804a fight-spoil, or 804b cultivated
  material). This branch simply dispatches again, one level down.

A yield-profile entry describes, by role: which resource type(s) it produces, a
base rate, whether it is **passive** (per-tick) or **event-driven** (on clear),
and the training value it confers. Rates are tuned knobs, not hardcoded here —
they live in config and their history in
[balance-updates.md](../docs/balance-updates.md).

## Suggested Implementation Steps
1. Write a **yield-profiles** module holding the dispatch table keyed by state.
   Each entry is a small function `(province, elapsed) -> deltas, training`.
2. Implement the `allied` profile as a passive trickle: `rate * elapsed` of the
   province's flavour resource, drawn from config. Fold with the vimfold + name
   convention; comment *why* peace is passive (it is the incentive to be kind).
3. Implement the `hostile` profile to return an empty per-tick delta and expose a
   separate **on-clear** payout (training value + a trial log + a modest spoil)
   that 805 invokes when an expedition succeeds. Comment the branch: the whetstone
   path exists to give players a reason to *keep* enemies around to train on.
4. Implement the `unclaimed` profile as a one-line dispatch into the sub-mode
   table from 804; until 804 lands, have it raise a clear "sub-mode not yet
   implemented" error rather than silently returning zero.
5. Provide **evaluate-yield(province, elapsed)** as the single entry point that
   reads the province's state key and dispatches. 806 calls only this.
6. Keep resource *types* symbolic (flavour names), decoupled from Phase 7's pool
   identifiers; the bridge in 806 owns the mapping so a rename on either side
   touches one place.
7. Write the companion `*.info.md`. Test each branch: allied accrues over time,
   hostile is zero per-tick but pays on clear, unclaimed dispatches correctly.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- `unclaimed` sub-modes: 804, 804a, 804b. Clear event source: 805. Consumer that
  banks the deltas: 806. Trial-log/treasure types live in Phase 7:
  [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md).
