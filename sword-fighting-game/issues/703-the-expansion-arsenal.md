# 703 — The Expansion Arsenal

| | |
| --- | --- |
| Phase | 7 — Distance |
| Blocked by | 602, 604 |
| Blocks | none |
| Files | `assets/catalogue/weapons.lua`, `assets/catalogue/unit-types.lua` |

## Current behavior

Two-handed swords, and the spear the mega spearman carries.

## Intended behavior

The technology ladder the vision describes, as catalogue entries and the
few rules they need: spears and hatchets (the simple technology every army
starts with), big hammers, swords, glaives, halberds; pikes when the wood is
right; horses (and the lack of yaks); archers; and dragons, which are cannons
of fire. Each weapon is data first; a rule is added only where data cannot
say it (pikes' reach-but-no-close-defence, cavalry's charge momentum, the
dragon's cone).

## Suggested implementation steps

1. Add the weapons as data.
2. Add cavalry movement and the charge as a separate sub-issue when started.
