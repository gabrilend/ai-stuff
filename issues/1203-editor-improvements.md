# 1203 - Editor Improvements

## Overview

Several improvements and bug fixes needed for the standalone board editor (`bin/board-editor`).

## Issues

### 1. Loading Feature Broken

**Current:** File is selected in load dialog, but board display doesn't change after loading.

**Expected:** Selected board file loads and displays in the canvas.

**Likely Cause:** The loaded board data isn't being applied to the grid, or the grid isn't being refreshed after load.

### 2. No Filename Prompt on Save

**Current:** Save generates an automatic timestamp filename without user input.

**Expected:** Editor prompts user to enter a filename before saving.

**Implementation:** Add a text input dialog before `board_data_save_json()`.

### 3. Objects Snap to Cell Centers

**Current:** Objects are placed at grid cell centers.

**Expected:** Objects should snap to grid line intersections (vertices) for more precise placement.

**Implementation:** Change `grid_to_pixel_x/y` usage to return intersection points rather than cell centers, or add offset of `cell_size/2`.

### 4. No Scrolling/Panning

**Current:** Canvas is fixed, cannot scroll to see boards larger than the window.

**Expected:** User can scroll up/down to pan the view, similar to the game.

**Implementation:** Add scroll wheel handling and Camera2D offset adjustment.

### 5. Guard Rails Not Visible

**Current:** The editable area is implied by grid bounds but rails aren't drawn.

**Expected:** Draw visible guard rails (vertical lines) on left and right edges of the playable area to match game appearance.

**Implementation:** Add rail rendering in `render_canvas()`.

## Suggested Implementation Order

1. **Fix loading** - Critical bug, highest priority
2. **Add guard rails** - Quick visual improvement
3. **Grid intersection snap** - Affects object placement accuracy
4. **Add scrolling** - Enables larger boards
5. **Filename prompt** - UX improvement

## Files to Modify

- `src/032-editor-app.c` - Main editor logic
- `src/035-object-render.c` - Add rail rendering if needed

## Testing

1. Load dialog: Select file, verify board appears
2. Save: Verify filename prompt appears
3. Placement: Click grid intersection, verify object appears at vertex
4. Scroll: Use scroll wheel, verify canvas pans
5. Rails: Verify vertical lines visible on left/right edges

## Related Issues

- 1201-standalone-editor-application.md (original implementation)
