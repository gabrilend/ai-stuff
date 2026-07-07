# 804a — Unclaimed *fight* sub-mode (a specific combat spoil)

> Phase 8, sub-issue of [804](804-unclaimed-monsters-return.md). One of the two
> ways monsters return to an unclaimed province: they garrison it, and clearing
> them pays "a specific type of resource." Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 4).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** 804 (the roll that selects this sub-mode + the sub-mode dispatch
  table), 801 (province record).
- **Sibling:** 804b (cultivate).
- **Kind:** yield behaviour for one unclaimed sub-mode.

## Current Behavior
None of this exists yet. When 804's roll settles a province to `fight`, there is
nothing on the other side of that dispatch — no garrison, no spoil.

## Intended Behavior
The vision's first branch:

> monsters return, either to fight (for a specific type of resource) …

A province settled into **fight** mode is garrisoned by monsters and becomes a
**recurring combat target**. It yields **nothing passively** — like a hostile
province, its reward is an *event*, paid when an NCP expedition clears the
garrison. The distinguishing trait: it pays **one specific combat-spoil resource
type** determined by the province's flavour (e.g. a marsh pays a different spoil
than a crag). After a clear, if the province is still left unclaimed, the monsters
**creep back** over a (config-tuned) delay and it can be fought again — a
renewable *combat* loop, as opposed to 804b's renewable *harvest* loop.

The spoil type and the re-garrison delay are tuned knobs, config + tracked in
[balance-updates.md](../docs/balance-updates.md).

## Suggested Implementation Steps
1. Add the **fight** entry to 804's sub-mode dispatch table: a yield behaviour
   returning an empty per-tick delta and exposing an **on-clear** payout of the
   province's specific combat spoil.
2. Pick the spoil type from the province's flavour via a small lookup (itself a
   dispatch table flavour→spoil), so a new terrain adds one row.
3. On a clear (invoked by 805 when an expedition succeeds against a fight-mode
   province), pay the spoil into the yield accumulator and, if the province stays
   unclaimed, start the **re-garrison** timer; when it fills, the province is a
   fresh fight target again.
4. Comment the fork versus cultivate: fight mode is the *dangerous* frontier —
   ongoing risk, ongoing combat spoils; the player keeps it as a hunting ground.
5. Write the companion `*.info.md`. Test: fight mode is zero per-tick; a clear
   pays exactly the flavour's spoil; re-garrison re-arms the target after the
   delay.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Parent: [804](804-unclaimed-monsters-return.md). Sibling:
  [804b](804b-unclaimed-cultivate-mode.md). Clear events come from 805; spoils are
  banked by 806.
