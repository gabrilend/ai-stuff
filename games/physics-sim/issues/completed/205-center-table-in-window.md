# Issue 512: Center Table in Window

## Current Behavior

The game table (pegs, zones) is positioned starting from x=0, which works
when window width equals table width. If window is wider, table is left-aligned.

## Intended Behavior

The game table should be horizontally centered in the window:
1. Calculate table offset: (window_width - table_width) / 2
2. Apply offset to all world elements (pegs, zones)
3. Keep balls within table bounds
4. Update spawn point to be centered

## Suggested Implementation Steps

1. Add `x_offset` field to World struct (or calculate dynamically)
2. Modify peg generation to use offset
3. Modify zone generation to use offset
4. Update ball spawning to use centered position
5. Update rendering to account for offset

## Design Notes

Table width is fixed at 800px (8 cols * 60px spacing + margins).
Offset = (window_width - 800) / 2

## Success Criteria

- Table is centered regardless of window width
- Balls spawn at center of table
- Zones are centered
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Added table bounds to World struct (src/004-world.h:49-54):
- `table_x`: Left edge offset for centering
- `table_width`: Fixed width (800px)
- `table_top`: Y position where pegs start
- `table_bottom`: Y position of zone bottom

Added `world_set_table_bounds()` function (src/005-world.c:222-235):
- Centers table: `table_x = (window_width - table_width) / 2`
- Called at startup and on window resize

Peg generation updated to use `world->table_x` for positioning.
Zone generation updated to use `world->table_x` for x bounds.
Ball wall collision updated to use table bounds instead of screen edges.

Spawn point (SPAWN_X) remains at fixed 400px, which is center of 800px table.
