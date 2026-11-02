# Issue 067: Spawn Match Units With Ability Sets

## Current Behavior
Two pieces of work are waiting to merge, on separate stacks:
- **The base stack** (#47 → #51 → #55 → #58 → #60 → #73 → #75):
  - bases, shields, the turret and the shield-fall reset;
  - `src/systems/match.lua`, run by `game_state.lua`;
  - the match drawn in plain shapes.
- **The ability stack** (#63 → #80 → #82 → #90 → #94 → #96 → #101 → #104
  → #105):
  - mana bars and their charging rules;
  - abilities of five kinds, with targeting and activation;
  - effects, cooldowns, effects over time and templates;
  - the mana bars drawn above units.

The match doesn't use any of the ability work:
- `Match:spawn_unit` makes plain units with no abilities or mana.
- The match's update doesn't run `ManaSystem`, `AbilityActivationSystem`,
  `AbilityEffectSystem`, `CooldownSystem` or `PersistentEffectsSystem`.
- Nothing draws the mana bars in play.

So an autobattler's units never use the abilities just built.

## Intended Behavior
Ritz decided (Round 3): matches spawn units with ability sets, so every
unit in play charges mana and uses its abilities on its own.
- Each unit spawned by the match gets an ability set chosen by its unit
  type, from `src/data/ability_templates.lua`.
- The match runs mana, activation, effects, cooldowns and effects over
  time every update. Defeated units' mana and effects end.
- The match renderer draws the mana bars above its units, and passes
  activation events to the bar renderer so kept mana shows.
- Everything stays testable without a screen: a headless test runs a
  match whose units fight with their abilities.

## Depends On
- The base stack, ending at #75 (match wiring and match drawing).
- The ability stack, ending at #105 (abilities through mana bar drawing).

Don't start until both are merged to main. Building it now would need a
merge commit across the two stacks.

## Suggested Implementation Steps
1. Add a table of default sets by unit type in `src/data/ability_templates.lua`:
   - melee: `basic_warrior`;
   - ranged: `basic_archer`;
   - support: `support_cleric`;
   - tank: `brute`;
   - special: `battle_mage`.
   Let `Match:spawn_unit` take a set name that overrides it.
2. In `Match:spawn_unit`, call `AbilityFactory.attach_set(em, unit,
   set_name)` after making the unit.
3. In `Match:new`, make the systems in this order, sharing one entity
   manager:
   - `ManaSystem`;
   - `AbilityEffectSystem` (with the match's `random`);
   - `PersistentEffectsSystem(em, effects)`;
   - `AbilityActivationSystem(em, {effect_system = effects})`, which
     makes its own targeting and cooldowns.
   Expose them for tests and the renderer.
4. In `Match:update`, after the turret and base systems and before the
   reset:
   - run mana, then activation, then effects, then persistent effects;
   - stamp the activation events and effect cues with the match time;
   - add them to the match's events.
   Skip all of it once the match is over, as the base systems do.
5. Check that the shield-fall reset's unit removal also clears removed
   units' effects and over-time effects, so nothing ticks on a removed
   unit.
6. In `MatchRenderer.draw`:
   - keep one `ManaBarRenderer` per match;
   - update it with the match clock;
   - call `notice()` for each activation event;
   - draw it after the units.
   Mark the result as not yet seen on screen.
7. Add a headless test to `tests/test_match.lua`:
   - spawn two small teams with ability sets near each other;
   - run the match for some seconds;
   - check that abilities fired, damage and healing happened, and the
     events carry match time.
   Add a recorder test that the renderer draws mana bars over spawned
   units.

## Related Issues
- 040a-run-the-base-systems-in-a-match.md (match wiring, #73)
- 040b-units-attack-bases-and-shields.md
- 040c-draw-the-match-with-plain-shapes.md (#75)
- 041-050 and 045 (the ability stack, #63-#105)
