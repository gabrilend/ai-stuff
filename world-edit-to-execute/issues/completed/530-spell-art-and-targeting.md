# Issue 530: Spell Art, Effects and Targeting

**Phase:** 5 (rendering) and 7 (gameplay)
**Type:** Implementation
**Priority:** High
**Dependencies:** 529 (abilities, buffs), 522 (models), 523 (animation)

---

## Current Behavior

Spells have no art: no caster, target or effect models, no missiles (a
Storm Bolt lands the moment it's cast), no buff art (a stunned unit
looks like any other). The script's special effects (AddSpecialEffect,
AddSpellEffect ..., DestroyEffect) are no-ops. Spell targets are
checked only for enemy or ally; the abilities' own "targets allowed" list
isn't read.

## Intended Behavior

- **Art:** abilities and buffs play their art: the stock art from the install's profiles, or the map's own when its object data changes it.
- **Effects:** models at points or on units' attachment points, playing Birth, Stand and Death.
- **Missiles:** fly with their model, speed and arc, and the spell lands when they arrive.
- **The script:** its effects work.
- **Targeting:** spells target units or ground as their data allows, checked against "targets allowed", and the pointer shows a spell's area while aiming.

## Suggested Implementation Steps

1. `demo/wc3map/effects.lua`: effects, missiles, art lookup; buff art hooks.
2. Abilities: caster art, missiles, target / effect / area art; aura art; targets allowed.
3. `jass/natives/art.lua`: the script's effects.
4. The map viewer draws effects, missiles, and the aiming ring.
5. Tests with made-up tables, and DAoW's own overrides.

## Acceptance Criteria

- [x] Ability art (caster, target, effect, special, area, missile, lightning; attach points; missile speed and arc) read from the map's changes, else the stock profile (by field code, else by profile field name); buff art likewise (a new object kind: buffs)
- [x] Effects at points or attached to units (following them), timed or destroyed (lingering for their Death); missiles homing on units or to points, arcing, carrying the spell's effect to where they land
- [x] Casting plays caster art at the effect, launches a missile if the spell has one (or is a missile spell), then target art on the target, effect and area art at a point; Blizzard's waves drop its effect art; buffs show their art while they last; auras show their ability's target art on the units they touch, without restarting it at each refresh
- [x] "Targets allowed" (atar): kind (air, ground, structure ...), side (enemies, friend, allies, player, neutral, self, notself), hero or not, alive or dead, vulnerable or not; else the base's enemy / ally rule
- [x] Natives: AddSpecialEffect(Loc/Target), AddSpellEffect(ById)(Loc/Target), GetAbilityEffect(ById), DestroyEffect, the BJ forms and bj_lastCreatedEffect
- [x] The map viewer draws effects and missiles with their models (Birth, Stand, Death), at the unit model's attachment points; ranged attacks fly their missile model (ua1m); a marker where a model isn't found; the aimed spell's area under the pointer
- [x] `test_effects.lua`: 32 tests; related suites pass

## Implementation Notes

**Date:** 2026-09-30

### Where art comes from

- **Lookup:** `g.ability_art(id, level, kind)` and `g.buff_art(id, kind)` read a field code (acat, atat, aeat, asat, aaea, amat, alig; for buffs ftat, feat, fsat).
  - The map's change comes first (object_stock).
  - Failing that, the stock profile field by name (CasterArt, TargetArt ...: `object_stock:profile_field`), since not every art code is certain here.
- **Values:** comma-separated lists of model paths; every one plays.
- **Buffs** are a new object kind (`AbilityBuffMetaData.slk`, `AbilityBuffData.slk`), in `g.data.buffs`.
- **Checked on DAoW 5.4b** (its own changes, no install):
  - Its Storm Bolt copy A0AI flies MoonPriestessMissile.
  - Its aura A0FZ shows `war3mapImported\lightaura.mdx`, a model the map imports and the asset source finds.
  - Here it draws as a marker: its textures are the install's.

### `demo/wc3map/effects.lua`

- **Effects** (`g.effects`): path, a point or a unit and attachment point, a kind, an optional end time; attached effects follow their unit.
- **Destroying:** `g.destroy_effect` marks one dying; it stays `DEATH_LINGER` (1.5 s) for its Death, then goes.
- **Missiles** (`g.launch`): home on a unit or fly to a point, at the ability's missile speed (amsp / Missilespeed, else 1000), rising and falling by its arc, and call back when they land.
- **Buff hooks:** `g.on_buff_added` / `g.on_buff_removed` (buffs.lua calls them) attach and end a buff's art. An aura's buff carries its ability's target art. An aura refresh keeps the art already playing.

### Casting (`abilities.lua`)

- **`abilities.land`** at the spell's effect:
  - Caster art on the caster (1.5 s).
  - Then, if the spell has missile art (or its base is a missile spell: Storm Bolt, Death Coil) and a unit target, a missile; when it arrives, target art on the target, and the effect (if the target still lives).
  - Point spells play effect and area art at the point.
- **`abilities.target_ok`:**
  - The ability's `atar` flags, by group (kind, side, hero, body, life, vulnerability); a group named must match one of its flags.
  - Without flags, the base's enemies / allies rule.
  - Unit and unit-or-point spells check it.

### The script (`jass/natives/art.lua`)

- **Effects:** the natives in the criteria, as effect handles (the game's records).
- **Effect types** by name or number.
- **No-ops:** the ones these natives replace are gone from `interface.lua` and `bj.lua`.

### Drawing (`demo/wc3map/draw_effects.lua`, `main.lua`)

- **Models:** each effect's model (the asset source's), playing Birth, then Stand, then Death once destroyed (one without Death disappears).
- **Attachment points:** the unit model's attachment node pivot ("Overhead Ref" ...), turned with the unit (rest pose), else a height by name.
- **Missiles:** they face their way.
- **Ranged attacks:** they fly the unit's missile model (ua1m) when found, else the old arrow.
- **Where no model is found,** a small ring coloured by kind (a missile: an arrow).
- **Aiming:** while aiming a spell, a ring of its area follows the pointer.
- **Scripted actions** for runs and screenshots: `herolevel:N` (the selected hero to a level, learning what it can) and `cast:<ability>` (at the nearest enemy).

### Not yet

- **Attachment points** use the rest pose (they don't follow the model's animation).
- **Lightning effects** (chain lightning, drains) are read but not drawn; chain effects bounce nowhere.
- **Sounds,** and the art's scale and colour fields.
- **Ranged attacks'** missile arc and speed still come from combat's own (ua1z speed; arc not read).
- **The HUD** has no custom cursor; the aiming ring and the "Select a target" line stand in.
