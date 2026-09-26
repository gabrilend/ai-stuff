# Issue 115: Balance History Explorer

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 112b (the stacks of layers), 112d (the oldest versions), 112c (the stock tables' parsers)
**Blocks:** 115a

---

## Current Behavior

**Completed 2026-09-25.** `scripts/balance-history.sh [--open]` writes
`tmp/shared-memory/balance-history/` in about 11 seconds: `history.js` from
`src/cli/balance-history.lua` (The Frozen Throne: 24 versions, 1.07 disc to
1.29.2; Reign of Chaos: 21 versions, 1.00 disc to 1.27b; run it for the
current counts of objects whose numbers changed) and `index.html`, a copy of
`src/viewers/balance-history.html`. Checked in headless Firefox: the heat map
shows 1.11, 1.14b and 1.19a as the big early rebalances and a large ability
pass in 1.29.1; the Knight's page shows hit points 800 → 835 in 1.19a and
damage 25 → 28 with cooldown 1.50 → 1.40 in 1.22a.
`src/tests/test_balance_history.lua` (6 checks) holds those two changes, the
version order, the name, and that only changing fields are kept.

Found while building: a Lua `cond and false or x` always gives `x` (the disc
was asked for as a layer named "1.07"); fixed with a plain `if`. Lua's `%q`
writes decimal escapes that JavaScript reads as octal, so the data file uses
JSON escaping. Node on this machine fails to start (a library mismatch), so
the data was checked with Python's JSON parser instead.

Before this, the stock tables existed for every supported version as layers,
but nothing showed how the numbers moved between them.

## Intended Behavior

A page where you pick a unit, hero, ability, item or upgrade and see each of
its numbers across every version, as a line per field, and a map of which
patches changed the most. The owner (2026-09-25): "Let's focus on something
more fun! Anything you'd like!"

Two separate pieces (the owner's rule: data generation apart from viewing):

- **Generator** (`src/cli/balance-history.lua`): for each game and each of its
  versions in order (the disc, then every built layer), open a chain on that
  version reading the **melee** tables (the ones balance patches change;
  issue 112b), parse the stock tables, and record, for every object and every
  numeric field, the value per version. Keep only fields that change at least
  once. Names come from the profile text of the newest version (borrowed text,
  labelled so in the data; issue 112c). Writes one data file.
- **Viewer** (`src/viewers/balance-history.html`): a self-contained page (no
  network) that reads the data file and draws, with SVG, a searchable list of
  objects, one chart per changed field (version on the x axis), and a heat
  map of changes per patch per kind of object.

Output goes to `tmp/shared-memory/balance-history/` (the RAM tier for
artifacts): the viewer copied beside the data, opened in a browser. It is
made from the player's own install and stays on this machine; it is never
committed or published.

## Suggested Implementation Steps

1. The generator: versions in order per game, a chain per version
   (`layer = false` for the disc), tables per kind (units: `UnitBalance`,
   `UnitWeapons`; abilities: `AbilityData`; items: `ItemData`; upgrades:
   `UpgradeData`), numeric values only, fields that change kept; writes
   `history.js` (`window.HISTORY = {...}`, so the page opens from disk).
2. The viewer: object search, per-field line charts, the patch heat map;
   dark and light themes.
3. A run script (`scripts/balance-history.sh`) that generates, copies the
   viewer, and prints the path to open.
4. Tests (`src/tests/test_balance_history.lua`): the generator's data for the
   Knight shows melee damage 25 up to 1.21b and 28 from 1.22a (the change
   issue 112b found), and the data holds only fields that change.

## Acceptance Criteria

- [x] Generator writes the history for both games, every built version
- [x] Viewer shows per-field charts and the patch heat map, offline
- [x] Run script; output only under `tmp/shared-memory/`
- [x] Test on the Knight's damage change
- [x] `.info.md` beside each new file

## Related Documents

- `issues/112b-game-version-layers-per-map.md`, `issues/112d-older-patch-program-shapes.md`
- `src/gamedata/chain.lua`, `src/parsers/slk.lua`
