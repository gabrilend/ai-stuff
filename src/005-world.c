// src/005-world.c
// World state management implementation
// Handles creation, initialization, and cleanup of world state
//
// External functions: world_create, world_destroy, world_generate_pegs,
//                     world_render_pegs

#include "004-world.h"
#include <raylib.h>
#include <stdlib.h>
#include <stdio.h>

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

    // Render each peg as a circle
    for (int i = 0; i < world->peg_count; i++) {
        DrawCircle((int)world->pegs[i].x, (int)world->pegs[i].y,
                   world->pegs[i].radius, LIGHTGRAY);
    }
}
// }}}
