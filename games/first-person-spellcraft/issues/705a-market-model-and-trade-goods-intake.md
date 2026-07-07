# 705a — Market Model & Trade-Goods Intake

> **Phase:** 7 — Economy & Settlement Management
> **Parent:** 705.
> **Depends on:** 701 (stock is priced in resource types), 702 (trade goods flow
> through the stockpile / market inventory), 703 (stock policy is a mold).
> **Blocks:** 705b (the engine reads market inventories & the request-type
> dispatch).
> **Concern:** data generation (simulation).

What a market *is*, and how "trade goods come in." This sub-issue builds the
standing structure; the act of fulfilling a request is 705b.

## Current Behavior

None of this exists yet. There is no market entity, no trade-goods flow, and no
table of who-fulfills-what.

## Intended Behavior

- A **market record**, one per player-placed market: its on-hand trade goods, the
  capabilities it can fulfill (which of magic items / rituals / market goods), and
  a reference to its **stock policy**.
- A **stock policy** — a *mold*, per the templates-never-instantiations
  strategem: what the market should try to keep in stock and at what resource
  cost. The market is a placed *instance*; its policy is the *template* the player
  edits (via 707). Editing the policy never edits the market's current on-hand
  goods directly — the intake process reconciles stock toward the policy over
  time.
- A **request-type dispatch table**, keyed by request-type (magic item / ritual /
  market good), mapping each to the handler 705b will call. Adding a new request
  class later is adding a row.
- **Trade-goods intake** — a periodic process (ticking alongside production) that
  brings trade goods into markets toward their stock policy: "trade goods come
  in." Intake is priced against the resource types (701) and recorded in the
  stockpile ledger with market provenance. This is the *supply* side; production
  (704) is the *make-it-yourself* side, and a market may draw on both.

## Suggested Implementation Steps

1. Define the market record and the stock-policy mold (reusing 703's mold
   discipline: the policy is edited; the on-hand stock is derived toward it).
2. Author the request-type dispatch table with the three vision classes as rows,
   each pointing at its (705b) handler.
3. Implement trade-goods intake: each intake step moves a market's on-hand stock
   toward its policy, paying the cost through the stockpile, ledgered with
   provenance. Make an unaffordable restock an explicit "could not restock, here's
   why," not a silent skip.
4. Provide read-only queries (what can this market fulfill, what is on hand) for
   705b and for the 707 UI.
5. Write the `.info.md` and a test: set a stock policy, run intake, assert stock
   converges toward the policy and the ledger reflects the spend; then make
   restock unaffordable and assert the explicit refusal.

## Files (proposed, by role)

- an `economy/market` module (market record, stock policy, request-type dispatch
  table, trade-goods intake) and its `.info.md`.
- a market-intake test covering convergence toward policy and unaffordable
  restock.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md).
- Parent 705; sibling 705b (the fulfillment engine that reads this model).
