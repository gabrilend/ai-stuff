# 804 — The unclaimed → monsters-return dynamic

> Phase 8. Leave a province alone and its reversion timer runs; when it fills,
> monsters return, and the province rolls into one of two sub-modes. This ticket
> owns the *timer* and the *roll*; the two sub-modes are 804a and 804b. Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 4).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** 801 (the reversion timer field), 802 (the `unclaimed` state and
  its `on_enter`/`on_exit` hooks that start/stop the timer).
- **Split into:** 804a (fight sub-mode), 804b (cultivate sub-mode).
- **Blocks:** completes the `unclaimed` branch of 803.
- **Kind:** timed state behaviour + a weighted roll.

## Current Behavior
None of this exists yet. A province can be in the `unclaimed` state (802) and it
carries a reversion timer field (801), but nothing advances that timer and
nothing happens when it fills. An unclaimed province just sits, inert.

## Intended Behavior
The vision:

> leave unclaimed, and monsters return, either to fight (for a specific type of
> resource) or to protect and leave to nature, to cultivate natural materials.

While a province is `unclaimed`, its **reversion timer** advances with game time.
This covers both a province never claimed and one abandoned after being held —
entering `unclaimed` starts the timer (via 802's `on_enter`). When the timer
fills, **monsters return**, and the province settles into one of two sub-modes by
a **weighted roll on the province's traits** (terrain flavour, and how it was
treated per its kindness ledger):

- **fight** (804a) — monsters garrison it; it becomes a recurring combat target.
- **cultivate** (804b) — monsters protect it and leave it to nature.

The choice is a roll, then a **dispatch on the result** into the sub-mode's yield
behaviour — not a branching if. A province that has settled remembers its
sub-mode (stored on the record) so it stays a fight target or a nature preserve
until something changes it. If an expedition later re-clears the province (805),
the sub-mode is cleared and the timer resets, ready to run again if abandoned
once more.

The timer duration and the fight/cultivate weights are tuned knobs, in config,
tracked in [balance-updates.md](../docs/balance-updates.md) — no numbers here.

## Suggested Implementation Steps
1. In the **yield-profiles** module (or a small **unclaimed** module beside it),
   add a per-tick **advance-reversion(province, elapsed)** that only acts while
   the province is `unclaimed` and has not yet settled a sub-mode.
2. On timer fill, run a **weighted roll** over the two sub-modes using weights
   derived from the province's traits + kindness ledger, drawn from config.
   Store the chosen sub-mode key on the province record.
3. Build a **sub-mode dispatch table** keyed by `fight` / `cultivate`, each entry
   pointing at the yield behaviour defined in 804a / 804b. The `unclaimed` yield
   profile in 803 dispatches through this table.
4. Provide **reset-reversion(province)** for 805 to call when a province is
   re-cleared: clear the sub-mode, reset the timer.
5. Comment both control-flow branches: settling to *fight* means the player left
   a dangerous frontier and now must send heroes to keep it down for spoils;
   settling to *cultivate* means the player ceded it to nature and now reaps slow
   renewable materials. Each path's consequence stated at the fork.
6. Write the companion `*.info.md`. Test: the timer only runs while unclaimed;
   fill triggers exactly one roll; a forced weight picks the expected sub-mode;
   reset clears the sub-mode and timer.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Sub-modes: [804a](804a-unclaimed-fight-mode.md),
  [804b](804b-unclaimed-cultivate-mode.md).
- Feeds the `unclaimed` branch of 803; reset by 805.
