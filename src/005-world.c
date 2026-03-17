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
    world->score = 0;
    world->high_score = 0;

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
    // Zones are placed at the bottom of the world
    float zone_width = (float)world->width / zone_count;
    float zone_y_min = (float)world->height - zone_height;
    float zone_y_max = (float)world->height;

    // Default point values (symmetric pattern: 10, 50, 100, 500, 100, 50, 10)
    // For 7 zones: center gets 500, working outward gets lower values
    int default_points[] = {10, 50, 100, 500, 100, 50, 10};

    // Generate zones
    for (int i = 0; i < zone_count; i++) {
        world->zones[i].x_min = i * zone_width;
        world->zones[i].x_max = (i + 1) * zone_width;
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
