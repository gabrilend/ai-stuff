# Issue 804 - Adversary Board Layout

## Status
Pending

## Current Behavior
Single pachinko board. World height accommodates one table with scrolling.

## Intended Behavior
- Second board positioned below player's board
- Adversary board is visually flipped (their "top" at bottom)
- Their gates are at the top of their board (our bottom)
- Visual distinction between player and adversary areas
- Shared gate row serves both boards

## Suggested Implementation Steps

1. **Extend World structure**
   - Add adversary_table_top, adversary_table_bottom
   - Add adversary_pegs array and adversary_peg_count
   - Rename existing peg/zone arrays to player_* prefix

2. **Calculate adversary board position**
   - Adversary table_top = player table_bottom + gate_height
   - Adversary table_bottom = adversary_table_top + table_height
   - Gates serve as shared boundary

3. **Generate adversary pegs**
   - Mirror the player's peg layout
   - world_generate_adversary_pegs() function
   - Pegs positioned relative to adversary bounds
   - Stagger pattern inverted (or mirrored)

4. **Update world rendering**
   - world_render_adversary_pegs() function
   - Different peg color for adversary (red-tinted?)
   - Clear visual boundary between boards

5. **Extend world height for scrolling**
   - Update scroll limits to include adversary board
   - User can scroll to see full adversary area
   - Consider split-screen or minimap for overview

6. **Update table bounds calculation**
   - world_set_table_bounds() handles both boards
   - Shared table_width and table_x centering

## Dependencies
- Phase 7 complete (viewport and scrolling)

## Related Documents
- src/004-world.h (World struct)
- src/005-world.c (world generation functions)

## Notes
- The "flip" is conceptual: adversary spawns at bottom, balls go up
- Gates remain in the same physical location, shared by both boards
- Adversary pegs don't need collision with player balls (handled in 807)
- Visual hierarchy: player board brighter, adversary slightly dimmer
