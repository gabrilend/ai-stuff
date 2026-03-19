# 1304 - Stage Spawning Mechanic Investigation

## Status: Open

## Problem

The stage spawning/expansion mechanic is broken when adding new stages. Parts appear in wrong positions and the layout is incorrect.

## Current Behavior

- When new stage is added, parts appear in wrong places
- Layout doesn't match expected stage configuration
- Something is fundamentally broken in the stage addition process

## Intended Behavior

1. New stages should spawn with correct object positions
2. Stage layout should match the loaded board data
3. Expansion should integrate smoothly with existing stages

## Investigation Steps

1. Add debug logging to stage spawning code
2. Trace object positions from board data through to final placement
3. Check coordinate transformations during stage addition
4. Verify grid alignment between old and new stages
5. Check if slot-based layout system (issue 1221) is properly integrated
6. Test with simple board (few pegs) to isolate the issue

## Files to Investigate

- `src/015-stage.c` - Stage management
- `src/039-slot-manager.c` - Slot-based layout system
- `src/001-main.c` - Stage initialization and expansion triggers
- `src/021-board-data.c` - Board loading

## Diagnostic Output Needed

- Board data object positions after loading
- Grid origin and cell size values
- Final pixel positions of spawned objects
- Any coordinate transformations applied

## Notes

- Issue 1221 introduced slot-based layout foundation
- May be conflict between old and new coordinate systems
- Need to understand full data flow from JSON to rendered objects
