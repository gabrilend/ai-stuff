# Issue 529: Abilities and Buffs

**Phase:** 7 (gameplay: roadmap rows 704, 705)
**Type:** Implementation
**Priority:** High
**Dependencies:** 527 (object tables, gameplay constants), 528 (heroes' skills), 520 (the script's events)

---

## Current Behavior

Units' abilities are ids and levels stored on them by the script
(UnitAddAbility ...); nothing uses them:

- **Casting:** there is none: the command card's ability buttons say "not simulated".
- **Spell events:** never fire, and those are what nearly every custom map's spells are built on (triggers on SPELL_EFFECT).
- **Mana:** never spent or regained.
- **Buffs:** there are none.
- **Hit points:** don't regenerate.

## Intended Behavior

Abilities as WC3 runs them:

- **Values:** by level from the ability tables (map over stock); a custom ability behaves as the stock ability it copies.
- **Casting:** into range, a cast point, then mana and cooldown spent; the script's spell events fire in WC3's order; channelled abilities last and can be interrupted.
- **Effects:** a starter set of stock effects, and buffs they leave (stuns, slows, auras, shields, damage over time).
- **Passives:** attack passives.
- **Regeneration.**
- **The script's side:** spell orders, buffs as abilities, cooldown reset, damage events.

## Suggested Implementation Steps

1. `demo/wc3map/buffs.lua`: buff instances and what they add up to.
2. `demo/wc3map/abilities.lua`: values, casting, events, effects, auras, passives, regeneration.
3. Combat, movement, the VM and natives on them.
4. Command card and HUD casting.
5. Tests.

## Acceptance Criteria

- [x] Ability values by level: mana (amcs), cooldown (acdn), range (aran), area (aare), duration (adur/ahdu), data fields; a custom ability's base decides its behaviour
- [x] Casting: approach into range, cast point (ucpt), mana and cooldown at the effect; SPELL_CHANNEL, SPELL_CAST, SPELL_EFFECT, SPELL_FINISH, SPELL_ENDCAST in order with GetSpellAbilityId/Unit/TargetUnit/TargetX/Y; channels tick and end; other orders, stuns and death interrupt (ENDCAST without FINISH)
- [x] Starter set: Storm Bolt, Thunder Clap, Blizzard, Water Elemental, Holy Light, Divine Shield, Devotion/Brilliance/Endurance/Unholy/Thorns auras, Bash, Critical Strike, Shockwave, Wind Walk, Death Coil, Frost Nova, Blink, Slow, Bloodlust, Roar; Channel (ANcl) with its target kind, time and order from its data; any other base still casts (events, mana, cooldown)
- [x] Buffs: stun, invulnerable, invisible, move and attack speed, armour, damage, regeneration, damage over time; same id replaces; units read them (movement, attack cooldown, armour, target choice, sight)
- [x] Spell damage ignores armour and uses the damage table's spells row; heals; summons with timed life
- [x] Regeneration of hit points and mana (uhpr, umpr; heroes' StrRegenBonus, IntRegenBonus; buffs); starting mana (umpi)
- [x] Natives: spell order strings in IssueTargetOrder/PointOrder/ImmediateOrder; GetUnitAbilityLevel and UnitRemoveAbility on buffs; UnitHasBuffBJ; UnitRemoveBuffs(Ex/BJ); UnitResetCooldown; EVENT_UNIT_DAMAGED (GetEventDamage)
- [x] Command card: the unit's abilities with cooldown shading, passives shown; pressing casts or picks a target
- [x] `test_abilities.lua`: 51 tests; full suite passes

## Implementation Notes

**Date:** 2026-09-30

### `demo/wc3map/abilities.lua`

- **Values:**
  - `g.ability_info(id, level)` reads the ability tables (`g.data.abilities`: the map's changes over the stock rows) at that level: mana, cooldown, range, area, duration and hero duration, `data(code, default)` for its own fields, and `duration_for(target)`.
  - `g.ability_spec` gives the base's behaviour and target kind. For Channel, the target kind comes from its data (Ncl2).
  - `g.ability_order` gives its order string (Channel: Ncl6; else the table's, else the base's).
- **Casting** (`g.cast(unit, id, target, x, y)`):
  - Checks: learned, not passive, cooled down, mana, not stunned, target kind, enemy or ally.
  - Then the cast: walk into range, face, SPELL_CHANNEL and SPELL_CAST, the cast point (ucpt, else 0.3 s), then mana, cooldown, SPELL_EFFECT and the effect.
  - Channels tick for their time, then SPELL_FINISH and SPELL_ENDCAST.
  - `abilities.interrupt` (a new order, a stun, death) fires ENDCAST alone.
  - The script may stop a cast from its own events: the cast checks it's still current.
- **The starter set:**
  - Effects by base code, each reading its data fields with stand-in defaults. The codes and defaults are FROM MEMORY; each effect names them.
  - An unknown base still casts: its events, mana and cooldown. That is what trigger-made abilities need.
- **Auras:** every half second, each aura on a living unit gives its buff to allies (or enemies) in range, lasting a little over the refresh.
- **Passives:** `g.modify_strike` runs attack passives (bash, critical strike, wind walk's backstab) and damage buffs on every strike (a hook in `combat.lua`).
- **Vitals:** hit points and mana regenerate every tick, and units start with their initial mana (umpi).
- **Units:** they get their type's `uabi` abilities at level 1. Heroes' skills come from learning (issue 528). System abilities (move, attack, harvest, inventory ...) aren't buttons.

### `demo/wc3map/buffs.lua`

- **Buffs** are tables on the unit (id, source, end time, flags, factors). A buff of the same id replaces the old one unless the old lasts longer.
- **`buffs.sum`** turns them into what the game reads: `stunned`, `buff_invulnerable`, `invisible`, `speed_mult`, `attack_mult`, `armor_bonus`, `damage_mult`, regeneration bonuses.
- **`buffs.update`** runs damage over time and expiry; a buff may run `on_end` (timed life for summons).

### Around it

- **Combat:**
  - `combat.damage(..., {spell = true})` skips armour.
  - Armour bonuses count; invulnerable buffs protect.
  - Stunned and casting units don't attack.
  - The attack cooldown is divided by `attack_mult`.
  - `g.damage_listeners` and `on_damaged` get every hit.
- **Movement:** stunned units don't move; move speed × `speed_mult`.
- **Vision:** invisible units aren't seen (issue 524 already asked `u.invisible`).
- **The VM:**
  - `on_damaged` fires EVENT_UNIT_DAMAGED and EVENT_PLAYER_UNIT_DAMAGED with GetEventDamage and GetEventDamageSource.
  - Spell order strings find the unit's ability with that order.
  - GetSpellTargetX and GetSpellTargetY.
  - Buffs answer GetUnitAbilityLevel and UnitHasBuffBJ; UnitRemoveAbility removes a buff by id.
  - UnitRemoveBuffs and UnitResetCooldown are real now (they were no-ops).
- **Animation:** casting units play Spell, or Spell Channel while channelling (`demo/wc3map/animate.lua`).
- **Command card and HUD:**
  - `db.castable` and `db.ability_ready` give each ability's button: cooldown shade, darkened when it can't be cast, passives not pressable.
  - Pressing a no-target spell casts it with the first selected unit that can; others enter targeting ("cast"), and a click casts.

### Not yet

- **More stock abilities:** most of the game's ~500 aren't in the starter set yet. Missing include: autocast (Heal, Inner Fire), toggles (Immolation, Defend), transformations (Metamorphosis, Bear Form), morphs, item abilities, and building and upgrade abilities.
- **Missiles and art:** projectiles travel instantly; no effect art is drawn.
- **Magic immunity,** spell steal and dispels by type (positive / negative), and buff levels.
- **Targets allowed** (`atar`: air, ground, structure, organic ...): only enemy or ally is checked.
- **Computer players** don't cast.

### Follow-up (2026-09-30)

A stock source that only answers `value()` (the stats test's stand-in) broke the game's command-card lists, which call `list()`. `game.lua` now gives such a source a `list()` built from `value()`. The full suite passes: 118 files.
