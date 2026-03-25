# 611 - Portal Improvements

## Status: Complete

## Problem

1. Portal in/out zones are too large - should be one grid square
2. Need to validate that entry portals select random exit from same channel
3. Editor should prevent saving if a channel has entries but no exits
4. Runtime should display error message if ball enters channel with no exits

## Current Behavior

- Portal zones are exactly one grid square (DEFAULT_PORTAL_SIZE = 1)
- Random exit selection verified working in portal_manager_check_ball
- Editor blocks save and shows notification if orphan channels found
- Runtime prints fun error message when ball enters channel with no exits

## Implementation

1. Changed `DEFAULT_PORTAL_SIZE` from 2 to 1 in `src/032-editor-app.c`
   - Portal zones now 50x50 pixels (one grid cell)

2. Verified random exit selection already works correctly:
   - `portal_manager_check_ball` uses `rand() % channel->exit_count` to select exit
   - Teleports ball to selected exit's center position

3. Added `board_data_validate_portals` function:
   - Declaration in `src/020-board-data.h`
   - Implementation in `src/021-board-data.c`
   - Counts entries/exits per channel (1-16)
   - Returns orphan channel number if entries exist without matching exits

4. Added save-time validation in editor:
   - `editor_app_save` calls validation before writing file
   - Save dialog KEY_ENTER handler also validates
   - Shows notification "Channel X has no exit!" and blocks save

5. Updated runtime warning in `src/029-portal.c`:
   - Now prints fun message when ball enters orphan channel

## Files Modified

- `src/020-board-data.h` - Added board_data_validate_portals declaration
- `src/021-board-data.c` - Added board_data_validate_portals implementation
- `src/029-portal.c` - Updated runtime warning message
- `src/032-editor-app.c` - Changed portal size, added save validation
