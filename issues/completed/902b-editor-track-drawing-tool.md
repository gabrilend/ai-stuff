# 902b - Editor Track Drawing Tool

## Status: Completed

## Parent Issue: 902 - Track Mover System

## Depends on

- 902a (Track data structure) - Completed

## Problem

Need an editor tool to draw track segments on the board. Tracks are paths for movers to follow, similar to lines but forming a network for movement rather than collision.

## Current Behavior

- No track drawing tool exists in the editor
- Track data structures exist in BoardData (from 902a)
- Cannot create boards with tracks

## Intended Behavior

1. New "Track" tool button in the editor tools panel
2. Click to place track segment endpoints (like line tool)
3. Track segments connect at shared endpoints automatically
4. Visual distinction from collision lines (dashed/different color)
5. Track segments saved to JSON via existing serialization

## Technical Design

### Tool State Machine

Similar to line tool:
```c
typedef enum TrackToolState {
    TRACK_STATE_IDLE,      // Waiting for first click
    TRACK_STATE_END        // First point set, positioning end
} TrackToolState;

typedef struct TrackToolData {
    TrackToolState state;
    int start_col, start_row;
    int end_col, end_row;
    float start_x, start_y;
    float end_x, end_y;
} TrackToolData;
```

### Editor Changes

1. Add `APP_TOOL_TRACK` to EditorAppTool enum in `031-editor-app.h`
2. Add `TrackToolData` struct to editor header
3. Add `track_tool` field to EditorApp struct
4. Handle track placement in `editor_app_update()`
5. Render track preview and existing tracks in `editor_app_render()`
6. Add track button to tools panel

### Visual Rendering

Tracks should be visually distinct from collision lines:
- Thinner line (2-3px vs 10px default for lines)
- Different color (cyan/teal instead of orange)
- Optional: dashed pattern to indicate "path, not obstacle"
- Draw small circles at endpoints to show connection points

### Connectivity

- When placing a track segment, snap to existing track endpoints
- Segments sharing an endpoint are connected in the network
- Call `board_data_compute_track_connectivity()` after changes

## Implementation Steps

1. Add `APP_TOOL_TRACK` to EditorAppTool enum
2. Add TrackToolData struct and field to EditorApp
3. Add "T" keyboard shortcut for track tool
4. Handle track placement clicks in update function
5. Add track preview rendering (endpoint circles + line)
6. Add existing track segment rendering
7. Add track button to tools panel (after rotor)
8. Test connectivity computation when tracks share endpoints

## Files to Modify

- `src/031-editor-app.h` - Add TRACK tool enum, TrackToolData struct
- `src/032-editor-app.c` - Tool handling, rendering, panel button
- `src/035-object-render.c` - Track segment rendering function

## Visual Design

Track segments:
- Color: (80, 200, 220, 255) - Cyan/teal
- Thickness: 3px
- Endpoint circles: 4px radius, same color
- Preview: Semi-transparent version during placement

## Notes

- Tracks don't collide with balls (unlike lines)
- Tracks are visual paths for movers to follow
- Intersection detection is computed on load (not stored in JSON)
- Simpler than line tool: no thickness adjustment needed

## Implementation Complete

### Changes Made

1. **src/031-editor-app.h**:
   - Added `APP_TOOL_TRACK` to EditorAppTool enum
   - Added `TrackToolState` enum (TRACK_STATE_IDLE, TRACK_STATE_END)
   - Added `AppTrackToolData` struct with grid/pixel position tracking
   - Added `track_tool` field to EditorApp struct

2. **src/032-editor-app.c**:
   - Added track_tool initialization in editor_app_create()
   - Added KEY_SIX keyboard shortcut for track tool
   - Updated tool_values arrays to include APP_TOOL_TRACK (toolbar + sidebar)
   - Added handle_track_tool() function for two-click placement
   - Added track tool preview in render_cursor_preview()
   - Added right-click cancellation for track tool
   - Updated place_object switch to handle APP_TOOL_TRACK

3. **src/034-object-render.h**:
   - Added render_track_segment(), render_track_preview(), render_board_tracks() declarations

4. **src/035-object-render.c**:
   - Added track rendering constants (TRACK_COLOR cyan, 3px thickness, 4px endpoints)
   - Implemented render_track_segment() with endpoint circles
   - Implemented render_track_preview() for semi-transparent preview
   - Implemented render_board_tracks() to render all track segments

5. **Bug Fix (044-rotor.c)**:
   - Fixed incorrect struct member names (connected_count → connection_count, connected_indices → connections[i].object_index)

### Usage

1. Press `6` or click "Track" button to select track tool
2. Click first point to set start
3. Move mouse to end point, click to confirm
4. Right-click to cancel mid-placement
5. Track segments appear as cyan lines with white-outlined endpoint circles

### Unblocks

- 902c (Mover placement) - can now place movers on tracks
- 902d (Track following physics) - tracks exist to follow
