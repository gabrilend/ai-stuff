// src/010-upgrades.h
// Upgrade system for purchasing gameplay improvements with score
// Manages upgrade state, menu UI, and purchase logic

#ifndef UPGRADES_H
#define UPGRADES_H

// Forward declarations
typedef struct World World;

// Upgrade type identifiers
typedef enum {
    UPGRADE_SPAWN_RATE,
    UPGRADE_BALL_SIZE,
    UPGRADE_COUNT  // Number of upgrade types
} UpgradeType;

// {{{ typedef struct Upgrade
// Upgrade represents a single purchasable improvement.
// Each upgrade has multiple levels with increasing costs.
typedef struct Upgrade {
    const char* name;        // Display name
    const char* description; // Short description of effect
    int base_cost;           // Cost for level 1
    int level;               // Current level (0 = not purchased)
    int max_level;           // Maximum purchasable level
} Upgrade;
// }}}

// {{{ typedef struct UpgradeManager
// UpgradeManager holds all upgrades and menu state.
typedef struct UpgradeManager {
    Upgrade upgrades[UPGRADE_COUNT];  // Array of all upgrades
    int menu_open;                    // 1 if menu is visible
    int selected_index;               // Currently highlighted upgrade
    float purchase_hold_time;         // Time ENTER has been held (for repeat purchases)
    float purchase_cooldown;          // Time until next repeat purchase
} UpgradeManager;
// }}}

// {{{ upgrade_manager_create
// Creates and initializes an upgrade manager with default upgrades.
// Returns NULL on allocation failure.
//
// Returns:
//   UpgradeManager pointer on success, NULL on failure
UpgradeManager* upgrade_manager_create(void);
// }}}

// {{{ upgrade_manager_destroy
// Destroys an upgrade manager and frees resources.
//
// Parameters:
//   manager: UpgradeManager instance to destroy
void upgrade_manager_destroy(UpgradeManager* manager);
// }}}

// {{{ upgrade_get_cost
// Calculates the cost for the next level of an upgrade.
// Formula: base_cost * (current_level + 1)
//
// Parameters:
//   upgrade: Upgrade to calculate cost for
//
// Returns:
//   Cost for next level, or 0 if already at max level
int upgrade_get_cost(Upgrade* upgrade);
// }}}

// {{{ upgrade_manager_can_afford
// Checks if player can afford the selected upgrade.
//
// Parameters:
//   manager: UpgradeManager instance
//   score: Current player score
//
// Returns:
//   1 if affordable, 0 otherwise
int upgrade_manager_can_afford(UpgradeManager* manager, int score);
// }}}

// {{{ upgrade_manager_purchase
// Attempts to purchase the selected upgrade.
// Deducts cost from score and increments upgrade level.
//
// Parameters:
//   manager: UpgradeManager instance
//   score: Pointer to player score (will be modified)
//
// Returns:
//   1 on successful purchase, 0 if cannot afford or at max level
int upgrade_manager_purchase(UpgradeManager* manager, int* score);
// }}}

// {{{ upgrade_manager_handle_input
// Handles input for the upgrade menu.
// Tab toggles menu, Up/Down selects, Enter purchases, Escape closes.
//
// Parameters:
//   manager: UpgradeManager instance
//   score: Pointer to player score (for purchases)
void upgrade_manager_handle_input(UpgradeManager* manager, int* score);
// }}}

// {{{ upgrade_manager_render
// Renders the upgrade menu overlay if open.
// Shows all upgrades with costs, levels, and affordability.
//
// Parameters:
//   manager: UpgradeManager instance
//   score: Current player score (for affordability display)
//   screen_width: Screen width for centering
//   screen_height: Screen height for centering
void upgrade_manager_render(UpgradeManager* manager, int score,
                            int screen_width, int screen_height);
// }}}

// {{{ upgrade_get_spawn_rate_bonus
// Returns the spawn rate bonus from upgrades.
//
// Parameters:
//   manager: UpgradeManager instance
//
// Returns:
//   Additional balls per second from spawn rate upgrade
float upgrade_get_spawn_rate_bonus(UpgradeManager* manager);
// }}}

// {{{ upgrade_get_ball_radius_modifier
// Returns the ball radius modifier from upgrades.
//
// Parameters:
//   manager: UpgradeManager instance
//
// Returns:
//   Radius reduction (negative value) from ball size upgrade
float upgrade_get_ball_radius_modifier(UpgradeManager* manager);
// }}}

#endif // UPGRADES_H
