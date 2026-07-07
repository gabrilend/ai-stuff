# 806 — Territory → economy feedback bridge

> Phase 8. The one-way valve from the province ring into the kingdom's coffers:
> each economic tick, walk the map, ask every province for its yield, and deposit
> the sum into the Phase-7 resource pools. Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 6).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** 801 (the map to walk), 803 (the yield each province reports),
  804a/804b (the unclaimed sub-mode yields).
- **Cross-phase:** Phase 7 — deposits into the economy's resource pools.
- **Kind:** an aggregator / translation bridge (separation of concerns).

## Current Behavior
None of this exists yet. Provinces can produce yield deltas (803, 804a, 804b) and
they accumulate on the province record, but nothing drains those accumulators and
nothing carries them into the economy. Territory yields go nowhere.

## Intended Behavior
Each **economic tick**, the bridge:
1. **walks the territory map** (801),
2. asks each province to **evaluate its current yield** through 803's single
   entry point (which dispatches on relationship state, and for unclaimed, on
   sub-mode),
3. **sums the deltas by resource type**,
4. **maps** territory resource *flavours* onto the Phase-7 pool identifiers (this
   mapping lives here, so a rename on either side touches one place),
5. **deposits** into the Phase-7 resource pools (gold, gems, resource notes,
   trial logs), and
6. **drains** each province's yield accumulator by what it banked.

The separation is deliberate and load-bearing: **territory produces yield events;
the bridge translates them into economy deposits.** Territory code never writes
to economy state directly, and economy code never reaches into a province. A bug
on one side cannot corrupt the other — the isolation is the whole point, per the
project's "keep the separation of concerns isolated, to better encapsulate
errors" discipline.

**Trial logs** and **training value** produced by hostile/fight clears (803, 805)
ride this same bridge into Phase 7's treasure types where applicable.

## Suggested Implementation Steps
1. Write a **territory-economy bridge** module. Give it **collect-yields(map,
   elapsed)** that walks the map, calls 803's `evaluate-yield` per province, and
   accumulates a per-resource-type total.
2. Define the **flavour → pool** mapping as a dispatch table in this module; keep
   territory flavour names and Phase-7 pool ids on opposite sides of it.
3. Write **deposit(totals)** that hands the mapped totals to the Phase-7 economy's
   deposit interface — reading Phase 7's public pool API, not its internals.
4. Drain each province's accumulator by the banked amount so the same yield is
   never double-counted; comment why draining is post-deposit (a crash mid-tick
   should not silently lose banked goods — order the write so it is recoverable).
5. Make the bridge a pure consumer: it must not mutate relationship state or
   trigger transitions. Its only job is read-yield → deposit.
6. Write the companion `*.info.md`. Test with a small map holding one province of
   each kind (allied, hostile, unclaimed-fight, unclaimed-cultivate): assert the
   correct pools receive the correct sums and accumulators drain to zero.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Yield source: 803 (+ 804a/804b). Map: 801.
- Economy destination (Phase 7):
  [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md).
