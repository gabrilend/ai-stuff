# 804b — Unclaimed *cultivate* sub-mode (renewable natural materials)

> Phase 8, sub-issue of [804](804-unclaimed-monsters-return.md). The other way
> monsters return: they protect the province and leave it to nature, which slowly
> cultivates natural materials. Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 4).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula
- **Depends on:** 804 (the roll that selects this sub-mode + the sub-mode dispatch
  table), 801 (province record).
- **Sibling:** 804a (fight).
- **Kind:** yield behaviour for one unclaimed sub-mode.

## Current Behavior
None of this exists yet. When 804's roll settles a province to `cultivate`, there
is nothing on the other side of that dispatch — no growth, no harvest.

## Intended Behavior
The vision's second branch:

> … or to protect and leave to nature, to cultivate natural materials.

A province settled into **cultivate** mode is guarded by monsters that "protect
and leave to nature." Unlike fight mode, it yields **passively but slowly** — it
accrues **natural materials** over time (a different, renewable resource type
than the fight spoil), which can be **harvested peacefully** without a combat
clear. It is the reward for *leaving land alone*: less exciting than a hunting
ground, but it asks nothing and gives steadily. Left long enough it can build a
richer stock (an optional maturity curve — a young preserve yields less than an
old-growth one), all config-tuned.

The material type, the accrual rate, and any maturity curve are tuned knobs,
config + tracked in [balance-updates.md](../docs/balance-updates.md).

## Suggested Implementation Steps
1. Add the **cultivate** entry to 804's sub-mode dispatch table: a yield behaviour
   returning a **passive** per-tick delta of the province's natural material.
2. Pick the material type from the province's flavour via the same style of small
   flavour→material lookup used in 804a (a sibling dispatch table).
3. Accrue the material into the yield accumulator each tick; optionally scale by a
   maturity factor that grows the longer the province stays cultivated.
4. Provide a peaceful **harvest** path that 806 drains each economic tick — no
   expedition, no combat required. Comment the fork versus fight: cultivate mode
   is the *calm* frontier — no risk, a slow renewable trickle; the player ceded it
   to nature and reaps quietly.
5. Write the companion `*.info.md`. Test: cultivate mode accrues over time without
   a clear; the material matches the flavour; the maturity factor (if enabled)
   raises the rate over elapsed cultivation time.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Parent: [804](804-unclaimed-monsters-return.md). Sibling:
  [804a](804a-unclaimed-fight-mode.md). Harvest is banked by 806.
