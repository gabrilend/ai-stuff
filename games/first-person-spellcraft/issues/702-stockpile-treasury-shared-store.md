# 702 — The Stockpile / Treasury (shared store)

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** 701 (resource types define what the shelves count).
> **Blocks:** 704 (production deposits goods here), 705 (fulfillment spends from
> here), 706 (returns deposit here). Also the **Phase 8 seam** knocks on this
> module's deposit door.
> **Concern:** data generation (simulation). No UI here — 707 only *reads* it.

The shared store the whole settlement feeds and draws from. When the vision says
"here, have a health potion. There's extra at the stockpile," this is the
stockpile. It is one place that holds how much of everything the player has, and
it is the single door that both returning adventurers and (later) friendly
provinces use to hand resources in.

## Current Behavior

None of this exists yet. Nothing counts the player's resources or produced
goods; there is nowhere for a returning adventurer to deposit treasure and
nowhere for a market to spend from.

## Intended Behavior

A **stockpile / treasury** with two shelves and a ledger:

- a **balance shelf** — resource-type id → amount, for the treasure kinds from
  701 (gold, gems, resource notes, trial logs);
- a **goods shelf** — good id → amount, for produced goods (from 704) and
  incoming trade goods (from 705);
- an **append-only ledger** — every deposit and withdrawal, each stamped with
  its **provenance**: which adventurer brought it, which province granted it,
  which workshop produced it, which market spent it. Append-only on purpose: the
  economy's history should read like a bank statement no one can quietly rewrite.

The module offers, as its whole public surface:

- **Deposit a bag of resources, with provenance** — the *one door* both the
  return loop (706) and Phase 8 provinces knock on. Adds to the right shelf,
  writes a ledger line. This is factored out here (rather than living inside the
  return loop) precisely so Phase 8 can reuse it without touching Phase 5's code.
- **Withdraw / spend, with provenance** — subtract from a shelf; **refuse
  explicitly** (a returned error with a reason, not a silent clamp to zero) when
  the shelf can't cover the amount. Prefer a loud, traceable failure over a
  fallback.
- **Check affordability** — can this bag be paid from current balances? — so
  callers (fulfillment) can ask before they commit.
- **Read a balance / read the ledger** — read-only queries the config UI (707)
  leans on.

Provenance is itself a **dispatch table keyed by provenance-kind** (adventurer /
province / workshop / market) mapping to how that source is annotated in the
ledger, so adding a new source of resources later is adding a row.

## Suggested Implementation Steps

1. Define the two shelves as plain tables keyed by the 701 resource-type ids and
   by good ids. Assign the memory first; fill it in as resources arrive.
2. Implement the deposit door: validate the resource ids against 701, add,
   append a ledger line with provenance.
3. Implement withdraw/spend and affordability-check, with explicit refusal on
   shortfall (return an error value and reason; do not clamp silently).
4. Implement the append-only ledger: writes only append; there is no edit or
   delete entrypoint. Provenance annotation via the dispatch table.
5. Implement the read-only balance and ledger queries for 707.
6. Write the `.info.md` (each entrypoint as a black box) and a small
   test that deposits, withdraws, over-withdraws (expects refusal), and checks
   the ledger is append-only and correct.

## Files (proposed, by role)

- an `economy/stockpile` module (shelves + ledger + the deposit/withdraw/query
  surface) and its `.info.md`.
- a stockpile test that exercises deposit, spend, over-spend refusal, and ledger
  integrity.

## Design notes worth keeping

- The deposit door is the **Phase 8 seam**. Do not let the return loop own
  deposit logic; the stockpile owns it so provinces can reuse it.
- The ledger being append-only mirrors the project's append-only-memory
  discipline: history is added to, never rewritten.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  the stockpile is the "702" hub every arrow passes through.
- 701 (resource types), 704 (deposits goods), 705 (spends), 706 (deposits
  treasure), and the Phase 8 province seam.
