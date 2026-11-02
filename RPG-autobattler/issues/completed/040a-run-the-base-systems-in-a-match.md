# Issue 040a: Run the Base Systems in a Match

## Current Behavior
Bases, shields, turrets, shield destruction and the unit reset (issues
036-040) exist as separate systems, but nothing creates them. The game
state shows a test pattern and a tutorial; no match is ever played.

## Intended Behavior
Entering the game state starts a match: two bases at the edges of the
field, each with three shields and a turret, and the unit reset ready. The
match advances while the game is not paused, and stops when a base falls.
All of it can be run without a window.

## Suggested Implementation Steps
1. Add a Match object that owns an entity manager, both bases and the
   base, turret and reset systems, and runs them in order each frame.
2. Create a Match in `GameState:enter`, update it in `GameState:update`
   while unpaused, restart it on R, drop it on exit.
3. Test a match headlessly through a shield fall, a reset and a victory,
   and the game state with a stand-in LÖVE.

## Related Issues
- 036 to 040 (completed)
- 040b-units-attack-bases-and-shields.md
- A separate change draws all of this with plain shapes.

## What Happened

Built as `src/systems/match.lua` and wired into
`src/systems/game_state.lua`. Each frame the match runs the turrets, then
the bases, then hands the bases' events to the reset, and keeps every event
(stamped with match time) for the drawing and UI to read with
`pop_events()`. Once a base falls the match stops updating. Tested by
`tests/test_match.lua` (four tests), including the real `GameState` with a
stand-in `love` table: entering creates the match, the tutorial holds it,
escape starts play, a shield falls, the reset clears the attackers, R
starts a new match and exit drops it. Nothing was seen on screen.

### Decisions
- **Where the bases sit:** 80 pixels in from the left and right edges at
  mid-height, team 1 on the left. The map generator's spawn points are not
  used yet, because the game state does not build a map.
- **Order within a frame:** turrets, bases, reset. A shield that falls
  this frame is reported by the bases' update on the next frame, and the
  reset starts then.
- **R** ("reset everything" in the tutorial text) now also starts a fresh
  match.
- **Units cannot attack bases yet.** No combat system targets a base, so
  the tests stand in for unit attacks by calling `Base.apply_damage` for
  each attacker in reach. That gap is written up as issue 040b.
