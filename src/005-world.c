// src/005-world.c
// World state management implementation
// Handles creation, initialization, and cleanup of world state
//
// External functions: world_create, world_destroy, world_generate_pegs,
//                     world_render_pegs, world_generate_zones,
//                     world_render_zones

#include "004-world.h"
#include <raylib.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// {{{ world_create
World* world_create(int width, int height) {
    World* world = (World*)malloc(sizeof(World));
    if (!world) {
        fprintf(stderr, "ERROR: Failed to allocate world\n");
        return NULL;
    }

    world->width = width;
    world->height = height;
    world->pegs = NULL;
    world->peg_count = 0;
    world->zones = NULL;
    world->zone_count = 0;
    world->bumpers = NULL;
    world->bumper_count = 0;
    world->score = 0;
    world->high_score = 0;

    // Adversary board
    world->adversary_pegs = NULL;
    world->adversary_peg_count = 0;
    world->adversary_bumpers = NULL;
    world->adversary_bumper_count = 0;

    // Initialize table bounds to defaults (will be set properly later)
    world->table_x = 0.0f;
    world->table_width = (float)width;
    world->table_top = 0.0f;
    world->table_bottom = (float)height;
    world->adversary_table_top = (float)height;
    world->adversary_table_bottom = (float)height;

    return world;
}
// }}}

// {{{ world_destroy
void world_destroy(World* world) {
    if (!world) {
        return;
    }

    // Free peg array if allocated
    if (world->pegs) {
        free(world->pegs);
    }

    // Free zone array if allocated
    if (world->zones) {
        free(world->zones);
    }

    // Free bumper array if allocated
    if (world->bumpers) {
        free(world->bumpers);
    }

    // Free adversary arrays
    if (world->adversary_pegs) {
        free(world->adversary_pegs);
    }
    if (world->adversary_bumpers) {
        free(world->adversary_bumpers);
    }

    // Free world structure
    free(world);
}
// }}}

// {{{ world_generate_pegs
void world_generate_pegs(World* world, int rows, int cols,
                         float start_x, float start_y, float spacing) {
    if (!world) {
        return;
    }

    // Free existing pegs if any
    if (world->pegs) {
        free(world->pegs);
    }

    // Calculate total peg count
    world->peg_count = rows * cols;
    world->pegs = (Peg*)malloc(sizeof(Peg) * world->peg_count);

    if (!world->pegs) {
        fprintf(stderr, "ERROR: Failed to allocate peg array\n");
        world->peg_count = 0;
        return;
    }

    // Generate staggered grid
    int idx = 0;
    for (int row = 0; row < rows; row++) {
        // Odd rows get half-spacing offset for staggered pattern
        float offset = (row % 2 == 0) ? 0 : spacing / 2;

        for (int col = 0; col < cols; col++) {
            world->pegs[idx].x = start_x + col * spacing + offset;
            world->pegs[idx].y = start_y + row * spacing;
            world->pegs[idx].radius = PEG_RADIUS;
            idx++;
        }
    }
}
// }}}

// {{{ world_render_pegs
void world_render_pegs(World* world) {
    if (!world || !world->pegs) {
        return;
    }

    // Color palette for pegs - cohesive visual design
    Color peg_color = (Color){180, 180, 200, 255};      // Light steel
    Color peg_outline = (Color){100, 100, 120, 255};    // Darker outline

    // Render each peg as a circle with outline
    for (int i = 0; i < world->peg_count; i++) {
        // Draw filled circle
        DrawCircle((int)world->pegs[i].x, (int)world->pegs[i].y,
                   world->pegs[i].radius, peg_color);

        // Draw outline for depth
        DrawCircleLines((int)world->pegs[i].x, (int)world->pegs[i].y,
                       world->pegs[i].radius, peg_outline);
    }
}
// }}}

// {{{ world_generate_zones
void world_generate_zones(World* world, int zone_count, float zone_height) {
    if (!world || zone_count <= 0) {
        return;
    }

    // Free existing zones if any
    if (world->zones) {
        free(world->zones);
    }

    // Allocate zone array
    world->zone_count = zone_count;
    world->zones = (ScoreZone*)malloc(sizeof(ScoreZone) * zone_count);

    if (!world->zones) {
        fprintf(stderr, "ERROR: Failed to allocate zone array\n");
        world->zone_count = 0;
        return;
    }

    // Calculate zone dimensions
    // Zones span the table width (centered in window)
    float zone_width = world->table_width / zone_count;
    float zone_y_min = (float)world->height - zone_height;
    float zone_y_max = (float)world->height;

    // Default point values (symmetric pattern: 10, 50, 100, 500, 100, 50, 10)
    // For 7 zones: center gets 500, working outward gets lower values
    int default_points[] = {10, 50, 100, 500, 100, 50, 10};

    // Generate zones (positioned within table bounds)
    for (int i = 0; i < zone_count; i++) {
        world->zones[i].x_min = world->table_x + i * zone_width;
        world->zones[i].x_max = world->table_x + (i + 1) * zone_width;
        world->zones[i].y_min = zone_y_min;
        world->zones[i].y_max = zone_y_max;

        // Assign point values (use default pattern if zone_count == 7)
        if (zone_count == 7) {
            world->zones[i].points = default_points[i];
        } else {
            // For other zone counts, use simple center-based pattern
            int distance_from_center = (zone_count / 2) - i;
            if (distance_from_center < 0) distance_from_center = -distance_from_center;
            world->zones[i].points = (zone_count - distance_from_center) * 100;
        }
    }
}
// }}}

// {{{ world_render_zones
void world_render_zones(World* world) {
    if (!world || !world->zones) {
        return;
    }

    // Render each zone using its stored bounds
    for (int i = 0; i < world->zone_count; i++) {
        ScoreZone* zone = &world->zones[i];

        // Calculate zone dimensions from stored bounds
        float zone_width = zone->x_max - zone->x_min;
        float zone_height = zone->y_max - zone->y_min;

        // Choose color based on point value
        Color zone_color;
        if (zone->points >= 500) {
            zone_color = GOLD;
        } else if (zone->points >= 100) {
            zone_color = GREEN;
        } else if (zone->points >= 50) {
            zone_color = BLUE;
        } else {
            zone_color = GRAY;
        }

        // Draw zone rectangle
        DrawRectangle((int)zone->x_min, (int)zone->y_min,
                     (int)zone_width, (int)zone_height,
                     zone_color);

        // Draw zone border
        DrawRectangleLines((int)zone->x_min, (int)zone->y_min,
                          (int)zone_width, (int)zone_height,
                          DARKGRAY);

        // Draw point value text
        char text[16];
        sprintf(text, "%d", zone->points);
        int text_width = MeasureText(text, 20);
        float text_x = zone->x_min + zone_width / 2 - text_width / 2;
        float text_y = zone->y_min + zone_height / 2 - 10;
        DrawText(text, (int)text_x, (int)text_y, 20, WHITE);
    }
}
// }}}

// {{{ world_set_table_bounds
void world_set_table_bounds(World* world, float table_width,
                            float table_top, float zone_height) {
    if (!world) return;
    (void)zone_height;  // Reserved for future use (multi-row zones)

    // Store table dimensions
    world->table_width = table_width;
    world->table_top = table_top;
    world->table_bottom = (float)world->height;  // Zones go to bottom

    // Center table horizontally in window
    world->table_x = ((float)world->width - table_width) / 2.0f;
}
// }}}

// {{{ world_render_rails
void world_render_rails(World* world) {
    if (!world) return;

    // Rail visual style - darker than pegs, industrial look
    Color rail_color = (Color){80, 80, 100, 255};
    Color rail_highlight = (Color){100, 100, 120, 255};

    // Rail dimensions
    float rail_width = 10.0f;
    float rail_top = world->table_top - 20.0f;  // Start above table
    float rail_height = world->table_bottom - rail_top;

    // Left rail
    float left_x = world->table_x - rail_width;
    DrawRectangle((int)left_x, (int)rail_top,
                 (int)rail_width, (int)rail_height, rail_color);
    // Highlight on right edge (inner side)
    DrawRectangle((int)(left_x + rail_width - 2), (int)rail_top,
                 2, (int)rail_height, rail_highlight);

    // Right rail
    float right_x = world->table_x + world->table_width;
    DrawRectangle((int)right_x, (int)rail_top,
                 (int)rail_width, (int)rail_height, rail_color);
    // Highlight on left edge (inner side)
    DrawRectangle((int)right_x, (int)rail_top,
                 2, (int)rail_height, rail_highlight);
}
// }}}

// {{{ world_generate_bumpers
// Bumpers are placed at the top of each gate divider (between zones).
// For N zones, there are N-1 dividers, so N-1 bumpers.
// Each bumper is centered on the divider line at the top of the zones.
void world_generate_bumpers(World* world) {
    if (!world || world->zone_count < 2) {
        return;  // Need at least 2 zones to have dividers
    }

    // Free existing bumpers if any
    if (world->bumpers) {
        free(world->bumpers);
    }

    // Number of bumpers = number of dividers = zone_count - 1
    world->bumper_count = world->zone_count - 1;
    world->bumpers = (Bumper*)malloc(sizeof(Bumper) * world->bumper_count);

    if (!world->bumpers) {
        fprintf(stderr, "ERROR: Failed to allocate bumper array\n");
        world->bumper_count = 0;
        return;
    }

    // Bumper radius from ball.h constant
    // Note: we can't include ball.h here due to circular deps,
    // so we use a local constant that should match BUMPER_RADIUS
    float bumper_radius = 10.0f;

    // Generate bumpers at each zone divider
    // Divider is at the x_max of zone[i] (which equals x_min of zone[i+1])
    for (int i = 0; i < world->bumper_count; i++) {
        // Divider X position is at the right edge of zone[i]
        float divider_x = world->zones[i].x_max;

        // Y position is at the top of the zones (y_min)
        // Position bumper so its bottom edge aligns with zone top
        float bumper_y = world->zones[i].y_min;

        world->bumpers[i].x = divider_x;
        world->bumpers[i].y = bumper_y;
        world->bumpers[i].radius = bumper_radius;
    }
}
// }}}

// {{{ world_render_bumpers
void world_render_bumpers(World* world) {
    if (!world || !world->bumpers) {
        return;
    }

    // Bumper visual style - soft, cushion-like appearance
    // Muted teal/cyan color to contrast with gold/green/blue zones
    Color bumper_color = (Color){80, 140, 140, 255};      // Muted teal
    Color bumper_outline = (Color){60, 100, 100, 255};    // Darker outline

    // Render each bumper as a filled circle with outline
    for (int i = 0; i < world->bumper_count; i++) {
        Bumper* bumper = &world->bumpers[i];

        // Draw filled circle
        DrawCircle((int)bumper->x, (int)bumper->y,
                   bumper->radius, bumper_color);

        // Draw outline for depth
        DrawCircleLines((int)bumper->x, (int)bumper->y,
                        bumper->radius, bumper_outline);
    }
}
// }}}

// {{{ world_generate_adversary_pegs
void world_generate_adversary_pegs(World* world, int rows, int cols, float spacing) {
    if (!world) {
        return;
    }

    // Free existing adversary pegs if any
    if (world->adversary_pegs) {
        free(world->adversary_pegs);
    }

    // Calculate total peg count
    world->adversary_peg_count = rows * cols;
    world->adversary_pegs = (Peg*)malloc(sizeof(Peg) * world->adversary_peg_count);

    if (!world->adversary_pegs) {
        fprintf(stderr, "ERROR: Failed to allocate adversary peg array\n");
        world->adversary_peg_count = 0;
        return;
    }

    // Calculate adversary board bounds (below zones)
    // Adversary table starts at bottom of zones
    world->adversary_table_top = world->zones[0].y_max;
    world->adversary_table_bottom = world->adversary_table_top + (rows * spacing) + 50.0f;

    // Generate staggered grid (mirrored from player)
    // Pegs are placed from top of adversary area downward
    float peg_grid_width = cols * spacing;
    float start_x = world->table_x + (world->table_width - peg_grid_width) / 2.0f;
    float start_y = world->adversary_table_top + 50.0f;  // Margin below zones

    int idx = 0;
    for (int row = 0; row < rows; row++) {
        // Odd rows get half-spacing offset for staggered pattern
        float offset = (row % 2 == 0) ? 0 : spacing / 2;

        for (int col = 0; col < cols; col++) {
            world->adversary_pegs[idx].x = start_x + col * spacing + offset;
            world->adversary_pegs[idx].y = start_y + row * spacing;
            world->adversary_pegs[idx].radius = PEG_RADIUS;
            idx++;
        }
    }
}
// }}}

// {{{ world_render_adversary_pegs
void world_render_adversary_pegs(World* world) {
    if (!world || !world->adversary_pegs) {
        return;
    }

    // Adversary peg colors - red-tinted, dimmer than player pegs
    Color peg_color = (Color){180, 140, 140, 255};      // Reddish steel
    Color peg_outline = (Color){120, 80, 80, 255};      // Darker red outline

    // Render each peg as a circle with outline
    for (int i = 0; i < world->adversary_peg_count; i++) {
        // Draw filled circle
        DrawCircle((int)world->adversary_pegs[i].x, (int)world->adversary_pegs[i].y,
                   world->adversary_pegs[i].radius, peg_color);

        // Draw outline for depth
        DrawCircleLines((int)world->adversary_pegs[i].x, (int)world->adversary_pegs[i].y,
                       world->adversary_pegs[i].radius, peg_outline);
    }
}
// }}}

// {{{ world_generate_adversary_bumpers
void world_generate_adversary_bumpers(World* world) {
    if (!world || world->zone_count < 2) {
        return;
    }

    // Free existing adversary bumpers if any
    if (world->adversary_bumpers) {
        free(world->adversary_bumpers);
    }

    // Number of bumpers = number of dividers = zone_count - 1
    world->adversary_bumper_count = world->zone_count - 1;
    world->adversary_bumpers = (Bumper*)malloc(sizeof(Bumper) * world->adversary_bumper_count);

    if (!world->adversary_bumpers) {
        fprintf(stderr, "ERROR: Failed to allocate adversary bumper array\n");
        world->adversary_bumper_count = 0;
        return;
    }

    float bumper_radius = 10.0f;

    // Generate bumpers at bottom of each zone divider
    for (int i = 0; i < world->adversary_bumper_count; i++) {
        float divider_x = world->zones[i].x_max;
        float bumper_y = world->zones[i].y_max;  // Bottom of zones

        world->adversary_bumpers[i].x = divider_x;
        world->adversary_bumpers[i].y = bumper_y;
        world->adversary_bumpers[i].radius = bumper_radius;
    }
}
// }}}

// {{{ world_render_adversary_bumpers
void world_render_adversary_bumpers(World* world) {
    if (!world || !world->adversary_bumpers) {
        return;
    }

    // Adversary bumper colors - reddish teal
    Color bumper_color = (Color){140, 100, 100, 255};
    Color bumper_outline = (Color){100, 70, 70, 255};

    for (int i = 0; i < world->adversary_bumper_count; i++) {
        Bumper* bumper = &world->adversary_bumpers[i];

        DrawCircle((int)bumper->x, (int)bumper->y,
                   bumper->radius, bumper_color);

        DrawCircleLines((int)bumper->x, (int)bumper->y,
                        bumper->radius, bumper_outline);
    }
}
// }}}
