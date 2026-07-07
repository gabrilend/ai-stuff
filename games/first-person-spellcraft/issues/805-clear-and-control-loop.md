# 805 — The clear-and-control loop (NCP expeditions drive transitions)

> Phase 8. The loop that *moves* provinces between relationships. The player does
> not conquer directly — an autonomous NCP mounts an expedition, and the manner
> and outcome decide the new relationship. This is the seam onto Phase 5 and
> Phase 6. Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 5).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** 801 (provinces), 802 (the transition table it drives), 803 (the
  yields it unlocks), 804/804a/804b (re-clearing an unclaimed province resets it).
- **Cross-phase:** Phase 5 (the expedition is an NCP's, indirect control) and
  Phase 6 (the challenge engaged is the province's lair).
- **Blocks:** the unkindness tally that 807 watches gets ticked here.
- **Kind:** the core interaction loop of the phase.

## Current Behavior
None of this exists yet. Relationships (802) can change *in principle*, but
nothing drives a change from gameplay. There is no bridge from "an NCP went and
did a thing at a province" to "that province is now allied / hostile."

## Intended Behavior
The vision frames this as the Majesty-formula loop:

> overcoming trials and challenges and clearing and controlling neighbouring
> provinces yields resources depending on your relationship to them.

The controlling word is **indirect**. The Majesty formula is a game where you
never command a hero — you post incentives and one chooses to go. So this loop
does **not** let the player conquer a province by fiat. Instead:

1. The player sets **incentives / policy** (whose ownership lives on the Phase 5
   side — this loop only reads the result).
2. An autonomous **NCP mounts an expedition** at a province and engages that
   province's **Phase-6 challenge** (its lair/trial).
3. The expedition produces an **expedition resolution record**: the target
   province, the **manner** (peaceful vs unkind), and the **outcome** (succeed /
   fail).
4. This loop reads that record and picks the resulting **transition** via a
   dispatch table keyed by `(manner, outcome)`:

   | manner   | outcome | resulting relationship                     |
   | -------- | ------- | ------------------------------------------ |
   | peaceful | succeed | `allied`                                   |
   | unkind   | succeed | `hostile` (subjugated whetstone)           |
   | any      | fail    | unchanged; monsters may entrench further   |

5. On a successful transition it calls **802's transition table** (running the
   state hooks) and **unlocks 803's yield profile** for the new state; if the
   target was an unclaimed fight/cultivate province, it calls **804's
   reset-reversion** and pays the on-clear spoil. On an **unkind** success it
   also **ticks the unkindness tally** that 807 watches.

## Suggested Implementation Steps
1. Write a **clear-and-control** module. Define the **`(manner, outcome)`
   dispatch table** mapping to the resulting relationship (or "no change").
   Prefer the table over nested ifs.
2. Write **resolve-expedition(resolution_record)**: look up the province, pick
   the transition from the table, and — on success — call 802's transition,
   trigger 803's on-clear payout where relevant, and reset 804's timer for
   re-cleared unclaimed provinces.
3. On the `unkind + succeed` path, notify the **unkindness tally** (injected from
   807, so this module does not hard-depend on the union). Comment the fork: the
   unkind path buys a training ground *and* a step toward provoking a union — the
   cost of cruelty stated where the cruelty happens.
4. Treat the resolution record as an **input from Phase 5** — define its shape
   here (target id, manner, outcome, plus which NCP for training credit) but do
   not reach into Phase 5's internals; read the record only.
5. Route **training value** (from 803's hostile/fight payouts) back to the NCP in
   the record, honouring "be unkind, and they are challenges to train up on."
6. Write the companion `*.info.md`. Test each `(manner, outcome)` row lands the
   right transition; a failed expedition changes nothing; an unkind success both
   subjugates and ticks the tally.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Expedition source (Phase 5):
  [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).
- Challenge engaged (Phase 6):
  [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md).
- Drives 802; unlocks 803; resets 804; feeds the tally in 807.
