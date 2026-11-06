# 604 — Mods Overlay The Catalogue

| | |
| --- | --- |
| Phase | 6 — Growth |
| Blocked by | 201 |
| Blocks | 703 |
| Files | `src/004-catalogue.lua`, `mods/` |

## Current behavior

Built in `src/004-catalogue.lua`; mods come from the configuration's list
and then from `--mod`. The example mod `mods/example-clay-knights/` adds a
clay knight and a perk. Tested in tests/035-command-and-growth.lua.

## Intended behavior

Each folder under mods/ (in name order, and only those listed as enabled in
the configuration's `mods` list) may hold any of the four catalogue files. An
entry with a name already present replaces it whole; a new name adds it. The
merged catalogue is validated as one, so a mod that refers to a weapon
another mod removed fails at start-up naming both.

A shipped example mod, `mods/example-clay-knights/`, adds a unit type and a
perk, so the mechanism is visible and tested.

## Suggested implementation steps

1. Overlay in the loader, before validation.
2. Test: the example mod adds its entries; a broken mod stops the load naming
   its folder.
