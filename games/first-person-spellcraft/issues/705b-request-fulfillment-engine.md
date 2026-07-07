# 705b — Request-Fulfillment Engine

> **Phase:** 7 — Economy & Settlement Management
> **Parent:** 705.
> **Depends on:** 705a (markets, the request-type dispatch, on-hand stock), 702
> (spends the resources), 703 (the request instance it consumes is a stamped
> copy), 701 (pricing).
> **Blocks:** 706 (the return loop calls this per request).
> **Concern:** data generation (simulation).

Where a request becomes a delivered capability — "they arrive and do their duty."
Given one stamped request instance, decide whether a market can supply it and the
adventurer can pay, then either deliver or refuse.

## Current Behavior

None of this exists yet. Nothing turns a request into a fulfilled capability;
markets (once 705a lands) can hold stock but nothing draws it down for an
adventurer.

## Intended Behavior

- **Fulfill one request instance** — the engine's single job. For a stamped
  request instance (from 703, handed over by 706):
  1. Dispatch on the request-type (magic item / ritual / market good) via 705a's
     table to the right handler — no if/else over request kind.
  2. Ask whether *some* market can supply the capability (has it in stock or can
     produce it from 704's goods).
  3. Ask the stockpile (702) whether the scarce-resource cost is affordable from
     what the adventurer brought back (and/or the shared treasury, per the
     template's rule).
  4. If both hold: spend the resources, draw down the market stock / produced
     goods, deliver the capability into the character's loadout, and ledger the
     whole transaction with market provenance.
  5. If either fails: **refuse explicitly** with a reason (out of stock,
     unaffordable). No partial silent fulfillment, no fallback substitution. The
     reason travels back so 706 can hand it to Phase 5 for companion dialogue.
- **The engine never stamps and never edits templates.** It only *consumes* a
  request instance and *mutates* stockpile/market stock and the character's
  loadout. Keeping it downstream of stamping preserves the mold/copy wall.
- **Deterministic given inputs**, so 708's demo and the tests are reproducible.

## Suggested Implementation Steps

1. Implement the three per-request-type handlers (magic item, ritual, market
   good), each: locate a supplying market, price it, spend, deliver, ledger.
2. Implement the top-level fulfill-one-request that dispatches to a handler and
   returns either a delivered-capability result or an explicit refusal-with-reason.
3. Ensure affordability and stock checks happen *before* any mutation, so a
   refusal leaves the world untouched (no half-spent resources).
4. Write the `.info.md` and a test: a fulfillable request delivers the capability
   and draws down stock + resources correctly; an unaffordable one and an
   out-of-stock one each refuse with the right reason and leave balances unchanged.

## Files (proposed, by role)

- an `economy/fulfillment` module (the three handlers + the dispatching
  fulfill-one-request) and its `.info.md`.
- a fulfillment test covering success, unaffordable refusal, and out-of-stock
  refusal with no side effects on failure.

## Design notes worth keeping

- Comment the two branches at the decision point: **fulfilled** (spend + deliver
  + ledger) versus **refused** (touch nothing, return the reason). A future
  editor must not "helpfully" add a partial-fulfillment fallback — an unfulfilled
  request is information the player is meant to receive.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md).
- Parent 705; sibling 705a (the market model it reads). Called by 706.
