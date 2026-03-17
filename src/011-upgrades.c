// src/011-upgrades.c
// Upgrade system implementation
// Handles upgrade state, menu rendering, and purchase logic

#include <stdio.h>
#include <stdlib.h>
#include "010-upgrades.h"
#include "raylib.h"

// Upgrade effect constants
#define SPAWN_RATE_BONUS_PER_LEVEL 1.0f   // +1 ball/sec per level
#define BALL_RADIUS_REDUCTION_PER_LEVEL 1.0f  // -1 radius per level

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

    // Initialize spawn rate upgrade
    manager->upgrades[UPGRADE_SPAWN_RATE].name = "Spawn Rate";
    manager->upgrades[UPGRADE_SPAWN_RATE].description = "+1 ball/sec";
    manager->upgrades[UPGRADE_SPAWN_RATE].base_cost = 100;
    manager->upgrades[UPGRADE_SPAWN_RATE].level = 0;
    manager->upgrades[UPGRADE_SPAWN_RATE].max_level = 5;

    // Initialize ball size upgrade
    manager->upgrades[UPGRADE_BALL_SIZE].name = "Ball Size";
    manager->upgrades[UPGRADE_BALL_SIZE].description = "-1 radius";
    manager->upgrades[UPGRADE_BALL_SIZE].base_cost = 150;
    manager->upgrades[UPGRADE_BALL_SIZE].level = 0;
    manager->upgrades[UPGRADE_BALL_SIZE].max_level = 3;

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

// {{{ upgrade_manager_can_afford
int upgrade_manager_can_afford(UpgradeManager* manager, int score) {
    if (!manager) return 0;
    if (manager->selected_index < 0 || manager->selected_index >= UPGRADE_COUNT) return 0;

    Upgrade* upgrade = &manager->upgrades[manager->selected_index];
    int cost = upgrade_get_cost(upgrade);

    return cost > 0 && score >= cost;
}
// }}}

// {{{ upgrade_manager_purchase
int upgrade_manager_purchase(UpgradeManager* manager, int* score) {
    if (!manager || !score) return 0;
    if (!upgrade_manager_can_afford(manager, *score)) return 0;

    Upgrade* upgrade = &manager->upgrades[manager->selected_index];
    int cost = upgrade_get_cost(upgrade);

    // Deduct cost and increment level
    *score -= cost;
    upgrade->level++;

    printf("Purchased %s level %d for %d points\n",
           upgrade->name, upgrade->level, cost);

    return 1;
}
// }}}

// {{{ upgrade_manager_handle_input
void upgrade_manager_handle_input(UpgradeManager* manager, int* score) {
    if (!manager) return;

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
    if (!manager->menu_open) return;

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

    // Enter to purchase
    if (IsKeyPressed(KEY_ENTER)) {
        upgrade_manager_purchase(manager, score);
    }

    // Escape to close
    if (IsKeyPressed(KEY_ESCAPE)) {
        manager->menu_open = 0;
        printf("Upgrade menu closed\n");
    }
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
    int menu_height = 50 + UPGRADE_COUNT * 70 + 60;  // Title + upgrades + footer
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
        int cost = upgrade_get_cost(upgrade);
        int is_selected = (i == manager->selected_index);
        int can_afford = (cost > 0 && score >= cost);
        int is_maxed = (upgrade->level >= upgrade->max_level);

        // Selection highlight
        if (is_selected) {
            DrawRectangle(menu_x + 10, y_offset - 5, menu_width - 20, 60,
                         (Color){60, 60, 80, 255});
        }

        // Upgrade name and level
        char name_text[64];
        sprintf(name_text, "%s [%d/%d]", upgrade->name, upgrade->level, upgrade->max_level);
        Color name_color = is_selected ? WHITE : LIGHTGRAY;
        DrawText(name_text, menu_x + 20, y_offset, 18, name_color);

        // Description
        DrawText(upgrade->description, menu_x + 20, y_offset + 22, 14, GRAY);

        // Cost or status
        if (is_maxed) {
            DrawText("MAX", menu_x + menu_width - 70, y_offset + 10, 18, GREEN);
        } else {
            char cost_text[32];
            sprintf(cost_text, "%d pts", cost);
            Color cost_color = can_afford ? GREEN : RED;
            DrawText(cost_text, menu_x + menu_width - 90, y_offset + 10, 16, cost_color);
        }

        y_offset += 70;
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
