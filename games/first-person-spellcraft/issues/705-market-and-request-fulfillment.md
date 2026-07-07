# 705 — The Market System & Request Fulfillment

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** 701 (requests are priced in resource types), 702 (spends from
> and stocks into the stockpile), 703 (the request instances it fulfills are
> stamped from templates), 704 (produced goods are part of what markets can
> supply).
> **Blocks:** 706 (the return loop hands requests to the fulfillment engine),
> 708 (the demo shows fulfillment).
> **Concern:** data generation (simulation). Its stock-policy editing UI is 707.
> **Umbrella issue** — broken into sub-issues 705a, 705b.

Where "trade goods come in, they request capabilities from ashore, and they
arrive and do their duty." The player sets up markets; trade goods flow into
them; a returning adventurer's stamped request is matched against what a market
can supply and paid for with the scarce resources it brought back. This umbrella
frames the whole; the pieces are:

- **705a — Market model & trade-goods intake.** What a market is, the
  request-type dispatch table, and the periodic arrival of trade goods per each
  market's stock policy.
- **705b — Request-fulfillment engine.** Taking one stamped request instance and
  either delivering the capability (spending resources, drawing on stock/produced
  goods) or refusing with a reason.

## Current Behavior

None of this exists yet. There are no markets, no trade goods, and no way for a
request to be fulfilled. The vision's "request things from the markets that the
player has set up" has nothing behind it.

## Intended Behavior

Together: the player places markets and sets each one's stock policy; trade goods
arrive over time; and any stamped request instance (from 703 via 706) is resolved
to either a delivered capability or an explicit refusal. Requests come in three
classes — **magic items, rituals, and market goods** — and each is fulfilled by
its own handler chosen from a dispatch table, so the fulfillment engine never
branches on request kind. See the sub-issues for detail.

## Suggested Implementation Steps

1. Do **705a** first — the market records, the request-type dispatch table, and
   trade-goods intake.
2. Then **705b** — the engine that consumes a request instance and resolves it.
3. Keep both strictly headless (simulation). Only 707 edits the stock *policy*
   (a mold); the market itself is a placed instance.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  the "705" market/fulfillment box.
- Sub-issues 705a, 705b. Upstream 701–704; downstream 706, 708.
