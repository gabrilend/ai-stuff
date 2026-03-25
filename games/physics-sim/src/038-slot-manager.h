// src/038-slot-manager.h
// Slot-based world layout system
// Provides single source of truth for vertical positioning of boards, gates, and reticles
// Replaces ad-hoc position calculations with predictable slot-based layout
//
// Layout structure (top to bottom):
//   Player Reticle -> Player Boards -> Gates -> Adversary Boards -> Adversary Reticle
//
// When stages expand, new boards and gates are inserted symmetrically from center

#ifndef SLOT_MANAGER_H
#define SLOT_MANAGER_H

// =============================================================================
// Constants
// =============================================================================

// Standard slot heights (pixels)
// Reticle height provides clearance for ball trajectory before hitting pegs
// Current layout: spawn at y~75, pegs at y=150, so 150px reticle gives good clearance
#define SLOT_RETICLE_HEIGHT 150.0f
#define SLOT_BOARD_HEIGHT 946.0f    // 22 rows x 43px cell size (denser grid)
#define SLOT_GATE_HEIGHT 40.0f      // Gate zone height
#define SLOT_GATE_MARGIN 50.0f      // Margin above and below gates

// Maximum slots (reticle + boards + gates on each side)
#define MAX_SLOTS 32

// =============================================================================
// Types
// =============================================================================

// {{{ SlotType enum
// Defines the type of content in a slot
typedef enum SlotType {
    SLOT_TYPE_RETICLE,   // Spawn area with visual reticle
    SLOT_TYPE_BOARD,     // Peg/obstacle grid
    SLOT_TYPE_GATES,     // Score zones with bumpers
    SLOT_TYPE_COUNT
} SlotType;
// }}}

// {{{ SlotOwner enum
// Defines who owns the slot (for boards and reticles)
typedef enum SlotOwner {
    SLOT_OWNER_PLAYER,     // Player-controlled
    SLOT_OWNER_ADVERSARY,  // AI-controlled
    SLOT_OWNER_SHARED      // Shared (gates)
} SlotOwner;
// }}}

// {{{ typedef struct Slot
// Slot represents a vertical section of the world layout.
// Slots are stacked vertically and positions are calculated automatically.
typedef struct Slot {
    SlotType type;         // What type of content
    SlotOwner owner;       // Who owns this slot
    float y_start;         // Top edge (calculated)
    float y_end;           // Bottom edge (calculated)
    float height;          // Height of this slot (fixed per type)
    int multiplier;        // For gates: point multiplier (1x, 2x, etc.)
    int stage_index;       // For boards: which stage (0 = original, 1+ = expansions)
    void* content;         // Pointer to Stage, GateRow, or NULL
} Slot;
// }}}

// {{{ typedef struct SlotManager
// SlotManager tracks all slots and provides positioning information.
// Single source of truth for world layout.
typedef struct SlotManager {
    Slot slots[MAX_SLOTS]; // Fixed array of slots
    int slot_count;        // Number of active slots

    // Cached positions for quick access
    float player_reticle_y;        // Y position for player spawn
    float adversary_reticle_y;     // Y position for adversary spawn
    float player_board_top;        // Top of player's first board
    float player_board_bottom;     // Bottom of player's last board
    float adversary_board_top;     // Top of adversary's first board
    float adversary_board_bottom;  // Bottom of adversary's last board
    float gates_y_min;             // Top of center gates
    float gates_y_max;             // Bottom of center gates
    float total_height;            // Total world height

    // Table dimensions (horizontal, constant)
    float table_x;         // Left edge of table
    float table_width;     // Width of table
} SlotManager;
// }}}

// =============================================================================
// SlotManager functions
// =============================================================================

// {{{ slot_manager_create
// Creates a new slot manager with the initial layout:
//   Player Reticle -> Player Board -> Gates -> Adversary Board -> Adversary Reticle
// Returns NULL on failure.
//
// Parameters:
//   table_x: Left edge of table (for horizontal centering)
//   table_width: Width of playable area
SlotManager* slot_manager_create(float table_x, float table_width);
// }}}

// {{{ slot_manager_destroy
// Destroys a slot manager and frees resources.
// Does NOT free content pointers (those are owned elsewhere).
void slot_manager_destroy(SlotManager* manager);
// }}}

// {{{ slot_manager_recalculate
// Recalculates all slot positions based on their heights.
// Call after adding or removing slots.
// Updates cached positions (reticle_y, board_top, etc.)
void slot_manager_recalculate(SlotManager* manager);
// }}}

// {{{ slot_manager_expand
// Expands the world by adding new boards and gates for both players.
// Inserts slots symmetrically around the center gates.
//
// After expansion with multiplier N:
//   Player Reticle
//   Player Board 1 (original)
//   Gates (1x)
//   Player Board N (new)
//   Gates (Nx) <- center, highest multiplier
//   Adversary Board N (new)
//   Gates (1x)
//   Adversary Board 1 (original)
//   Adversary Reticle
//
// Parameters:
//   manager: SlotManager to expand
//   multiplier: Point multiplier for center gates (2, 3, 4, etc.)
//
// Returns: 1 on success, 0 on failure (too many slots)
int slot_manager_expand(SlotManager* manager, int multiplier);
// }}}

// {{{ slot_manager_get_player_spawn_y
// Returns the Y coordinate for player ball spawning.
// This is the center of the player reticle slot.
float slot_manager_get_player_spawn_y(SlotManager* manager);
// }}}

// {{{ slot_manager_get_adversary_spawn_y
// Returns the Y coordinate for adversary ball spawning.
// This is the center of the adversary reticle slot.
float slot_manager_get_adversary_spawn_y(SlotManager* manager);
// }}}

// {{{ slot_manager_get_board_bounds
// Gets the vertical bounds for a specific board slot.
//
// Parameters:
//   manager: SlotManager
//   owner: SLOT_OWNER_PLAYER or SLOT_OWNER_ADVERSARY
//   stage_index: Which stage (0 = original)
//   y_top: Output - top of board
//   y_bottom: Output - bottom of board
//
// Returns: 1 if found, 0 if not found
int slot_manager_get_board_bounds(SlotManager* manager, SlotOwner owner,
                                  int stage_index, float* y_top, float* y_bottom);
// }}}

// {{{ slot_manager_get_gates_bounds
// Gets the vertical bounds for the center gates (highest multiplier).
//
// Parameters:
//   manager: SlotManager
//   y_min: Output - top of gates
//   y_max: Output - bottom of gates
void slot_manager_get_gates_bounds(SlotManager* manager, float* y_min, float* y_max);
// }}}

// {{{ slot_manager_update_table_x
// Updates the table_x value (called on window resize).
// This shifts the horizontal position but does not affect vertical layout.
void slot_manager_update_table_x(SlotManager* manager, float new_table_x);
// }}}

// {{{ slot_manager_print_debug
// Prints all slot positions to stdout for debugging.
void slot_manager_print_debug(SlotManager* manager);
// }}}

#endif // SLOT_MANAGER_H
