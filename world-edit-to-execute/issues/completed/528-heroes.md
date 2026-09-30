# Issue 528: Heroes

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 527 (gameplay constants, object tables, economy), 521a (production), 520 (script)

---

## Current Behavior

A hero is a unit with a flag. The script's hero natives store numbers on
it (level, XP, attributes) that change nothing: no experience from
kills, no levels, attributes that give nothing, skills learned without
points or rules, no revival at altars (a fallen hero lies until the
script revives it), and no hero limit.

## Intended Behavior

Heroes work as in WC3, with the map's own gameplay constants:

- **Levels:** experience from kills near them, shared.
- **Attributes:** base plus growth per level; strength, agility and intelligence give hit points, armour, mana and damage.
- **Skills:** skill points to learn skills, with level requirements.
- **Revival:** fallen heroes wait to be revived at an altar, at a cost and time.
- **Limits:** hero limits and per-type limits, and hero tokens.
- **The script:** its hero natives and hero events work.

## Suggested Implementation Steps

1. `demo/wc3map/heroes.lua`: attributes, experience, levels, skills, revival, limits.
2. Production: hero and type limits, tokens, revival queues.
3. Natives and events; Blizzard.j's hero limit.
4. HUD: level, XP, skill points; learning; reviving.
5. Tests.

## Acceptance Criteria

- [x] Heroes start at level 1 with a skill point; attributes = base + growth × (level − 1) + bonus; hit points, mana, armour and damage follow them (StrHitPointBonus, IntManaBonus, AgiDefenseBonus, primary attribute)
- [x] Experience needed and granted by the gameplay constants (DAoW's own curve and level cap); kills shared among the killer's (and allies') heroes within HeroExpRange, by each hero's level factor; suspended heroes take none; buildings only with BuildingKillsGiveExp
- [x] Learning: skill points, the skill's levels, first required level and level skip (alev, arlv, alsk / HeroAbilityLevelSkip)
- [x] Fallen heroes stay; altars revive them at the constants' cost and time, queued like training, with HeroReviveManaFactor mana
- [x] Hero limit (tech max 'HERO', SetPlayerMaxHeroesAllowed, MeleeStartingHeroLimit), per-type tech max, hero tokens
- [x] Natives: Get/SetHeroLevel, UnitStripHeroLevel, Get/Set/AddHeroXP, Get/SetHeroStr/Agi/Int, SelectHeroSkill, skill points, SuspendHeroXP, ReviveHero; EVENT_PLAYER_HERO_LEVEL, _SKILL, _REVIVE_START, _REVIVE_FINISH; GetLearnedSkill(Level), GetRevivingUnit
- [x] HUD: level on hero buttons, real mana bars, XP and skill points in the unit panel; learning from the skill menu; revive buttons on altars
- [x] `test_heroes.lua`: 42 tests; related suites pass

## Implementation Notes

**Date:** 2026-09-30

### `demo/wc3map/heroes.lua`

- **A new hero** (`heroes.init_unit`: every hero at start and every spawn):
  - Its attribute bases and growth come from the tables (ustr/uagi/uint, ustp/uagp/uinp, upra), with its raw hit points, mana, armour and damage kept apart (`game.lua` now stores them).
  - Heroes whose tables have no attributes keep the stats they were given.
- **`heroes.refresh`** works out the attributes at the hero's level, then hit points, mana, armour and weapon damage, keeping the share of hit points and mana it had.
- **Experience:**
  - `g.add_xp`, `g.set_xp` and `g.set_hero_level` level up through `C:level_for_xp` (issue 527's constants), capped at MaxHeroLevel.
  - A level-up gives a skill point per level and fires EVENT_PLAYER_HERO_LEVEL.
  - Kills (a death listener): `C:kill_xp(victim level, hero?)`, × SummonedKillFactor for summons, shared evenly among the living heroes of the killer or its allies within HeroExpRange, each × `C:hero_factor(level)`.
- **Skills:**
  - `g.hero_skills(u)` is the unit's hero ability list (uhab: the map's, else the stock tables').
  - `g.can_learn` checks points, ownership, levels, and hero level: required + learned × skip.
  - `g.learn` raises `u.abilities[id]` (what the ability system uses) and fires EVENT_PLAYER_HERO_SKILL.
- **Revival:**
  - `g.is_altar` (urev, else altar-sized buildings).
  - `g.revive_cost` (`C:revive` of the hero's gold, lumber and build time at its level).
  - `g.revive(altar, hero)` queues it in the altar, like training; `g.revive_now` stands it up with HeroReviveManaFactor mana.
  - The start and finish events fire.
- **Limits:**
  - `g.tech_limit` reads the script's tech max, else the game's.
  - `g.tech_count` counts living units, fallen heroes and queued ones.

### Around it

- **Production:**
  - Type limits and the hero limit ('HERO') on training.
  - Hero tokens (PLAYER_STATE_RESOURCE_HERO_TOKENS) pay for a hero, and are given back if it's cancelled.
  - Revival entries in queues.
  - A hero is a type id starting with a capital (WC3's convention).
- **Game:**
  - `g.spawn_listeners`.
  - Command-card lists (uhab, uabi, utra ...) fall back to the stock tables when the map doesn't set them.
- **The VM:**
  - Hero events dispatch as EVENT_PLAYER_HERO_*.
  - The hero natives go through the game's heroes when it has them.
  - SetHeroStr/Agi/Int set a bonus so the attribute reaches the value asked.
  - SetPlayerMaxHeroesAllowed and MeleeStartingHeroLimit (3 heroes, one of each melee type) are real.
- **HUD:**
  - Hero buttons show level, real mana, and fallen heroes darkened.
  - The unit panel shows XP toward the next level (with a bar) and unspent points.
  - The skill menu shows each skill's next level and darkens those not learnable yet.
  - Altars list their fallen heroes to revive.

### Not yet

- **Taverns:** selling heroes needs a unit of the buyer nearby, and the first hero is free.
- **Items:** inventories, tomes.
- **Neutral creeps' experience:** the TFT creep reduction by hero level isn't separate from HeroFactorXP.
- **Draining:** MaxLevelHeroesDrainExp (max-level heroes taking a share) isn't applied.
- **Regeneration:** hit point and mana regeneration from attributes (StrRegenBonus, IntRegenBonus) isn't applied, and neither is attack speed from agility.
- **Learned abilities** do nothing until the ability system (issue 529) acts on them.
