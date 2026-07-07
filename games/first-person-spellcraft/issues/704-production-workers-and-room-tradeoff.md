# 704 — Production: Workshops, Workers & the Throughput-vs-Room Tradeoff

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** 701 (inputs/outputs are resource types & goods), 702 (produced
> goods land in the stockpile).
> **Blocks:** 705 (fulfillment draws on produced goods), 708 (the demo shows the
> tradeoff curve).
> **Concern:** data generation (simulation). Its editing UI is 707.
> **Umbrella issue** — broken into sub-issues 704a, 704b, 704c.

The making-of-things half of the economy. The player decides how many workshops
there are (lumber shops, etc.) and how many workers staff each. The vision fixes
the tradeoff exactly: "the fewer, the better, as they have room to spread out.
but, throughput is lower." Fewer workers per workshop → each worker has more room
→ each is *more* efficient, but there are *fewer* of them, so the workshop's
*total* output is lower. There is a sweet spot, and finding it is the game.

This umbrella describes the feature as a whole; the pieces are:

- **704a — Building & worker-slot model.** The workshops, the building-type
  dispatch table, and the room-per-worker math that turns crowding into an
  efficiency number.
- **704b — Production tick & throughput.** Advancing time: each workshop
  consumes inputs and emits goods at its computed rate, resolvable per-workshop
  in parallel.
- **704c — Service staff & the production-speed bonus.** Hiring staff to cover
  workers' chores, granting a speed multiplier.

## Current Behavior

None of this exists yet. Nothing produces goods; there are no workshops, no
workers, no notion of throughput or of the room-vs-throughput tradeoff.

## Intended Behavior

Together, the sub-issues deliver: the player can place workshops of various
building-types, assign workers to each, hire service staff, and have the
simulation generate goods over time into the stockpile — with the room-vs-
throughput tradeoff and the service-staff speed bonus both modeled explicitly and
visible as numbers the config UI (707) can preview. See each sub-issue for its
slice.

## Suggested Implementation Steps

1. Do **704a** first — the data model and the room math the rest depend on.
2. Then **704b** — the tick that turns the model into goods over time.
3. Then **704c** — the service-staff multiplier layered onto the tick's rate.
4. Only after all three, expose the **compute-a-workshop's-throughput**
   projection function that 707 calls (so the UI shows the same number the
   simulation uses — no re-derivation, no drift).

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  the "704" production box feeding the stockpile.
- Sub-issues: 704a, 704b, 704c.
- 701, 702 (upstream), 705, 707, 708 (downstream).
