# 706 — The Return-and-Request Loop (the Phase 5 seam)

> **Phase:** 7 — Economy & Settlement Management
> **Depends on:** 702 (deposit brought-back treasure), 703 (stamp the request
> from the template), 705 (fulfill the request). Reads 701 throughout.
> **Blocks:** 708 (the demo runs whole returns); it is the contract Phase 5 calls.
> **Concern:** data generation (orchestration / simulation). No UI.

The conductor. Every other simulation issue is an instrument; this one plays
them in order when an adventurer comes home. It owns the **seam to Phase 5** —
what a "return" carries in, what a "ready to redeploy" carries out — and nothing
of the world's making of goods or holding of stock, which it delegates.

## Current Behavior

None of this exists yet. Even once 701–705 exist, nothing strings them together;
a returning adventurer has nowhere to hand its treasure and no path from "I'm
home" to "I'm re-equipped and redeploying."

## Intended Behavior

The loop, run once per returning adventurer:

1. **Receive a return event** (from Phase 5). It carries the character's
   identity, its **character-kind** (which selects a template), its brought-back
   treasure (resource-type → amount), and its current loadout. The loop needs
   nothing else from Phase 5.
2. **Deposit the brought-back treasure** through the stockpile's one deposit door
   (702), with adventurer provenance.
3. **Look up the request/inventory templates** for this character-kind (703).
4. **Stamp the request and loadout instances** from those templates plus the
   brought-back treasure (703's stamp operation — the only place instances are
   born).
5. **Fulfill each stamped request** through the fulfillment engine (705b),
   collecting deliveries and the reasons for any refusals.
6. **Re-equip the character**: apply the free grants from the loadout instance
   (drawn from the stockpile) and the fulfilled capabilities to its loadout.
7. **Hand back a redeploy-ready result** to Phase 5: the character with its
   refreshed loadout, plus the list of **unfulfilled requests and their reasons**,
   so Phase 5 can color the companion's dialogue ("the stockpile was out of mana
   crystals").

This module *is* the seam. It defines the small inbound contract (the return
event) and the small outbound contract (the redeploy-ready hand-back). Phase 5
knows only those two shapes; it never touches stockpile, market, or workshop.

## Suggested Implementation Steps

1. Nail down the two contract shapes first: the **return event** and the
   **redeploy-ready hand-back**. Write them as the module's documented interface;
   this is the whole agreement with Phase 5.
2. Implement the ordered loop calling 702 → 703 → 705b → re-equip.
3. Thread the unfulfilled-request reasons all the way out to the hand-back — do
   not drop them; they are the point of the seam back to companion dialogue.
4. Keep the loop a pure orchestrator: it holds no economy state of its own, it
   only calls the modules that do. If it starts accumulating state, that state
   belongs in the module that owns that concern.
5. Write the `.info.md` (documenting both contract shapes as black boxes) and a
   test: feed a synthetic return event, assert treasure landed in the stockpile,
   a request was stamped and fulfilled (or refused with a reason), the loadout was
   refreshed, and the hand-back carries the unfulfilled remainder.

## Files (proposed, by role)

- an `economy/return-loop` module (the two contracts + the ordered orchestration)
  and its `.info.md`.
- a return-loop test driving one synthetic return end to end.

## Design notes worth keeping

- The deposit in step 2 uses the **same door** Phase 8 provinces will use. Do not
  special-case adventurer deposits here; provenance is the only difference, and
  the stockpile (702) already handles that.
- Put a comment at the seam explaining the two contract shapes and why they are
  kept minimal: the less Phase 5 knows about the economy's internals, the freer
  either side is to change without breaking the other.

## Related Documents / Tools

- [datapath-economy-settlement.md](../docs/datapath-economy-settlement.md) —
  "The two seams: Seam to Phase 5."
- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) *(planned,
  Phase 5)* — the other side of this contract.
- Calls 702, 703, 705b. Reachable by Phase 5.
