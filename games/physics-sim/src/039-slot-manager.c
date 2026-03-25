// src/039-slot-manager.c
// Slot-based world layout system implementation
// Provides single source of truth for vertical positioning
// All positions calculated from slot heights, eliminating ad-hoc calculations

#include "038-slot-manager.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// =============================================================================
// Internal helpers
// =============================================================================

// {{{ find_center_gates_index
// Finds the index of the center gates slot (highest multiplier).
// Returns -1 if no gates found.
static int find_center_gates_index(SlotManager* manager) {
    int best_index = -1;
    int best_multiplier = 0;

    for (int i = 0; i < manager->slot_count; i++) {
        if (manager->slots[i].type == SLOT_TYPE_GATES) {
            if (manager->slots[i].multiplier > best_multiplier) {
                best_multiplier = manager->slots[i].multiplier;
                best_index = i;
            }
        }
    }

    return best_index;
}
// }}}

// {{{ get_height_for_type
// Returns the standard height for a slot type.
static float get_height_for_type(SlotType type) {
    switch (type) {
        case SLOT_TYPE_RETICLE:
            return SLOT_RETICLE_HEIGHT;
        case SLOT_TYPE_BOARD:
            return SLOT_BOARD_HEIGHT;
        case SLOT_TYPE_GATES:
            // Gates have margin above and below
            return SLOT_GATE_MARGIN + SLOT_GATE_HEIGHT + SLOT_GATE_MARGIN;
        default:
            return 0.0f;
    }
}
// }}}

// =============================================================================
// SlotManager functions
// =============================================================================

// {{{ slot_manager_create
SlotManager* slot_manager_create(float table_x, float table_width) {
    SlotManager* manager = (SlotManager*)calloc(1, sizeof(SlotManager));
    if (!manager) return NULL;

    manager->table_x = table_x;
    manager->table_width = table_width;
    manager->slot_count = 0;

    // Create initial layout: Reticle -> Board -> Gates -> Board -> Reticle
    // Slot 0: Player Reticle
    manager->slots[0].type = SLOT_TYPE_RETICLE;
    manager->slots[0].owner = SLOT_OWNER_PLAYER;
    manager->slots[0].height = get_height_for_type(SLOT_TYPE_RETICLE);
    manager->slots[0].multiplier = 0;
    manager->slots[0].stage_index = 0;
    manager->slots[0].content = NULL;

    // Slot 1: Player Board
    manager->slots[1].type = SLOT_TYPE_BOARD;
    manager->slots[1].owner = SLOT_OWNER_PLAYER;
    manager->slots[1].height = get_height_for_type(SLOT_TYPE_BOARD);
    manager->slots[1].multiplier = 0;
    manager->slots[1].stage_index = 0;
    manager->slots[1].content = NULL;

    // Slot 2: Gates (center, 1x multiplier)
    manager->slots[2].type = SLOT_TYPE_GATES;
    manager->slots[2].owner = SLOT_OWNER_SHARED;
    manager->slots[2].height = get_height_for_type(SLOT_TYPE_GATES);
    manager->slots[2].multiplier = 1;
    manager->slots[2].stage_index = 0;
    manager->slots[2].content = NULL;

    // Slot 3: Adversary Board
    manager->slots[3].type = SLOT_TYPE_BOARD;
    manager->slots[3].owner = SLOT_OWNER_ADVERSARY;
    manager->slots[3].height = get_height_for_type(SLOT_TYPE_BOARD);
    manager->slots[3].multiplier = 0;
    manager->slots[3].stage_index = 0;
    manager->slots[3].content = NULL;

    // Slot 4: Adversary Reticle
    manager->slots[4].type = SLOT_TYPE_RETICLE;
    manager->slots[4].owner = SLOT_OWNER_ADVERSARY;
    manager->slots[4].height = get_height_for_type(SLOT_TYPE_RETICLE);
    manager->slots[4].multiplier = 0;
    manager->slots[4].stage_index = 0;
    manager->slots[4].content = NULL;

    manager->slot_count = 5;

    // Calculate all positions
    slot_manager_recalculate(manager);

    printf("SlotManager created with %d initial slots, total_height=%.0f\n",
           manager->slot_count, manager->total_height);

    return manager;
}
// }}}

// {{{ slot_manager_destroy
void slot_manager_destroy(SlotManager* manager) {
    if (manager) {
        // Note: We don't free content pointers - they're owned elsewhere
        free(manager);
    }
}
// }}}

// {{{ slot_manager_recalculate
void slot_manager_recalculate(SlotManager* manager) {
    if (!manager) return;

    // Stack slots from top to bottom
    float y = 0.0f;

    for (int i = 0; i < manager->slot_count; i++) {
        manager->slots[i].y_start = y;
        manager->slots[i].y_end = y + manager->slots[i].height;
        y = manager->slots[i].y_end;
    }

    manager->total_height = y;

    // Update cached positions for quick access
    manager->player_reticle_y = 0.0f;
    manager->adversary_reticle_y = 0.0f;
    manager->player_board_top = 0.0f;
    manager->player_board_bottom = 0.0f;
    manager->adversary_board_top = 0.0f;
    manager->adversary_board_bottom = 0.0f;
    manager->gates_y_min = 0.0f;
    manager->gates_y_max = 0.0f;

    int found_player_board = 0;
    int found_adversary_board = 0;

    for (int i = 0; i < manager->slot_count; i++) {
        Slot* slot = &manager->slots[i];

        switch (slot->type) {
            case SLOT_TYPE_RETICLE:
                // Reticle Y is center of slot
                if (slot->owner == SLOT_OWNER_PLAYER) {
                    manager->player_reticle_y = (slot->y_start + slot->y_end) / 2.0f;
                } else {
                    manager->adversary_reticle_y = (slot->y_start + slot->y_end) / 2.0f;
                }
                break;

            case SLOT_TYPE_BOARD:
                if (slot->owner == SLOT_OWNER_PLAYER) {
                    if (!found_player_board) {
                        manager->player_board_top = slot->y_start;
                        found_player_board = 1;
                    }
                    manager->player_board_bottom = slot->y_end;
                } else {
                    if (!found_adversary_board) {
                        manager->adversary_board_top = slot->y_start;
                        found_adversary_board = 1;
                    }
                    manager->adversary_board_bottom = slot->y_end;
                }
                break;

            case SLOT_TYPE_GATES:
                // Track center gates (highest multiplier)
                if (slot->multiplier >= 1) {
                    int center_idx = find_center_gates_index(manager);
                    if (i == center_idx) {
                        // Gates actual zone is inside the margins
                        manager->gates_y_min = slot->y_start + SLOT_GATE_MARGIN;
                        manager->gates_y_max = slot->y_end - SLOT_GATE_MARGIN;
                    }
                }
                break;

            default:
                break;
        }
    }
}
// }}}

// {{{ slot_manager_expand
// Expands the world by inserting new boards and gates symmetrically.
// After expansion, layout becomes:
//   Player Reticle
//   Player Board 0 (original)
//   Gates (1x) NEW
//   Player Board 1 (new)
//   Gates (2x) (original center, upgraded)
//   Adversary Board 1 (new)
//   Gates (1x) NEW
//   Adversary Board 0 (original)
//   Adversary Reticle
int slot_manager_expand(SlotManager* manager, int multiplier) {
    if (!manager) return 0;

    // Need to add 4 new slots: player gates, player board, adversary board, adversary gates
    if (manager->slot_count + 4 > MAX_SLOTS) {
        fprintf(stderr, "SlotManager: Cannot expand, too many slots\n");
        return 0;
    }

    // Find the center gates
    int center_idx = find_center_gates_index(manager);
    if (center_idx < 0) {
        fprintf(stderr, "SlotManager: Cannot expand, no center gates found\n");
        return 0;
    }

    // New stage index = current multiplier (1 -> stage 1, 2 -> stage 2, etc.)
    int new_stage = manager->slots[center_idx].multiplier;

    // Update center gates to new multiplier
    manager->slots[center_idx].multiplier = multiplier;

    // Step 1: Insert 2 slots BEFORE center: [gates 1x, player board new]
    // Shift center and everything after by 2 positions
    for (int i = manager->slot_count - 1; i >= center_idx; i--) {
        manager->slots[i + 2] = manager->slots[i];
    }
    manager->slot_count += 2;

    // Insert player gates (1x) at old center position
    manager->slots[center_idx].type = SLOT_TYPE_GATES;
    manager->slots[center_idx].owner = SLOT_OWNER_SHARED;
    manager->slots[center_idx].height = get_height_for_type(SLOT_TYPE_GATES);
    manager->slots[center_idx].multiplier = 1;
    manager->slots[center_idx].stage_index = new_stage;
    manager->slots[center_idx].content = NULL;

    // Insert new player board after the new gates
    manager->slots[center_idx + 1].type = SLOT_TYPE_BOARD;
    manager->slots[center_idx + 1].owner = SLOT_OWNER_PLAYER;
    manager->slots[center_idx + 1].height = get_height_for_type(SLOT_TYPE_BOARD);
    manager->slots[center_idx + 1].multiplier = 0;
    manager->slots[center_idx + 1].stage_index = new_stage;
    manager->slots[center_idx + 1].content = NULL;

    // Center gates are now at center_idx + 2
    int new_center_idx = center_idx + 2;

    // Step 2: Insert 2 slots AFTER center: [adversary board new, gates 1x]
    // Shift everything after center by 2 positions
    for (int i = manager->slot_count - 1; i > new_center_idx; i--) {
        manager->slots[i + 2] = manager->slots[i];
    }
    manager->slot_count += 2;

    // Insert new adversary board right after center
    manager->slots[new_center_idx + 1].type = SLOT_TYPE_BOARD;
    manager->slots[new_center_idx + 1].owner = SLOT_OWNER_ADVERSARY;
    manager->slots[new_center_idx + 1].height = get_height_for_type(SLOT_TYPE_BOARD);
    manager->slots[new_center_idx + 1].multiplier = 0;
    manager->slots[new_center_idx + 1].stage_index = new_stage;
    manager->slots[new_center_idx + 1].content = NULL;

    // Insert adversary gates (1x) after the new board
    manager->slots[new_center_idx + 2].type = SLOT_TYPE_GATES;
    manager->slots[new_center_idx + 2].owner = SLOT_OWNER_SHARED;
    manager->slots[new_center_idx + 2].height = get_height_for_type(SLOT_TYPE_GATES);
    manager->slots[new_center_idx + 2].multiplier = 1;
    manager->slots[new_center_idx + 2].stage_index = new_stage;
    manager->slots[new_center_idx + 2].content = NULL;

    // Recalculate positions
    slot_manager_recalculate(manager);

    printf("SlotManager expanded to %d slots, multiplier=%d, total_height=%.0f\n",
           manager->slot_count, multiplier, manager->total_height);

    return 1;
}
// }}}

// {{{ slot_manager_get_player_spawn_y
float slot_manager_get_player_spawn_y(SlotManager* manager) {
    return manager ? manager->player_reticle_y : 50.0f;
}
// }}}

// {{{ slot_manager_get_adversary_spawn_y
float slot_manager_get_adversary_spawn_y(SlotManager* manager) {
    return manager ? manager->adversary_reticle_y : 0.0f;
}
// }}}

// {{{ slot_manager_get_board_bounds
int slot_manager_get_board_bounds(SlotManager* manager, SlotOwner owner,
                                  int stage_index, float* y_top, float* y_bottom) {
    if (!manager) return 0;

    for (int i = 0; i < manager->slot_count; i++) {
        Slot* slot = &manager->slots[i];
        if (slot->type == SLOT_TYPE_BOARD &&
            slot->owner == owner &&
            slot->stage_index == stage_index) {
            if (y_top) *y_top = slot->y_start;
            if (y_bottom) *y_bottom = slot->y_end;
            return 1;
        }
    }

    return 0;
}
// }}}

// {{{ slot_manager_get_gates_bounds
void slot_manager_get_gates_bounds(SlotManager* manager, float* y_min, float* y_max) {
    if (!manager) return;

    if (y_min) *y_min = manager->gates_y_min;
    if (y_max) *y_max = manager->gates_y_max;
}
// }}}

// {{{ slot_manager_update_table_x
void slot_manager_update_table_x(SlotManager* manager, float new_table_x) {
    if (manager) {
        manager->table_x = new_table_x;
    }
}
// }}}

// {{{ slot_manager_print_debug
void slot_manager_print_debug(SlotManager* manager) {
    if (!manager) {
        printf("SlotManager: NULL\n");
        return;
    }

    printf("=== SlotManager Debug ===\n");
    printf("Table: x=%.0f, width=%.0f\n", manager->table_x, manager->table_width);
    printf("Total height: %.0f\n", manager->total_height);
    printf("Player reticle Y: %.0f\n", manager->player_reticle_y);
    printf("Player board: top=%.0f, bottom=%.0f\n",
           manager->player_board_top, manager->player_board_bottom);
    printf("Gates: y_min=%.0f, y_max=%.0f\n",
           manager->gates_y_min, manager->gates_y_max);
    printf("Adversary board: top=%.0f, bottom=%.0f\n",
           manager->adversary_board_top, manager->adversary_board_bottom);
    printf("Adversary reticle Y: %.0f\n", manager->adversary_reticle_y);
    printf("\nSlots (%d):\n", manager->slot_count);

    const char* type_names[] = {"RETICLE", "BOARD", "GATES"};
    const char* owner_names[] = {"PLAYER", "ADVERSARY", "SHARED"};

    for (int i = 0; i < manager->slot_count; i++) {
        Slot* slot = &manager->slots[i];
        printf("  [%d] %s (%s) y=[%.0f, %.0f] h=%.0f",
               i,
               type_names[slot->type],
               owner_names[slot->owner],
               slot->y_start, slot->y_end, slot->height);
        if (slot->type == SLOT_TYPE_GATES) {
            printf(" mult=%dx", slot->multiplier);
        }
        if (slot->type == SLOT_TYPE_BOARD) {
            printf(" stage=%d", slot->stage_index);
        }
        printf("\n");
    }
    printf("=========================\n");
}
// }}}
