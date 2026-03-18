# 1226 - Drag-to-Select and Multi-Edit

## Status: Complete

## Problem

Editing properties on multiple objects requires selecting and modifying each one individually. This is tedious when adjusting values across many pegs or lines.

## Current Behavior

- Can only select one object at a time
- Must click each object individually
- Property changes apply to single selected object only

## Intended Behavior

1. Click and drag to create selection rectangle
2. All objects within rectangle become selected
3. Selected objects highlighted with distinct visual (e.g., outline or glow)
4. Property panel shows "Multiple selected" when >1 object selected
5. Changing a property applies to all selected objects
6. Click empty space to deselect all
7. Shift+click to add/remove from selection
8. Ctrl+A to select all objects

## Implementation

### EditorApp Struct Changes (`src/031-editor-app.h`)

Added multi-selection state:
```c
// Selection/property editing (issue 1226 - multi-select)
int* selected_indices;      // Array of selected object indices
int selection_count;        // Number of selected objects
int selection_capacity;     // Allocated capacity of selected_indices

// Drag selection state
int is_drag_selecting;      // Currently dragging to select
float drag_start_x, drag_start_y;  // Start position in pixels
```

### Selection Helper Functions (`src/032-editor-app.c`)

Added selection management functions:
- `selection_clear()` - Clears all selected objects
- `selection_contains()` - Check if object is in selection
- `selection_add()` - Add object to selection
- `selection_remove()` - Remove object from selection
- `selection_toggle()` - Toggle object in/out of selection
- `selection_set_single()` - Replace selection with single object
- `selection_select_all()` - Select all objects
- `selection_select_in_rect()` - Select objects within rectangle

### Input Handling

- Right-click drag: Creates selection rectangle, selects objects within
- Right-click (no drag): Selects single object at cursor
- Shift+right-click: Toggles object in/out of selection
- Ctrl+A: Selects all objects
- ESC: Clears selection

### Rendering

- `render_selection_highlights()` - Draws cyan highlight circles around selected objects
- `render_drag_selection_rect()` - Draws semi-transparent rectangle while dragging

### Property Panel

- Shows "Multiple (N)" when N objects selected
- Property changes apply to all selected objects
- Uses first selected object's values for slider display

## Files Modified

- `src/031-editor-app.h` - Added selection state fields
- `src/032-editor-app.c` - Selection logic, rendering, input handling

## Notes

- Legacy `selected_object_index` field maintained for compatibility
- Selection array grows dynamically as needed
- Drag threshold of 10 pixels distinguishes click vs drag
