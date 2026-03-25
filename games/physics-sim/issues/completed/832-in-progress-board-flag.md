# 832 - In-Progress Board Flag

## Status: Complete

## Problem

Users editing boards may want to save incomplete work without having those unfinished boards appear in random stage selection during gameplay.

## Current Behavior

- All boards in the boards/ directory are eligible for random selection
- No way to mark a board as "work in progress"
- Users must either finish a board or delete it to prevent it appearing in-game

## Intended Behavior

1. Save dialog shows an "In-progress" checkbox
2. When checked, board JSON includes `"in_progress": true` field
3. Random board selection skips boards with in_progress flag
4. Editor can still load and edit in-progress boards normally

## Implementation Steps

1. Add `in_progress` field to BoardData struct in `src/020-board-data.h`
2. Update JSON load/save in `src/021-board-data.c` to handle field
3. Add checkbox UI to save dialog in `src/032-editor-app.c`
4. Update `stage_pool_select_random` in `src/027-stage-pool.c` to skip in-progress boards
5. Test: save board with flag, verify it doesn't appear in random selection

## Files Modified

- `src/020-board-data.h` - Added in_progress field to BoardData
- `src/021-board-data.c` - JSON load/save for in_progress boolean
- `src/031-editor-app.h` - Added in_progress to SaveDialogState
- `src/032-editor-app.c` - Checkbox in save dialog (TAB to toggle)
- `src/027-stage-pool.c` - Filter out in-progress boards at scan time

## Implementation

1. Added `int in_progress` field to BoardData struct
2. JSON serialization writes `"in_progress": true` when flag is set
3. Save dialog shows checkbox with TAB to toggle
4. Stage pool loads each board on scan and skips those with in_progress flag
