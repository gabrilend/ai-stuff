# Issue 542: Research

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 521a (production), 524 (object stock), 535 (morph listeners)

---

## Current Behavior

There's no research. Buildings' research lists (ures) aren't read.

- **The script:** SetPlayerTechResearched stores a number that nothing uses except requirement checks. GetPlayerTechCount returns only that number, AddPlayerTechResearched and GetPlayerTechResearched don't exist, and no RESEARCH_* events fire.
- **Computer players:** AI Editor "upgrade" entries are noted as unplayed.

## Intended Behavior

- **What a building researches:** the upgrades in its ures list (the stock lists by id as a fallback).
- **Levels and cost:** each upgrade has levels (glvl). A level costs gold, lumber and time: base plus increment for each level already had (gglb/gglm, glmb/glmm, gtib/gtim). It needs its requirements (greq).
- **The queue:** a research takes a place in the building's queue like training. It can't be queued past its last level, and cancelling refunds it.
- **The script's events:** RESEARCH_START, RESEARCH_CANCEL and RESEARCH_FINISH fire, with GetResearched.
- **Levels:** they belong to the player. The script's natives see the same numbers, and levels count as requirements.
- **Effects:** each of an upgrade's effects (gef1-4 with gba, gmo, gco) applies at base + increment × (level − 1). It applies to the player's units whose upgrade list (upgr) names it: those there now, those made later, and units that change type.
  - **Supported effects:** hit points (flat and share), armour, damage, dice, range, attack speed, move speed, mana, both regenerations, and an ability's level.
  - **Unknown effect codes** are left alone and recorded in `g.research_unknown`.
  - **Changing levels:** a level changed either way (by the script, too) re-applies the difference.
- **The script's natives:**
  - SetPlayerTechResearched, AddPlayerTechResearched and GetPlayerTechResearched;
  - GetPlayerTechCount gives a research's level, else the count of units of that type;
  - IssueImmediateOrderById with a research id starts it.
- **Command card:** "Research X (level n)" buttons; a finished one is disabled.
- **Computer players:** `AI:produce` researches ids that one of their buildings researches, and `AI:count` counts levels and queued ones. AI Editor "upgrade" entries are played.

## Suggested Implementation Steps

1. `demo/wc3map/research.lua`: `upgrade_info` (cached), levels, `apply_research`, `set_research`, `researches`, `can_research`, `research`, `research_done` / `research_cancelled`, db hooks.
2. `production.lua`: research entries in the queue; `has_tech` asks research levels.
3. Natives; the card and HUD; the AI.
4. Tests.

## Acceptance Criteria

- [x] Research lists, costs and times by level; queue, max level, cancel refund, events
- [x] Effects on units now and later; levels up and down re-apply the difference
- [x] Requirements; research as a requirement; ability levels; unknown effects noted
- [x] The script's natives; the card; the AI
- [x] DAoW: its 146 changed upgrades are read (names, levels, costs), and 345 of its buildings have research lists
- [x] Tests: test_research (40); the full suite passes

## Notes

- **From memory, to check against the install:** the effect codes (UpgradeEffects), the field codes, the stock research lists and the formula for later levels.
- **DAoW:** its upgrades have no effects in this container, because their effects are stock values the map doesn't change. On your machine the install supplies them.
- **Not modelled yet:** research that changes a unit's model or attack type, and "rlev" upgrades that grant an ability the unit doesn't have.
