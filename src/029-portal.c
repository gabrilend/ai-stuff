// src/029-portal.c
// Portal zone system implementation
// Handles portal registration, ball teleportation, and rendering

#include "028-portal.h"
#include "006-ball.h"
#include "022-grid.h"
#include "raylib.h"
#include <stdlib.h>
#include <stdio.h>

// =============================================================================
// Lifecycle
// =============================================================================

// {{{ portal_manager_create
PortalManager* portal_manager_create(void) {
    PortalManager* manager = (PortalManager*)calloc(1, sizeof(PortalManager));
    if (!manager) {
        fprintf(stderr, "ERROR: Failed to allocate PortalManager\n");
        return NULL;
    }
    return manager;
}
// }}}

// {{{ portal_manager_destroy
void portal_manager_destroy(PortalManager* manager) {
    if (manager) {
        free(manager);
    }
}
// }}}

// {{{ portal_manager_clear
void portal_manager_clear(PortalManager* manager) {
    if (!manager) return;

    for (int i = 0; i < MAX_PORTAL_CHANNELS; i++) {
        manager->channels[i].entry_count = 0;
        manager->channels[i].exit_count = 0;
    }
    manager->total_portals = 0;
}
// }}}

// =============================================================================
// Portal Registration
// =============================================================================

// {{{ portal_manager_add
int portal_manager_add(PortalManager* manager, int channel, PortalDirection type,
                       float x, float y, float width, float height) {
    if (!manager) return 0;

    if (channel < 0 || channel >= MAX_PORTAL_CHANNELS) {
        fprintf(stderr, "ERROR: Invalid portal channel: %d\n", channel);
        return 0;
    }

    PortalChannel* ch = &manager->channels[channel];
    Portal portal = { x, y, width, height, type, channel };

    if (type == PORTAL_ENTRY) {
        if (ch->entry_count >= MAX_PORTALS_PER_CHANNEL) {
            fprintf(stderr, "ERROR: Too many entry portals on channel %d\n", channel);
            return 0;
        }
        ch->entries[ch->entry_count++] = portal;
    } else {
        if (ch->exit_count >= MAX_PORTALS_PER_CHANNEL) {
            fprintf(stderr, "ERROR: Too many exit portals on channel %d\n", channel);
            return 0;
        }
        ch->exits[ch->exit_count++] = portal;
    }

    manager->total_portals++;
    return 1;
}
// }}}

// {{{ portal_manager_load_from_board
void portal_manager_load_from_board(PortalManager* manager, BoardData* data,
                                    Grid* grid) {
    if (!manager || !data || !grid) return;

    portal_manager_clear(manager);

    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* zone = &data->zones[i];

        if (zone->type != ZONE_PORTAL) continue;

        // Convert grid coordinates to pixel position
        // Portal center is at center of the zone area
        float x1 = grid->origin_x + zone->col * grid->cell_size;
        float y1 = grid->origin_y + zone->row * grid->cell_size;
        float width = zone->width * grid->cell_size;
        float height = zone->height * grid->cell_size;

        // Center position
        float cx = x1 + width / 2;
        float cy = y1 + height / 2;

        portal_manager_add(manager, zone->channel, zone->direction,
                          cx, cy, width, height);
    }

    printf("Loaded %d portals from board\n", manager->total_portals);
}
// }}}

// =============================================================================
// Ball Interaction
// =============================================================================

// {{{ portal_manager_check_ball
int portal_manager_check_ball(PortalManager* manager, Ball* ball,
                              float* out_x, float* out_y) {
    if (!manager || !ball || !out_x || !out_y) return 0;

    // Skip if ball is on cooldown
    if (ball->portal_cooldown > 0) {
        return 0;
    }

    // Check all entry portals
    for (int ch = 0; ch < MAX_PORTAL_CHANNELS; ch++) {
        PortalChannel* channel = &manager->channels[ch];

        for (int i = 0; i < channel->entry_count; i++) {
            Portal* entry = &channel->entries[i];

            // Check if ball center is inside entry portal bounds
            float half_w = entry->width / 2;
            float half_h = entry->height / 2;

            if (ball->x >= entry->x - half_w &&
                ball->x <= entry->x + half_w &&
                ball->y >= entry->y - half_h &&
                ball->y <= entry->y + half_h) {

                // Ball is inside entry portal - find exit
                if (channel->exit_count > 0) {
                    // Select random exit portal
                    int exit_idx = rand() % channel->exit_count;
                    Portal* exit = &channel->exits[exit_idx];

                    *out_x = exit->x;
                    *out_y = exit->y;

                    printf("Portal: ch %d, teleporting to exit %d (%.0f, %.0f)\n",
                           ch, exit_idx, *out_x, *out_y);
                    return 1;
                } else {
                    // Entry has no matching exits - warn user
                    printf("whoa hey there this channel %d doesn't have an out box! "
                           "what the heck, go fix it you goober!~\n", ch);
                }
            }
        }
    }

    return 0;
}
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ render_portal
// Renders a single portal with direction indicator
static void render_portal(Portal* portal) {
    Color color;
    Color arrow_color;

    if (portal->type == PORTAL_ENTRY) {
        // Entry portals: blue with white arrow
        color = (Color){50, 100, 255, 180};
        arrow_color = WHITE;
    } else {
        // Exit portals: orange with white arrow
        color = (Color){255, 150, 50, 180};
        arrow_color = WHITE;
    }

    float x = portal->x - portal->width / 2;
    float y = portal->y - portal->height / 2;

    // Draw portal zone
    DrawRectangle((int)x, (int)y, (int)portal->width, (int)portal->height, color);
    DrawRectangleLines((int)x, (int)y, (int)portal->width, (int)portal->height, WHITE);

    // Draw channel number
    char ch_text[8];
    snprintf(ch_text, sizeof(ch_text), "%d", portal->channel);
    int text_width = MeasureText(ch_text, 16);
    DrawText(ch_text, (int)portal->x - text_width / 2, (int)portal->y - 20, 16, WHITE);

    // Draw direction indicator (triangle)
    float cx = portal->x;
    float cy = portal->y;

    if (portal->type == PORTAL_ENTRY) {
        // Inward arrow (V shape pointing down)
        DrawTriangle(
            (Vector2){cx, cy + 10},      // Bottom point
            (Vector2){cx + 8, cy - 5},   // Top right
            (Vector2){cx - 8, cy - 5},   // Top left
            arrow_color
        );
    } else {
        // Outward arrow (^ shape pointing up)
        DrawTriangle(
            (Vector2){cx, cy - 10},      // Top point
            (Vector2){cx - 8, cy + 5},   // Bottom left
            (Vector2){cx + 8, cy + 5},   // Bottom right
            arrow_color
        );
    }
}
// }}}

// {{{ portal_manager_render
void portal_manager_render(PortalManager* manager) {
    if (!manager) return;

    for (int ch = 0; ch < MAX_PORTAL_CHANNELS; ch++) {
        PortalChannel* channel = &manager->channels[ch];

        for (int i = 0; i < channel->entry_count; i++) {
            render_portal(&channel->entries[i]);
        }
        for (int i = 0; i < channel->exit_count; i++) {
            render_portal(&channel->exits[i]);
        }
    }
}
// }}}
