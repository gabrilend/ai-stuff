/*
 * Input and Selection System (Issue 508e)
 *
 * Handles mouse input, entity picking, and selection management.
 * Works with the slot system to select rendered entities.
 *
 * Architecture:
 *   Raylib input -> InputState -> picking functions -> SelectionState
 *   SelectionState -> RenderSlot.selected flag -> visual feedback
 */

#ifndef INPUT_H
#define INPUT_H

#include <stdbool.h>
#include "raylib.h"
#include "slots.h"

/* {{{ Configuration */
#define MAX_SELECTION 24           /* Maximum entities in selection */
#define DRAG_THRESHOLD 5           /* Pixels before drag starts */
#define PICK_RADIUS 1.0f           /* World units for click picking */
/* }}} */

/* {{{ InputState - tracks mouse and keyboard state
 * Updated each frame by input_update(). */
typedef struct input_state {
    /* Mouse position (screen coordinates) */
    int mouse_x;
    int mouse_y;

    /* Mouse position (world coordinates on ground plane) */
    float world_x;
    float world_y;
    float world_z;

    /* Ray from camera through mouse position */
    Ray mouse_ray;

    /* Button states (current frame) */
    bool left_down;
    bool right_down;
    bool middle_down;

    /* Button events (single frame) */
    bool left_pressed;
    bool right_pressed;
    bool left_released;
    bool right_released;

    /* Drag state */
    bool dragging;
    int drag_start_x;
    int drag_start_y;
    int drag_end_x;
    int drag_end_y;

    /* Keyboard modifiers */
    bool shift_held;
    bool ctrl_held;
    bool alt_held;

    /* Camera reference (for world conversion) */
    Camera3D* camera;
} InputState;
/* }}} */

/* {{{ SelectionState - tracks currently selected entities
 * Slots are marked with selected=true when in selection. */
typedef struct selection_state {
    int slots[MAX_SELECTION];      /* Array of selected slot indices */
    int count;                     /* Number of selected slots */
} SelectionState;
/* }}} */

/* {{{ Global State Access */
InputState* input_get_state(void);
SelectionState* selection_get_state(void);
/* }}} */

/* {{{ Input Functions */

/* input_init
 * Initialize input system with camera reference. */
void input_init(Camera3D* camera);

/* input_update
 * Update input state from raylib. Call once per frame. */
void input_update(void);

/* input_set_camera
 * Update camera reference (for world coordinate conversion). */
void input_set_camera(Camera3D* camera);

/* input_screen_to_world
 * Convert screen position to world position on ground plane (Y=0).
 * Returns true if intersection found. */
bool input_screen_to_world(int screen_x, int screen_y,
                           float* world_x, float* world_z);

/* input_world_to_screen
 * Convert world position to screen position.
 * Returns true if position is in front of camera. */
bool input_world_to_screen(float world_x, float world_y, float world_z,
                           int* screen_x, int* screen_y);

/* }}} */

/* {{{ Picking Functions */

/* pick_entity_at_world
 * Find entity nearest to world position within radius.
 * Returns slot index or -1 if none found. */
int pick_entity_at_world(SlotArray* slots, float wx, float wz, float radius);

/* pick_entity_at_screen
 * Find entity under screen position using ray casting.
 * Returns slot index or -1 if none found. */
int pick_entity_at_screen(SlotArray* slots, int screen_x, int screen_y);

/* pick_entities_in_rect
 * Find all entities within screen rectangle.
 * Returns count, fills out array up to max entries. */
int pick_entities_in_rect(SlotArray* slots,
                          int x1, int y1, int x2, int y2,
                          int* out, int max);

/* }}} */

/* {{{ Selection Functions */

/* selection_init
 * Initialize selection state. */
void selection_init(void);

/* selection_clear
 * Clear all selections, update render slots. */
void selection_clear(SlotArray* slots);

/* selection_add
 * Add slot to selection if not already selected and not full.
 * Updates render slot selected flag. */
void selection_add(SlotArray* slots, int slot_index);

/* selection_remove
 * Remove slot from selection.
 * Updates render slot selected flag. */
void selection_remove(SlotArray* slots, int slot_index);

/* selection_toggle
 * Toggle slot selection state. */
void selection_toggle(SlotArray* slots, int slot_index);

/* selection_contains
 * Check if slot is in selection. */
bool selection_contains(int slot_index);

/* selection_get_count
 * Return number of selected entities. */
int selection_get_count(void);

/* selection_get_slot
 * Get slot index at selection index (0 to count-1).
 * Returns -1 if index out of range. */
int selection_get_slot(int index);

/* }}} */

/* {{{ Input Processing */

/* process_selection_input
 * Handle mouse clicks and drags for selection.
 * Call after input_update(), before rendering. */
void process_selection_input(SlotArray* slots);

/* }}} */

/* {{{ Drawing */

/* draw_selection_box
 * Draw selection rectangle during drag. Call during 2D drawing phase. */
void draw_selection_box(void);

/* draw_selection_circles
 * Draw selection circles under selected entities. Call during 3D drawing. */
void draw_selection_circles(SlotArray* slots);

/* }}} */

/* {{{ Move Marker (508f) */

/* MoveMarker - visual feedback for movement target
 * Shows a pulsing circle at the target location that fades out. */
typedef struct move_marker {
    float x, z;           /* World position (Y=0 ground plane) */
    float lifetime;       /* Remaining time (0-1, starts at 1.0) */
    float max_lifetime;   /* Initial lifetime for fade calculation */
    bool active;          /* Whether marker should be drawn */
} MoveMarker;

/* move_marker_show
 * Display move marker at world position. */
void move_marker_show(float x, float z);

/* move_marker_update
 * Update marker lifetime. Call each frame with delta time. */
void move_marker_update(float dt);

/* move_marker_draw
 * Render the move marker. Call during 3D drawing phase. */
void move_marker_draw(void);

/* move_marker_is_active
 * Check if marker is currently visible. */
bool move_marker_is_active(void);

/* }}} */

/* {{{ Movement Orders (508f) */

/* process_movement_input
 * Handle right-click for movement orders.
 * Calls Lua on_move_order(x, z) when right-clicked with selection. */
void process_movement_input(SlotArray* slots, struct lua_State* L);

/* Lua bridge for move marker */
int l_show_move_marker(lua_State* L);

/* }}} */

/* {{{ Lua Bridge Functions */
#include <lua.h>

/* render.get_selection() -> {entity_id, ...} */
int l_get_selection(lua_State* L);

/* render.set_selection({entity_id, ...}) */
int l_set_selection(lua_State* L);

/* render.clear_selection() */
int l_clear_selection(lua_State* L);

/* render.get_entity_at(screen_x, screen_y) -> entity_id or nil */
int l_get_entity_at(lua_State* L);

/* render.get_mouse_world() -> x, y, z */
int l_get_mouse_world(lua_State* L);

/* render.is_selected(entity_id) -> bool */
int l_is_selected(lua_State* L);

/* }}} */

#endif /* INPUT_H */
