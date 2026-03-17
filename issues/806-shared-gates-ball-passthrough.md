# Issue 806 - Shared Gates / Ball Passthrough

## Status
Pending

## Current Behavior
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
