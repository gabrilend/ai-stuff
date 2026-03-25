# 805 - Object Palette UI

## Current Behavior

No object palette exists. The editor mode (once implemented) needs a way to show available object types and indicate which one is currently selected.

## Intended Behavior

Create a visual palette showing all placeable object types:

1. Display palette on left side of screen in editor mode
2. Show icon/preview for each object type
3. Highlight currently selected object
4. Allow mouse click or number keys to select
5. Show object name on hover

Supported objects (Phase 11):
- Peg (circle)
- Ramp Left (diagonal \\)
- Ramp Right (diagonal /)
- Gate Row (horizontal bar)

## Suggested Implementation Steps

### Step 1: Define palette constants

```c
// src/024-editor.h

#define PALETTE_X 10
#define PALETTE_Y 100
#define PALETTE_ITEM_SIZE 50
#define PALETTE_ITEM_SPACING 10
#define PALETTE_BG_COLOR (Color){30, 30, 40, 220}
#define PALETTE_SELECTED_COLOR (Color){80, 120, 200, 255}
#define PALETTE_HOVER_COLOR (Color){60, 60, 80, 255}
```

### Step 2: Define palette item struct

```c
typedef struct PaletteItem {
    ObjectType type;
    const char* name;
    const char* shortcut;  // "1", "2", etc.
    Color preview_color;
} PaletteItem;
```

### Step 3: Initialize palette items

```c
// src/025-editor.c

static PaletteItem palette_items[] = {
    { OBJECT_PEG,        "Peg",        "1", LIGHTGRAY },
    { OBJECT_RAMP_LEFT,  "Ramp Left",  "2", (Color){200, 100, 80, 255} },
    { OBJECT_RAMP_RIGHT, "Ramp Right", "3", (Color){80, 100, 200, 255} },
    { OBJECT_GATE,       "Gate Row",   "4", GOLD }
};
#define PALETTE_ITEM_COUNT 4
```

### Step 4: Implement palette rendering

```c
void editor_render_palette(EditorState* editor) {
    int x = PALETTE_X;
    int y = PALETTE_Y;
    int width = PALETTE_ITEM_SIZE + 20;
    int height = PALETTE_ITEM_COUNT * (PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING) + 20;

    // Background panel
    DrawRectangle(x, y, width, height, PALETTE_BG_COLOR);
    DrawRectangleLines(x, y, width, height, (Color){80, 80, 100, 255});

    // Title
    DrawText("Objects", x + 5, y + 5, 12, LIGHTGRAY);

    // Items
    int item_y = y + 25;
    for (int i = 0; i < PALETTE_ITEM_COUNT; i++) {
        PaletteItem* item = &palette_items[i];
        int item_x = x + 10;

        // Selection/hover highlight
        Rectangle item_rect = { item_x, item_y, PALETTE_ITEM_SIZE, PALETTE_ITEM_SIZE };
        int is_selected = (editor->selected_object_type == item->type);
        int is_hovered = CheckCollisionPointRec(GetMousePosition(), item_rect);

        if (is_selected) {
            DrawRectangleRec(item_rect, PALETTE_SELECTED_COLOR);
        } else if (is_hovered) {
            DrawRectangleRec(item_rect, PALETTE_HOVER_COLOR);
        }

        // Draw preview icon
        editor_render_palette_icon(item, item_x, item_y, PALETTE_ITEM_SIZE);

        // Shortcut key indicator
        DrawText(item->shortcut, item_x + PALETTE_ITEM_SIZE - 12,
                 item_y + PALETTE_ITEM_SIZE - 14, 10, GRAY);

        item_y += PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING;
    }
}
```

### Step 5: Implement palette icon rendering

```c
static void editor_render_palette_icon(PaletteItem* item, int x, int y, int size) {
    int cx = x + size / 2;
    int cy = y + size / 2;
    int half = size / 3;

    switch (item->type) {
        case OBJECT_PEG:
            // Circle
            DrawCircle(cx, cy, half, item->preview_color);
            DrawCircleLines(cx, cy, half, WHITE);
            break;

        case OBJECT_RAMP_LEFT:
            // Diagonal line from top-right to bottom-left
            DrawLineEx(
                (Vector2){cx + half, cy - half},
                (Vector2){cx - half, cy + half},
                3, item->preview_color
            );
            break;

        case OBJECT_RAMP_RIGHT:
            // Diagonal line from top-left to bottom-right
            DrawLineEx(
                (Vector2){cx - half, cy - half},
                (Vector2){cx + half, cy + half},
                3, item->preview_color
            );
            break;

        case OBJECT_GATE:
            // Horizontal bar with divisions
            DrawRectangle(x + 5, cy - 5, size - 10, 10, item->preview_color);
            // Division lines
            for (int i = 1; i < 4; i++) {
                int div_x = x + 5 + (size - 10) * i / 4;
                DrawLine(div_x, cy - 8, div_x, cy + 8, WHITE);
            }
            break;

        default:
            // Unknown type - draw question mark
            DrawText("?", cx - 5, cy - 8, 16, RED);
            break;
    }
}
```

### Step 6: Implement palette input handling

```c
void editor_handle_palette_input(EditorState* editor) {
    // Keyboard shortcuts
    if (IsKeyPressed(KEY_ONE))   editor->selected_object_type = OBJECT_PEG;
    if (IsKeyPressed(KEY_TWO))   editor->selected_object_type = OBJECT_RAMP_LEFT;
    if (IsKeyPressed(KEY_THREE)) editor->selected_object_type = OBJECT_RAMP_RIGHT;
    if (IsKeyPressed(KEY_FOUR))  editor->selected_object_type = OBJECT_GATE;

    // Mouse click on palette items
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
        Vector2 mouse = GetMousePosition();
        int item_y = PALETTE_Y + 25;

        for (int i = 0; i < PALETTE_ITEM_COUNT; i++) {
            Rectangle item_rect = {
                PALETTE_X + 10, item_y,
                PALETTE_ITEM_SIZE, PALETTE_ITEM_SIZE
            };

            if (CheckCollisionPointRec(mouse, item_rect)) {
                editor->selected_object_type = palette_items[i].type;
                break;
            }

            item_y += PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING;
        }
    }
}
```

### Step 7: Add tooltip on hover

```c
void editor_render_palette_tooltip(EditorState* editor) {
    Vector2 mouse = GetMousePosition();
    int item_y = PALETTE_Y + 25;

    for (int i = 0; i < PALETTE_ITEM_COUNT; i++) {
        Rectangle item_rect = {
            PALETTE_X + 10, item_y,
            PALETTE_ITEM_SIZE, PALETTE_ITEM_SIZE
        };

        if (CheckCollisionPointRec(mouse, item_rect)) {
            // Draw tooltip to the right of palette
            int tooltip_x = PALETTE_X + PALETTE_ITEM_SIZE + 30;
            int tooltip_y = item_y;
            const char* name = palette_items[i].name;
            int text_width = MeasureText(name, 14);

            DrawRectangle(tooltip_x - 5, tooltip_y - 2,
                         text_width + 10, 20, (Color){0, 0, 0, 200});
            DrawText(name, tooltip_x, tooltip_y, 14, WHITE);
            break;
        }

        item_y += PALETTE_ITEM_SIZE + PALETTE_ITEM_SPACING;
    }
}
```

## Visual Design

```
+------------------+
|     Objects      |
+------------------+
|  +----------+    |
|  |    O     | 1  |  <- Peg
|  +----------+    |
|  +----------+    |
|  |    \     | 2  |  <- Ramp Left
|  +----------+    |
|  +----------+    |
|  |    /     | 3  |  <- Ramp Right
|  +----------+    |
|  +----------+    |
|  |  |=|=|=| | 4  |  <- Gate Row
|  +----------+    |
+------------------+
```

## Files to Modify

- `src/024-editor.h` - Add palette constants and structs
- `src/025-editor.c` - Implement palette rendering and input

## Testing

1. Enter editor mode - palette should appear on left
2. Click palette items - selection should change
3. Press 1-4 keys - selection should change
4. Hover over items - tooltip should appear
5. Verify icons are visually distinct
6. Verify selected item has distinct highlight

## Related Issues

- 1104-editor-mode.md (editor mode provides context)
- 1106-object-placement.md (uses selected object type)

## Implementation Notes (Completed)

### Adapted for Current Object Types

The original issue referenced OBJECT_RAMP_LEFT, OBJECT_RAMP_RIGHT, and OBJECT_GATE which don't exist in our schema. Based on design decisions, we have:
- OBJECT_PEG - circular collision object
- OBJECT_LINE - line with variable thickness and rounded endpoints

The palette was implemented with these two object types.

### Files Modified:

1. **`src/024-editor.h`** - Added palette constants
   - PALETTE_X, PALETTE_Y, PALETTE_ITEM_SIZE, PALETTE_ITEM_SPACING

2. **`src/025-editor.c`** - Implemented palette system
   - `PaletteItem` struct - type, name, shortcut, preview_color
   - `palette_items[]` array - PEG and LINE items
   - `editor_render_palette_icon()` - draws preview icon for each type
   - `editor_render_palette()` - renders palette panel with items
   - `editor_handle_palette_click()` - handles mouse clicks on palette items

### Visual Features:

- Palette panel on left side at (10, 100)
- 50x50 pixel item boxes with 10px spacing
- "Objects" title at top
- Selected item highlighted in blue
- Hovered item highlighted in dark gray
- Keyboard shortcut indicators (1, 2) in bottom-right of each item
- Peg icon: filled circle with white outline
- Line icon: diagonal line with ball joint endpoints
