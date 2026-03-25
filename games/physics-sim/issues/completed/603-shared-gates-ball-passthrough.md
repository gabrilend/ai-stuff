# Issue 806 - Shared Gates / Ball Passthrough

## Status
Completed

## Current Behavior
- Balls entering score zones score points but continue through (not destroyed)
- passed_gate flag in Ball struct prevents double-scoring
- Player balls pass through gates and enter adversary board
- Adversary balls pass through gates and enter player board
- Particles still spawn on gate entry (once per crossing)
- Balls destroyed only at far boundary (player balls at adversary_table_bottom, adversary balls above spawn area)

## Previous Behavior
- Balls entering score zones are captured and destroyed
- Points are awarded and particles spawn
- Ball becomes inactive

## Intended Behavior
- Gates are shared between player and adversary boards
- Player balls entering gates pass through to adversary board
- Adversary balls entering gates pass through to player board
- Particles trigger once on gate entry
- Balls continue through to opposite board
- Balls destroyed only at far boundary (top or bottom)

## Suggested Implementation Steps

1. **Modify gate detection behavior**
   - Remove ball deactivation from zone scoring
   - Ball continues past zone instead of stopping
   - Score still awarded on zone entry

2. **Track gate passage state**
   - Add "passed_gate" flag to Ball struct
   - Prevents double-scoring on same gate
   - Reset when ball enters opposite board

3. **Implement passthrough physics**
   - Player balls continue downward into adversary board
   - Adversary balls continue upward into player board
   - No position teleportation, smooth transition

4. **Trigger particles on gate entry**
   - Keep existing particle burst
   - Only trigger once per gate crossing
   - Check passed_gate flag before spawning particles

5. **Update boundary destruction**
   - Player balls destroyed at adversary_table_bottom
   - Adversary balls destroyed at player_table_top (above spawn)
   - Remove intermediate destruction checks

6. **Visual gate enhancement**
   - Gates could have directional indicators
   - Or: visual pulse when ball passes through
   - Clear indication of shared nature

## Dependencies
- Issue 804 (Adversary Board Layout) must be complete

## Related Documents
- src/007-ball.c (ball_check_zone, zone collision)
- src/005-world.c (zone generation)

## Notes
- Scoring remains: balls still earn points passing through gates
- This creates risk/reward: balls that pass through help opponent
- Future: could have "blocker" power-up to capture balls at gates
- Future: gates could award different points based on direction

## Implementation Notes
- Added passed_gate field to Ball struct in src/006-ball.h
- Modified ball_update_task in src/007-ball.c:
  - Zone detection now checks !next->passed_gate before scoring
  - Sets passed_gate=1 after scoring instead of deactivating ball
- Modified ball_check_bounds in src/007-ball.c:
  - Takes World* instead of screen_height
  - Player balls (gravity_dir > 0) deactivate at adversary_table_bottom
  - Adversary balls (gravity_dir < 0) deactivate above spawn area
- ball_manager_spawn initializes passed_gate=0 for new balls
