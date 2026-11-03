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
