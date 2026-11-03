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
- [x] Recorded-call tests pass headlessly
- [ ] Seen and heard by a person

## Related Issues
- 045 (mana bars drawn), 049 (cues), 051-054 (what's being shown), 067

## What Happened (so far)

The drawing and the sound are built and tested with recorded calls, the
way the mana bars (045) were. Like 045, the issue stays open: no one has
seen or heard any of it, and its other boxes are about what a person
sees and hears. It isn't wired into a match yet; that comes with issue
067.

- `src/systems/ability_cue_renderer.lua` takes the effect system's cues
  each frame and keeps short-lived things to draw:
  - floating numbers that rise and fade, coloured by kind (physical,
    magical, true, over time, healing, healing over time; healing has a
    "+"); a miss shows "miss";
  - melee swings from caster to target: an arc shaped by weapon (sword,
    wider axe, short dagger), a straight thrust for a spear, half again
    wider when the weapon cleaves; arrows and over-time ticks don't
    swing;
  - area casts flash their circle; deaths draw a fading cross.
  It also draws from the systems' state: projectiles in flight, shaped by
  `visual_effect` (arrow and javelin with heads, a heavy-tipped bolt, a
  stone, a short dart, an orb for anything else); zones as circles that
  fade as they run out; and on each living unit a row of markers, a
  triangle pointing up per buff and down per debuff (with a stack
  count), a ring when stunned, and a dot per effect over time.
  `draw(g, world, view)` takes the graphics object and the same view
  (offset and zoom) as the mana bar renderer.
- `src/systems/sound_player.lua` plays a cue's `sound_effect` from
  `assets/sounds/<name>.ogg` or `.wav`. With no file, no audio module or
  a broken file, nothing plays and nothing fails. Each name is looked up
  once, and names can't leave the folder.
- Damage cues now carry `delivery`, `weapon`, `cleave` and `damage_type`,
  and damage and heal cues carry `over_time` for a tick, so the renderer
  can tell a sword from an arrow or a poison tick. The balance harness
  keeps each step's cues as `world.last_cues`.
- `tests/test_ability_cue_renderer.lua` (7 tests, including a real
  headless battle drawn every frame), run by `./run <dir> unit`.

### Decisions

- Melee swings are drawn from damage cues that aren't projectiles or
  ticks, rather than adding a separate swing cue: every melee hit
  already makes a damage cue with its caster.
- Each kind differs by more than colour: buffs and debuffs by which way
  the triangle points, healing by its "+", misses by a word, as the mana
  bars do.
- No sound files are added; the game plays none until someone adds them
  to `assets/sounds/`, named after the `sound_effect` in each ability.

