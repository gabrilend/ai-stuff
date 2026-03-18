// src/037-wrap-zones.c
// Dynamic wrap zones implementation
// Positions wrap zones at edges of maximum viewable area
// Updates automatically when world bounds or screen size change
//
// Viewable area calculation (from camera scroll limits):
//   Top edge: table_top - screen_height (camera scrolled to top)
//   Bottom edge: adversary_table_bottom + screen_height (camera scrolled to bottom)
//
// Wrap zone positions:
//   Top zone: just above viewable top (receives adversary balls going up)
//   Bottom zone: just below viewable bottom (receives player balls going down)

#include "036-wrap-zones.h"
#include <raylib.h>
#include <stdlib.h>
#include <stdio.h>

// Default zone height (buffer area outside viewable region)
#define DEFAULT_ZONE_HEIGHT 100.0f

// {{{ wrap_zones_create
WrapZones* wrap_zones_create(World* world, float screen_height) {
    if (!world) return NULL;

    WrapZones* zones = (WrapZones*)malloc(sizeof(WrapZones));
    if (!zones) return NULL;

    zones->world = world;
    zones->zone_height = DEFAULT_ZONE_HEIGHT;
    zones->debug_visible = 1;  // Start with debug ON for testing

    // Initial position calculation
    wrap_zones_update(zones, screen_height);

    printf("Wrap zones created: top_y=%.0f, bottom_y=%.0f, height=%.0f\n",
           zones->top_zone_y, zones->bottom_zone_y, zones->zone_height);

    return zones;
}
// }}}

// {{{ wrap_zones_destroy
void wrap_zones_destroy(WrapZones* zones) {
    if (zones) {
        free(zones);
    }
}
// }}}

// {{{ wrap_zones_update
void wrap_zones_update(WrapZones* zones, float screen_height) {
    if (!zones || !zones->world) return;

    World* world = zones->world;
    zones->screen_height = screen_height;

    // Calculate viewable area bounds (same as camera scroll limits)
    // When camera is scrolled to top: shows [table_top - screen_height, table_top]
    // When camera is scrolled to bottom: shows [adversary_table_bottom, adversary_table_bottom + screen_height]
    float viewable_top = world->table_top - screen_height;
    float viewable_bottom = world->adversary_table_bottom + screen_height;

    // Position zones just outside viewable area
    // Top zone: its bottom edge touches viewable_top
    zones->top_zone_y = viewable_top - zones->zone_height;
    // Bottom zone: its top edge touches viewable_bottom
    zones->bottom_zone_y = viewable_bottom;

    // Zone width spans table area
    zones->zone_x = world->table_x;
    zones->zone_width = world->table_width;

    printf("Wrap zones updated: viewable=[%.0f, %.0f], top_zone=%.0f, bottom_zone=%.0f\n",
           viewable_top, viewable_bottom, zones->top_zone_y, zones->bottom_zone_y);
}
// }}}

// {{{ wrap_zones_check_ball
int wrap_zones_check_ball(WrapZones* zones, Ball* ball) {
    if (!zones || !ball || !ball->active) return 0;

    // Check if ball is within table X bounds
    // Balls outside table width shouldn't wrap (they're in the rail area)
    if (ball->x < zones->zone_x ||
        ball->x > zones->zone_x + zones->zone_width) {
        return 0;
    }

    if (ball->owner == OWNER_PLAYER) {
        // Player ball falling down - check if fully inside bottom zone
        // Ball is in zone when its top edge (y - radius) is past zone top
        if (ball->y - ball->radius > zones->bottom_zone_y) {
            // Calculate offset into bottom zone (how far ball has traveled into it)
            float offset_in_zone = ball->y - zones->bottom_zone_y;
            // Mirror position: spawn at same offset into top zone
            // Ball entering bottom zone at top appears at top of top zone
            ball->y = zones->top_zone_y + offset_in_zone;
            // Reset gate tracking so ball can score again after wrap
            ball->passed_gate = 0;
            return 1;
        }
    } else if (ball->owner == OWNER_ADVERSARY) {
        // Adversary ball floating up - check if fully inside top zone
        // Ball is in zone when its bottom edge (y + radius) is above zone bottom
        float top_zone_bottom = zones->top_zone_y + zones->zone_height;
        if (ball->y + ball->radius < top_zone_bottom) {
            // Calculate offset from bottom of top zone (how far ball has traveled into it)
            float offset_from_bottom = top_zone_bottom - ball->y;
            // Mirror position: spawn at same offset from top of bottom zone
            // Ball entering top zone at bottom appears at bottom of bottom zone
            ball->y = zones->bottom_zone_y + zones->zone_height - offset_from_bottom;
            // Reset gate tracking so ball can score again after wrap
            ball->passed_gate = 0;
            return 1;
        }
    }

    return 0;
}
// }}}

// {{{ wrap_zones_render_debug
void wrap_zones_render_debug(WrapZones* zones) {
    if (!zones || !zones->debug_visible) return;

    // Top zone - blue with transparency
    DrawRectangle(
        (int)zones->zone_x,
        (int)zones->top_zone_y,
        (int)zones->zone_width,
        (int)zones->zone_height,
        (Color){50, 100, 255, 80}
    );
    // Top zone border
    DrawRectangleLines(
        (int)zones->zone_x,
        (int)zones->top_zone_y,
        (int)zones->zone_width,
        (int)zones->zone_height,
        (Color){50, 100, 255, 200}
    );

    // Bottom zone - red with transparency
    DrawRectangle(
        (int)zones->zone_x,
        (int)zones->bottom_zone_y,
        (int)zones->zone_width,
        (int)zones->zone_height,
        (Color){255, 100, 50, 80}
    );
    // Bottom zone border
    DrawRectangleLines(
        (int)zones->zone_x,
        (int)zones->bottom_zone_y,
        (int)zones->zone_width,
        (int)zones->zone_height,
        (Color){255, 100, 50, 200}
    );

    // Labels
    DrawText("TOP WRAP ZONE",
             (int)(zones->zone_x + zones->zone_width / 2 - 60),
             (int)(zones->top_zone_y + zones->zone_height / 2 - 10),
             20, (Color){50, 100, 255, 200});
    DrawText("BOTTOM WRAP ZONE",
             (int)(zones->zone_x + zones->zone_width / 2 - 80),
             (int)(zones->bottom_zone_y + zones->zone_height / 2 - 10),
             20, (Color){255, 100, 50, 200});
}
// }}}

// {{{ wrap_zones_toggle_debug
void wrap_zones_toggle_debug(WrapZones* zones) {
    if (zones) {
        zones->debug_visible = !zones->debug_visible;
        printf("Wrap zones debug: %s\n", zones->debug_visible ? "ON" : "OFF");
    }
}
// }}}
