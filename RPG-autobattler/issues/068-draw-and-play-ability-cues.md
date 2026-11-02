# Issue 068: Draw and Play Ability Cues

## Current Behavior
The ability effect system (`src/systems/ability_effect_system.lua`) works
out every hit, heal, miss and effect, but draws and plays nothing. It
keeps cues for someone else to show:
- `pop_cues()` returns `{kind, x, y, amount, target, caster, visual,
  sound, ...}`.
- The kinds are damage, heal, effect_applied, effect_expired,
  projectile_launched, projectile_hit, projectile_miss, area and death.

There is more for a renderer to read:
- Projectiles in flight are in `effect_system.projectiles`.
- Lasting zones are listed by `PersistentEffectsSystem:get_zones()`.
- Effects on a unit are in its "effects" component and in
  `PersistentEffectsSystem:get_effects_on(unit)`.

The visual and audio criteria of issues 051-054 were left for this
issue:
- weapons that look and sound different (051);
- healing that shows its kind (052);
- active buffs and debuffs shown on units (053);
- area and zone boundaries (054).

## Intended Behavior
Players can see and hear what abilities do:
- **Floating numbers** for damage and healing, coloured by kind. A miss
  shows as "miss".
- **Projectiles** drawn in flight, shaped by their `visual_effect` (arrow,
  bolt, stone, javelin, dart).
- **Melee swings** drawn from the caster toward the target, wider for
  cleaving weapons.
- **Small icons or tints** on units for active buffs and debuffs, and
  for damage or healing over time.
- **Area casts** flash their circle. Zones draw their circle for as long
  as they last, fading as they run out.
- **Each cue's `sound_effect`** is played when sound files exist. When
  they don't, nothing is played and nothing fails.

## Suggested Steps
1. Add `src/systems/ability_cue_renderer.lua`. It should take cues each
   frame, keep short-lived floating numbers and flashes, and draw them
   with plain LÖVE shapes and text, as the mana bar renderer (045) does.
2. Draw projectiles from `effect_system.projectiles`, and zones from
   `get_zones()`.
3. Add a small sound player that maps `sound_effect` names to files, if
   present.
4. Test headlessly with recorded graphics calls, as
   `tests/test_mana_bar_renderer.lua` does.
5. Someone must look at it running and listen to it before it's called
   done.

## Depends On
- The ability stack, ending at the PR that reconciled issues 051-056.
- Issue 067 (match units with ability sets), for cues to appear in a
  real match.

## Acceptance Criteria
- [ ] Damage, healing and misses show as floating numbers or words
- [ ] Projectiles and melee swings are drawn, and weapons look different
- [ ] Active buffs, debuffs and over-time effects show on units
- [ ] Area casts and lasting zones show their boundaries
- [ ] Sounds play by name when present, and nothing fails when they're not
- [ ] Recorded-call tests pass headlessly
- [ ] Seen and heard by a person

## Related Issues
- 045 (mana bars drawn), 049 (cues), 051-054 (what's being shown), 067
