// src/011-upgrades.c
// Upgrade system implementation
// Handles upgrade state, menu rendering, and purchase logic

#include <stdio.h>
#include <stdlib.h>
#include "010-upgrades.h"
#include "raylib.h"

// Upgrade effect constants (scaled for 100x more levels)
#define SPAWN_RATE_BONUS_PER_LEVEL 0.0166f    // +0.0166 ball/sec per level (500 levels = +8.3 total)
#define BALL_RADIUS_REDUCTION_PER_LEVEL 0.01f // -0.01 radius per level (300 levels = -3 total)

// Hold-to-purchase repeat timing
#define PURCHASE_INITIAL_DELAY 0.3f   // Delay before repeat starts (seconds)
#define PURCHASE_REPEAT_RATE 30.0f    // Purchases per second when holding

// Stage upgrade costs (fixed per stage)
#define STAGE_2_COST 10000
#define STAGE_3_COST 50000
#define STAGE_4_COST 200000

// {{{ upgrade_manager_create
UpgradeManager* upgrade_manager_create(void) {
    UpgradeManager* manager = (UpgradeManager*)malloc(sizeof(UpgradeManager));
    if (!manager) {
        fprintf(stderr, "ERROR: Failed to allocate upgrade manager\n");
        return NULL;
    }

    // Initialize menu state
    manager->menu_open = 0;
    manager->selected_index = 0;
    manager->purchase_hold_time = 0.0f;
    manager->purchase_cooldown = 0.0f;

    // Initialize spawn rate upgrade (500 levels, +0.0166/level = +8.3 total)
    manager->upgrades[UPGRADE_SPAWN_RATE].name = "Spawn Rate";
    manager->upgrades[UPGRADE_SPAWN_RATE].description = "+8 ball/sec max";
    manager->upgrades[UPGRADE_SPAWN_RATE].base_cost = 1;
    manager->upgrades[UPGRADE_SPAWN_RATE].level = 0;
    manager->upgrades[UPGRADE_SPAWN_RATE].max_level = 500;

    // Initialize ball size upgrade (300 levels, -0.01/level = -3 total)
    manager->upgrades[UPGRADE_BALL_SIZE].name = "Ball Size";
    manager->upgrades[UPGRADE_BALL_SIZE].description = "-3 radius max";
    manager->upgrades[UPGRADE_BALL_SIZE].base_cost = 2;
    manager->upgrades[UPGRADE_BALL_SIZE].level = 0;
    manager->upgrades[UPGRADE_BALL_SIZE].max_level = 300;

    // Initialize stage expansion upgrade (1 level = stage 2 with ramps)
    manager->upgrades[UPGRADE_NEXT_STAGE].name = "Next Stage";
    manager->upgrades[UPGRADE_NEXT_STAGE].description = "Unlock ramp stage";
    manager->upgrades[UPGRADE_NEXT_STAGE].base_cost = STAGE_2_COST;
    manager->upgrades[UPGRADE_NEXT_STAGE].level = 0;
    manager->upgrades[UPGRADE_NEXT_STAGE].max_level = 1;  // Only stage 2 for now

    // Initialize callback to NULL
    manager->on_stage_purchase = NULL;
    manager->callback_user_data = NULL;

    return manager;
}
// }}}

// {{{ upgrade_manager_destroy
void upgrade_manager_destroy(UpgradeManager* manager) {
    if (!manager) return;
    free(manager);
}
// }}}

// {{{ upgrade_get_cost
int upgrade_get_cost(Upgrade* upgrade) {
    if (!upgrade) return 0;
    if (upgrade->level >= upgrade->max_level) return 0;

    // Cost scales with level: base_cost * (level + 1)
    return upgrade->base_cost * (upgrade->level + 1);
}
// }}}

// {{{ upgrade_get_cost_by_type
// Gets cost for upgrade by type (used for special stage cost handling)
static int upgrade_get_cost_by_type(UpgradeManager* manager, UpgradeType type) {
    if (!manager) return 0;
    Upgrade* upgrade = &manager->upgrades[type];
    if (upgrade->level >= upgrade->max_level) return 0;

    // Stage upgrades have fixed costs per level
    if (type == UPGRADE_NEXT_STAGE) {
        int stage_costs[] = { STAGE_2_COST, STAGE_3_COST, STAGE_4_COST };
        if (upgrade->level < 3) {
            return stage_costs[upgrade->level];
        }
        return 999999;  // Max stages reached
    }

    // Normal exponential scaling for other upgrades
    return upgrade->base_cost * (upgrade->level + 1);
}
// }}}

// {{{ upgrade_manager_can_afford
int upgrade_manager_can_afford(UpgradeManager* manager, int score) {
    if (!manager) return 0;
    if (manager->selected_index < 0 || manager->selected_index >= UPGRADE_COUNT) return 0;

    int cost = upgrade_get_cost_by_type(manager, (UpgradeType)manager->selected_index);
    return cost > 0 && score >= cost;
}
// }}}

// {{{ upgrade_manager_purchase
int upgrade_manager_purchase(UpgradeManager* manager, int* score) {
    if (!manager || !score) return 0;
    if (!upgrade_manager_can_afford(manager, *score)) return 0;

    UpgradeType type = (UpgradeType)manager->selected_index;
    Upgrade* upgrade = &manager->upgrades[type];
    int cost = upgrade_get_cost_by_type(manager, type);

    // Deduct cost and increment level
    *score -= cost;
    upgrade->level++;

    printf("Purchased %s level %d for %d points\n",
           upgrade->name, upgrade->level, cost);

    // Trigger stage purchase callback if this was a stage upgrade
    if (type == UPGRADE_NEXT_STAGE && manager->on_stage_purchase) {
        manager->on_stage_purchase(manager->callback_user_data);
    }

    return 1;
}
// }}}

// {{{ upgrade_manager_handle_input
int upgrade_manager_handle_input(UpgradeManager* manager, int* score) {
    if (!manager) return 0;

    float dt = GetFrameTime();

    // Tab toggles menu
    if (IsKeyPressed(KEY_TAB)) {
        manager->menu_open = !manager->menu_open;
        if (manager->menu_open) {
            printf("Upgrade menu opened\n");
        } else {
            printf("Upgrade menu closed\n");
        }
    }

    // Menu controls only work when menu is open
    if (!manager->menu_open) return 0;

    // Up/Down to select
    if (IsKeyPressed(KEY_UP) || IsKeyPressed(KEY_W)) {
        manager->selected_index--;
        if (manager->selected_index < 0) {
            manager->selected_index = UPGRADE_COUNT - 1;
        }
    }
    if (IsKeyPressed(KEY_DOWN) || IsKeyPressed(KEY_S)) {
        manager->selected_index++;
        if (manager->selected_index >= UPGRADE_COUNT) {
            manager->selected_index = 0;
        }
    }

    // Enter to purchase (hold for repeat)
    if (IsKeyDown(KEY_ENTER)) {
        if (IsKeyPressed(KEY_ENTER)) {
            // First press - purchase immediately
            upgrade_manager_purchase(manager, score);
            manager->purchase_hold_time = 0.0f;
            manager->purchase_cooldown = PURCHASE_INITIAL_DELAY;
        } else {
            // Holding - accumulate time and repeat purchase
            manager->purchase_hold_time += dt;
            manager->purchase_cooldown -= dt;
            if (manager->purchase_cooldown <= 0.0f) {
                upgrade_manager_purchase(manager, score);
                manager->purchase_cooldown = 1.0f / PURCHASE_REPEAT_RATE;
            }
        }
    } else {
        // Reset hold state when key released
        manager->purchase_hold_time = 0.0f;
        manager->purchase_cooldown = 0.0f;
    }

    // Escape to close menu (consumes the key press)
    if (IsKeyPressed(KEY_ESCAPE)) {
        manager->menu_open = 0;
        printf("Upgrade menu closed\n");
        return 1;  // ESC was consumed
    }

    return 0;  // ESC was not consumed
}
// }}}

// {{{ upgrade_manager_render
void upgrade_manager_render(UpgradeManager* manager, int score,
                            int screen_width, int screen_height) {
    if (!manager || !manager->menu_open) return;

    // Semi-transparent overlay
    DrawRectangle(0, 0, screen_width, screen_height, (Color){0, 0, 0, 180});

    // Menu box dimensions
    int menu_width = 350;
    int menu_height = 60 + UPGRADE_COUNT * 75 + 40;  // Title + upgrades + footer
    int menu_x = (screen_width - menu_width) / 2;
    int menu_y = (screen_height - menu_height) / 2;

    // Menu background
    DrawRectangle(menu_x, menu_y, menu_width, menu_height, (Color){40, 40, 50, 250});
    DrawRectangleLines(menu_x, menu_y, menu_width, menu_height, (Color){100, 100, 120, 255});

    // Title
    DrawText("UPGRADES", menu_x + menu_width / 2 - 60, menu_y + 15, 24, WHITE);

    // Current score
    char score_text[64];
    sprintf(score_text, "Score: %d", score);
    DrawText(score_text, menu_x + menu_width / 2 - 50, menu_y + 42, 16, GOLD);

    // Draw each upgrade
    int y_offset = menu_y + 70;
    for (int i = 0; i < UPGRADE_COUNT; i++) {
        Upgrade* upgrade = &manager->upgrades[i];
        UpgradeType type = (UpgradeType)i;
        int cost = upgrade_get_cost_by_type(manager, type);
        int is_selected = (i == manager->selected_index);
        int can_afford = (cost > 0 && score >= cost);
        int is_maxed = (upgrade->level >= upgrade->max_level);
        float progress = (float)upgrade->level / (float)upgrade->max_level;

        // Special background for stage upgrade
        int is_stage_upgrade = (type == UPGRADE_NEXT_STAGE);

        // Selection highlight (special color for stage upgrade)
        if (is_selected) {
            Color highlight = is_stage_upgrade ?
                (Color){60, 40, 80, 255} :  // Purple tint for stage
                (Color){60, 60, 80, 255};   // Normal gray
            DrawRectangle(menu_x + 10, y_offset - 5, menu_width - 20, 70, highlight);
        }

        // Upgrade name (gold for stage upgrade)
        Color name_color = is_stage_upgrade ?
            (is_selected ? GOLD : ORANGE) :
            (is_selected ? WHITE : LIGHTGRAY);
        DrawText(upgrade->name, menu_x + 20, y_offset, 18, name_color);

        // Progress bar or unlock status for stage upgrade
        int bar_x = menu_x + 20;
        int bar_y = y_offset + 24;
        int bar_width = menu_width - 130;
        int bar_height = 12;

        if (is_stage_upgrade && is_maxed) {
            // Stage unlocked - show special status
            DrawText("STAGE 2 UNLOCKED", bar_x, bar_y, 14, GREEN);
        } else {
            // Progress bar background
            DrawRectangle(bar_x, bar_y, bar_width, bar_height, (Color){30, 30, 40, 255});

            // Progress bar fill
            int fill_width = (int)(bar_width * progress);
            Color bar_color = is_maxed ? GREEN :
                (is_stage_upgrade ? PURPLE : (Color){100, 180, 255, 255});
            DrawRectangle(bar_x, bar_y, fill_width, bar_height, bar_color);
            DrawRectangleLines(bar_x, bar_y, bar_width, bar_height, (Color){80, 80, 100, 255});

            // Percentage text (skip for stage upgrade since it's 0% or 100%)
            if (!is_stage_upgrade) {
                char pct_text[16];
                sprintf(pct_text, "%d%%", (int)(progress * 100));
                DrawText(pct_text, bar_x + bar_width + 8, bar_y - 1, 14, LIGHTGRAY);
            }
        }

        // Description
        DrawText(upgrade->description, menu_x + 20, y_offset + 40, 12, GRAY);

        // Cost or status
        if (is_maxed) {
            const char* max_text = is_stage_upgrade ? "DONE" : "MAX";
            DrawText(max_text, menu_x + menu_width - 55, y_offset + 4, 16, GREEN);
        } else {
            char cost_text[32];
            sprintf(cost_text, "%d", cost);
            Color cost_color = can_afford ? GREEN : RED;
            DrawText(cost_text, menu_x + menu_width - 55, y_offset + 4, 16, cost_color);
        }

        y_offset += 75;
    }

    // Footer controls
    DrawText("UP/DOWN: Select  ENTER: Buy  ESC: Close",
             menu_x + 20, menu_y + menu_height - 30, 12, GRAY);
}
// }}}

// {{{ upgrade_get_spawn_rate_bonus
float upgrade_get_spawn_rate_bonus(UpgradeManager* manager) {
    if (!manager) return 0.0f;
    return manager->upgrades[UPGRADE_SPAWN_RATE].level * SPAWN_RATE_BONUS_PER_LEVEL;
}
// }}}

// {{{ upgrade_get_ball_radius_modifier
float upgrade_get_ball_radius_modifier(UpgradeManager* manager) {
    if (!manager) return 0.0f;
    // Returns negative value (radius reduction)
    return -manager->upgrades[UPGRADE_BALL_SIZE].level * BALL_RADIUS_REDUCTION_PER_LEVEL;
}
// }}}

// {{{ upgrade_manager_set_stage_callback
void upgrade_manager_set_stage_callback(UpgradeManager* manager,
                                        StagePurchaseCallback callback,
                                        void* user_data) {
    if (!manager) return;
    manager->on_stage_purchase = callback;
    manager->callback_user_data = user_data;
}
// }}}

// {{{ upgrade_get_stage_level
int upgrade_get_stage_level(UpgradeManager* manager) {
    if (!manager) return 0;
    return manager->upgrades[UPGRADE_NEXT_STAGE].level;
}
// }}}
