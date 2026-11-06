# Issue 040b: Units Attack Bases and Shields

## Current Behavior
Bases and shields take damage through `Base.apply_damage` and
`Base.damage_shield`, and the match runs them, but no unit ever calls
these. Melee and ranged combat look only for enemy units, so a unit that
reaches the enemy base stands there, and a match can never be won in play.
The match tests stand in for unit attacks.

## Intended Behavior
A unit with no enemy unit in reach, but within reach of an enemy base or
one of its shields, attacks it with its normal attack: melee at melee
range, ranged from its range, passing its own id so concentrated fire is
recognised (issue 039).

## Suggested Implementation Steps
1. Decide how a base is a target: the front shield's position while any
   shield stands, then the core. `Base.get_shields` and
   `DefenseShield.get_front_shield` give the positions.
2. In the combat that picks targets, fall back to the nearest enemy
   base or shield in reach when no enemy unit is found.
3. Route the hit through `Base.apply_damage(entity_manager, base, amount,
   attacker_team, attacker_id)`, or `Base.damage_shield` for a side shield.
4. Replace the stand-in attacks in `tests/test_match.lua` with real units
   walking up and attacking, and check a match ends in victory.

## Related Issues
- 040a-run-the-base-systems-in-a-match.md
- 026-027, 031-032 (completed): unit combat

## What Happened

Built as `src/systems/base_assault_system.lua`, run by the match after the
turrets and before the bases. Each frame, for each living unit not being
reset:
- **Enemy unit in reach:** it's left alone. Fighting units is the combat
  systems' job.
- **Enemy base in reach:** it hits with its normal attack through
  `Base.apply_damage(em, base, damage, team, unit.id)`. That means the
  front shield while one stands, then the core.
- **Otherwise:** it walks straight toward that target and stops at its
  reach.

Each hit is recorded as a `base_attacked` event.

`tests/test_match.lua` no longer stands in for attacks. Its shield-fall,
victory and game-state tests now run on real units walking up and
attacking, and a match still ends in team 1's victory. The new
`tests/test_base_assault.lua` covers:
- walking and stopping at reach;
- hit timing;
- shields before the core;
- enemy units in reach;
- reach by type;
- march off;
- reset units;
- concentrated fire from three attackers.

All of it is headless. Units now move in the match, which the match
drawing (#75) shows, but nobody has seen it on screen.

### Decisions
- **A new small system, not a change to MeleeCombatSystem.** The match runs
  no unit combat yet, and MeleeCombatSystem depends on a combat detection
  system that's never created and on `love.timer`.
- **Normal attacks by type:**

  | Type | Reach | Damage | Interval |
  |---|---|---|---|
  | melee | 15 | 15 | 1.0 s |
  | tank | 15 | 12 | 1.2 s |
  | ranged | 30 | 15 | 1.5 s |
  | support | 25 | 8 | 1.5 s |
  | special | 20 | 18 | 1.5 s |

  Melee matches MeleeCombatSystem's 15 damage each second at reach 15.
  Ranged matches the projectile system's default 15 damage from the
  30-pixel shooting range. The rest are first guesses for balancing.
- **Reach is measured to the edge of the target:** a shield counts as 9
  pixels across (the radius it's drawn at), the core as half its size.
- **Walking is a straight line at the unit's speed**, standing in for lane
  following, which the match doesn't run. `Match:new{march = false}` turns
  it off. Units don't avoid each other while walking.
- **A unit's first hit comes as soon as it arrives**, then one per interval.
- **Ranged hits land at once.** They don't fly as projectiles: the turret's
  shots are the only projectiles the match moves.
- **Abilities don't attack bases yet.** Issue 067 brings ability sets into
  the match. Targeting bases with abilities can follow once that lands.
