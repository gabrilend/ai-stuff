# Issue 513: Scroll Limits to Keep Table Visible

## Current Behavior

Scroll limits are based on world height vs screen height. User can scroll
such that the entire table could theoretically move off screen.

## Intended Behavior

Scroll limits should ensure the table is always partially visible:
1. Top of table can never go below bottom of screen
2. Bottom of table can never go above top of screen
3. User can scroll to see empty space above/below table
4. But table itself is always on screen somewhere

## Suggested Implementation Steps

1. Define table bounds (top_y = peg_start_y, bottom_y = zone_bottom)
2. Calculate scroll limits:
   - Min offset: table_top cannot go below screen_bottom
     → viewport_offset_min = table_top - screen_height
   - Max offset: table_bottom cannot go above screen_top
     → viewport_offset_max = table_bottom
3. Clamp viewport_offset_y to [min, max]
4. Allow negative offsets (scroll above table)

## Design Notes

Current clamp is [0, world_height - screen_height].
New clamp allows scrolling into "empty space" above and below table,
but ensures table is always visible.

## Success Criteria

- Can scroll to see space above table
- Can scroll to see space below table
- Table never completely leaves viewport
- Smooth scrolling experience
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Updated scroll limit calculation in main loop (src/001-main.c:189-200):

Old limits: `[0, world_height - screen_height]`
New limits: `[table_top - screen_height, table_bottom]`

The new limits ensure:
- Minimum offset allows scrolling up until table top is at screen bottom
  (min_offset = table_top - screen_height, can be negative)
- Maximum offset allows scrolling down until table bottom is at screen top
  (max_offset = table_bottom)

Same clamping logic applied in resize handler to keep viewport valid.
