# Issue 514: Add Guard Rails on Sides

## Current Behavior

Balls collide with screen edges (walls) at x=0 and x=screen_width.
If window is wider than table (800px), balls can fall off the table edges
into empty space on the sides.

## Intended Behavior

Add visual guard rails on the sides of the table:
1. Rails positioned at table edges (not screen edges)
2. Balls collide with rails, not screen edges
3. Rails are visible as vertical bars
4. Rails extend full height of table

## Suggested Implementation Steps

1. Add rail positions to World struct (or calculate from table offset)
2. Update ball wall collision to use rail positions instead of screen edges
3. Add rail rendering (vertical rectangles or lines)
4. Consider rail visual style (match peg color or distinct)

## Design Notes

Rail positions:
- Left rail: table_offset_x
- Right rail: table_offset_x + table_width (800px)

Rails should look like physical barriers, not just invisible walls.
Could use same style as pegs or a distinct rail design.

## Success Criteria

- Balls cannot fall off sides of table
- Rails are visually distinct
- Rails work with any window width
- Collision feels natural
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Ball collision updated in `ball_collide_with_walls()` (src/007-ball.c):
- Left wall: `world->table_x`
- Right wall: `world->table_x + world->table_width`
- Balls now bounce off table edges, not screen edges

Added `world_render_rails()` function (src/005-world.c:238-266):
- Visual style: Dark industrial look (Color: 80, 80, 100)
- Rail width: 10px
- Rail highlight: 2px inner edge for depth
- Rails extend from above table_top to table_bottom
- Rendered before pegs (behind pegs visually)

Rails called in main render loop before other world elements.
