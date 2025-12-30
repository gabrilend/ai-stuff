# Issue 508e: Input and Selection

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** High
**Dependencies:** 508d (map integration)

---

## Current Behavior

No input handling. The renderer is display-only.

---

## Intended Behavior

- Mouse position tracked
- Click selects entity under cursor
- Visual feedback for selection (ring/highlight)
- Box selection (drag to select multiple)
- Keyboard modifiers (Shift+click to add to selection)

---

## Suggested Implementation Steps

### 1. Mouse Tracking (C)

```c
/* {{{ InputState */
typedef struct input_state {
    // Mouse position (screen coords)
    int mouse_x, mouse_y;

    // Mouse position (world coords)
    float world_x, world_y, world_z;

    // Button states
    bool left_down, right_down;
    bool left_clicked, right_clicked;  // Single frame

    // Drag state
    bool dragging;
    int drag_start_x, drag_start_y;

    // Modifiers
    bool shift_held, ctrl_held;
} InputState;

InputState g_input;
/* }}} */

/* {{{ update_input */
void update_input(void) {
    g_input.mouse_x = GetMouseX();
    g_input.mouse_y = GetMouseY();

    // Convert to world coords (simplified - assumes top-down)
    screen_to_world(g_input.mouse_x, g_input.mouse_y,
                    &g_input.world_x, &g_input.world_y, &g_input.world_z);

    // Button events
    g_input.left_clicked = IsMouseButtonPressed(MOUSE_LEFT_BUTTON);
    g_input.right_clicked = IsMouseButtonPressed(MOUSE_RIGHT_BUTTON);
    g_input.left_down = IsMouseButtonDown(MOUSE_LEFT_BUTTON);
    g_input.right_down = IsMouseButtonDown(MOUSE_RIGHT_BUTTON);

    // Drag detection
    if (g_input.left_clicked) {
        g_input.drag_start_x = g_input.mouse_x;
        g_input.drag_start_y = g_input.mouse_y;
        g_input.dragging = false;
    }
    if (g_input.left_down) {
        int dx = g_input.mouse_x - g_input.drag_start_x;
        int dy = g_input.mouse_y - g_input.drag_start_y;
        if (dx*dx + dy*dy > 25) {  // 5 pixel threshold
            g_input.dragging = true;
        }
    }

    // Modifiers
    g_input.shift_held = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
    g_input.ctrl_held = IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL);
}
/* }}} */
```

### 2. Entity Picking (C)

```c
/* {{{ pick_entity_at */
// Returns slot index of entity at world position, or -1
int pick_entity_at(float wx, float wz, float radius) {
    int best = -1;
    float best_dist = radius * radius;

    for (int i = 0; i < MAX_SLOTS; i++) {
        ComponentSlot* slot = &g_slots->slots[i];
        if (!slot->in_use || !slot->data || !slot->data->visible) continue;

        RenderSlot* r = slot->data;
        float dx = r->x - wx;
        float dz = r->z - wz;
        float dist = dx*dx + dz*dz;

        if (dist < best_dist) {
            best_dist = dist;
            best = i;
        }
    }

    return best;
}
/* }}} */

/* {{{ pick_entities_in_rect */
// Returns array of slot indices in screen rectangle
int pick_entities_in_rect(int x1, int y1, int x2, int y2, int* out, int max) {
    int count = 0;

    // Ensure x1 < x2, y1 < y2
    if (x1 > x2) { int t = x1; x1 = x2; x2 = t; }
    if (y1 > y2) { int t = y1; y1 = y2; y2 = t; }

    for (int i = 0; i < MAX_SLOTS && count < max; i++) {
        ComponentSlot* slot = &g_slots->slots[i];
        if (!slot->in_use || !slot->data || !slot->data->visible) continue;

        RenderSlot* r = slot->data;

        // Convert to screen coords
        int sx, sy;
        world_to_screen(r->x, r->y, r->z, &sx, &sy);

        if (sx >= x1 && sx <= x2 && sy >= y1 && sy <= y2) {
            out[count++] = i;
        }
    }

    return count;
}
/* }}} */
```

### 3. Selection State (C)

```c
/* {{{ SelectionState */
#define MAX_SELECTION 24

typedef struct selection_state {
    int slots[MAX_SELECTION];
    int count;
} SelectionState;

SelectionState g_selection;

void selection_clear(void);
void selection_add(int slot);
void selection_remove(int slot);
void selection_toggle(int slot);
bool selection_contains(int slot);
/* }}} */

/* {{{ selection_add */
void selection_add(int slot) {
    if (g_selection.count >= MAX_SELECTION) return;
    if (selection_contains(slot)) return;

    // Update render slot
    ComponentSlot* cs = slot_get(g_slots, slot);
    if (cs && cs->data) {
        cs->data->selected = true;
    }

    g_selection.slots[g_selection.count++] = slot;
}
/* }}} */

/* {{{ selection_clear */
void selection_clear(void) {
    for (int i = 0; i < g_selection.count; i++) {
        ComponentSlot* cs = slot_get(g_slots, g_selection.slots[i]);
        if (cs && cs->data) {
            cs->data->selected = false;
        }
    }
    g_selection.count = 0;
}
/* }}} */
```

### 4. Input Processing

```c
/* {{{ process_input */
void process_input(void) {
    update_input();

    // Left click - select
    if (g_input.left_clicked && !g_input.dragging) {
        int slot = pick_entity_at(g_input.world_x, g_input.world_z, 2.0f);

        if (!g_input.shift_held) {
            selection_clear();
        }

        if (slot >= 0) {
            if (g_input.shift_held && selection_contains(slot)) {
                selection_remove(slot);
            } else {
                selection_add(slot);
            }
        }
    }

    // Box select on drag release
    if (!g_input.left_down && g_input.dragging) {
        int slots[MAX_SELECTION];
        int count = pick_entities_in_rect(
            g_input.drag_start_x, g_input.drag_start_y,
            g_input.mouse_x, g_input.mouse_y,
            slots, MAX_SELECTION
        );

        if (!g_input.shift_held) {
            selection_clear();
        }

        for (int i = 0; i < count; i++) {
            selection_add(slots[i]);
        }

        g_input.dragging = false;
    }
}
/* }}} */
```

### 5. Selection Visualization

```c
/* {{{ draw_selection_box */
void draw_selection_box(void) {
    if (g_input.dragging) {
        int x1 = g_input.drag_start_x;
        int y1 = g_input.drag_start_y;
        int x2 = g_input.mouse_x;
        int y2 = g_input.mouse_y;

        DrawRectangleLines(
            x1 < x2 ? x1 : x2,
            y1 < y2 ? y1 : y2,
            abs(x2 - x1),
            abs(y2 - y1),
            GREEN
        );
    }
}
/* }}} */
```

### 6. Lua Bridge for Selection

```c
/* {{{ l_get_selection */
// Lua: render.get_selection() -> {entity_id, entity_id, ...}
static int l_get_selection(lua_State* L) {
    lua_newtable(L);

    for (int i = 0; i < g_selection.count; i++) {
        ComponentSlot* cs = slot_get(g_slots, g_selection.slots[i]);
        if (cs) {
            lua_pushinteger(L, cs->entity_id);
            lua_rawseti(L, -2, i + 1);
        }
    }

    return 1;
}
/* }}} */
```

---

## Files to Create/Modify

- `src/render/input.h` - Input and selection structs
- `src/render/input.c` - Implementation
- `src/render/bridge.c` - Add selection API
- `src/render/main.c` - Call input processing

---

## Acceptance Criteria

- [ ] Mouse position tracked in screen and world coords
- [ ] Click selects entity under cursor
- [ ] Shift+click adds to selection
- [ ] Drag creates selection box
- [ ] Box release selects all entities in box
- [ ] Selected entities show visual feedback
- [ ] Lua can query current selection
- [ ] Selection limited to max (24)

---

## Notes

Screen-to-world conversion depends on camera setup. For a simple top-down
view, it's just an offset and scale. For perspective, it requires ray casting.

Start simple (top-down), add perspective later.

---

## Related Documents

- `issues/508d-map-integration.md` - Map must be loaded first
- `issues/508f-movement-orders.md` - Selection used for movement
