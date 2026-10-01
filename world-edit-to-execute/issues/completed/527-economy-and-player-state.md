# Issue 527: Economy and Player State

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 521a (production), 520 (the map's script), 525 (stock tables)

---

## Current Behavior

A player's gold and lumber are kept (the script's player state, or a
purse), and training spends them. Nothing earns them: workers can't
gather, there's no upkeep (the top bar guesses it from food at 50/80), no
bounty, no score. Food is capped at a hard 100. The script's player
states beyond gold, lumber and food cap, its scores, gold mines' amounts
and player state events do nothing. Only unit tables are read from the
install; the gameplay constants (war3mapMisc.txt, which every DAoW
version ships) aren't read at all.

## Intended Behavior

The data model a WC3 game keeps per player, and what fills it:

- **Player state:** gold, lumber, food ceiling, bounty flag, gathered totals and score counters, the same table the script reads and writes.
- **Food:** used against made, capped by the gameplay constant FoodCeiling (or the script's ceiling).
- **Upkeep:** tiers from the gameplay constants tax the gold that workers bring back.
- **Gathering:** workers mine gold (one at a time in a mine, which runs dry) and cut lumber, and carry it to buildings that take it back.
- **Bounty and scores:** kills pay bounty and count for both sides.
- **The script's side:** player states, scores, resource amounts and player state events.
- **Foundation:** every object kind's stock tables (with levels), and the gameplay constants in their order: defaults, then the install's, then the map's.

## Suggested Implementation Steps

1. `gamedata/object_stock.lua`: any kind's value by field code, levels, data fields, profiles.
2. `gamedata/game_constants.lua`: [Misc] defaults, install, map; experience, upkeep, damage table, revival helpers.
3. `demo/wc3map/economy.lua`: player state, food, upkeep, gathering, bounty, scores.
4. The game, production, combat and HUD on it; the AI's workers too.
5. Natives: player states, scores, resource amounts, harvest orders, player state events.
6. Tests.

## Acceptance Criteria

- [x] `object_stock`: units, abilities, items, upgrades; per-level columns, ability data fields (DataA1), profile fields (per-level comma lists); map changes (at their level) win
- [x] `game_constants`: WC3's defaults, overridden by the install's MiscData/MiscGame and the map's war3mapMisc.txt; experience needed and granted by formula, hero level factor, upkeep tiers, the damage table, revival cost
- [x] Player state shared with the script; FoodCeiling and upkeep from the constants (DAoW: 300, no upkeep)
- [x] Workers mine gold (one at a time; the mine runs dry and falls) and cut lumber (trees fall), returning to the nearest building that takes it back (urtm, else halls); upkeep taxes gold brought back
- [x] Bounty (ubba + ubdi × ubsi) from players that give it; scores for units, buildings and heroes made, killed and lost, gathering and upkeep
- [x] GetPlayerState (food used, gathered, upkeep rates ...), SetPlayerState, GetPlayerScore, Get/Set/AddResourceAmount, harvest orders; TriggerRegisterPlayerStateEvent fires
- [x] HUD: upkeep from the game; right-click or Gather sends workers to mines and trees; AI players put workers on gold and lumber by their profile
- [x] `test_economy.lua`: 30 tests; related suites pass

## Implementation Notes

**Date:** 2026-09-30

### Foundation

- **`gamedata/object_stock.lua`:**
  - Generalises issue 525's unit lookup to every kind. `unit_stock.lua` is now its units' case.
  - Kinds come from `field_rules.lua`, plus upgrades (`UpgradeMetaData.slk`, `UpgradeData.slk`).
  - Column rules:
    - `repeat` > 0 gives `field .. level`.
    - `data` 1-9 gives `field .. letter .. level` (DataA1).
    - `slk = "Profile"` reads the kind's text profiles, one comma entry per level (the last when there are fewer).
  - Map changes are looked up at their level, then at level 0.
  - `S:list(id, code)` splits id lists.
- **`gamedata/game_constants.lua`:**
  - Loading and reading:
    - `[Misc]` defaults (FROM MEMORY of TFT 1.21, labelled), then the install's `Units\MiscData.txt` and `Units\MiscGame.txt`, then the map's `war3mapMisc.txt`.
    - `C.origins[key]` says which source set each value.
    - Table-plus-formula series read as the Gameplay Constants give them: entries, then prev × A + level × B + C.
  - Helpers:
    - Experience: `hero_xp_needed`, `level_for_xp`, `kill_xp`, `hero_factor`.
    - `upkeep`: a tier whose limit is 0 isn't one, which is how DAoW switches upkeep off.
    - `damage_factor` (the attack × armour table) and `revive`.
- **On the game:**
  - `g.data` (units, abilities, items, upgrades) and `g.constants`, from `opts.chain`. The map viewer passes the install's chain.
  - `g.death_listeners` and `g.made_listeners`: combat and production call them.

### Economy (`demo/wc3map/economy.lua`)

- **State:**
  - `g.state(p)` (also `g.purse`) is the running script's player handle when a script runs, else a table of the game's.
  - It fills in: gold and lumber (the melee 500 and 150, or the script's literal amounts, without a script), bounty (neutral hostile gives it), gathered totals, and `score`.
- **Food:** `g.food(p)` counts units and queued units against food made, capped by `g.food_ceiling(p)`: the script's FOOD_CAP_CEILING, else FoodCeiling. The script's player no longer starts with a hard 100 ceiling.
- **Upkeep:** `g.upkeep(p)` and `g.income(p, kind, n)`: resources gathered are taxed, counted, and announced to the script for player state events.
- **Gathering** (`g.gather(worker, mine, x, y)`, the "gather" order):
  - Workers walk to a mine, wait their turn (one miner at a time, hidden while inside), and come out with 10 gold.
  - At trees they chop one lumber a second, up to 10.
  - Loads go to the nearest building that takes them back: `urtm`, else halls. Then back to the source, or the next tree.
  - Mines run dry and fall; trees fall at 0 lumber (their models stop drawing).
  - The numbers are stand-ins until the harvest abilities' fields are read.
- **Bounty and scores:**
  - A death pays the killer's owner the victim's bounty, if the victim's player gives it.
  - Units, buildings and heroes are counted as made, killed and lost.

### The script (`jass/natives/world.lua`, `jass/vm.lua`)

- **Player states:** GetPlayerState reads the game's state, including computed ones (food used, food cap, ceiling, upkeep rates, gathered). SetPlayerState announces changes.
- **Scores:** GetPlayerScore maps PLAYER_SCORE_* to the economy's counters.
- **Gold mines:** Get/Set/AddResourceAmount set a mine's gold; they were no-ops.
- **Orders:** harvest orders (and smart on a mine) send workers to gather.
- **Events:** `V:player_state_changed(p)` fires TriggerRegisterPlayerStateEvent registrations when their comparison turns true. Limit ops are accepted by name or number.

### HUD and AI

- **Top bar:** it shows the game's upkeep tier.
- **Orders:**
  - Right-clicking a gold mine, or ground among trees, with workers selected gathers.
  - The Gather button targets the same way.
- **AI:** AI players assign idle workers to gold, then lumber, up to their profile's harvest counts. `editor_ai` hands the profile's counts over.

### Not yet

- **Harvest numbers:** gold and lumber per trip, mining and chopping time, and tree lumber aren't read from the harvest abilities' data yet.
- **Races' gathering:** wisps, acolytes on haunted mines, entangled mines.
- **Building:** construction (workers building structures), repair, lumber mills as drop-offs without `urtm`.
- **Trees:** they don't regrow, and their sight-blocking isn't removed when they fall.
- **Trade:** trading between allies (gold and lumber sharing); tax.
