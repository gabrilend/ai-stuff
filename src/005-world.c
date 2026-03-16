// src/005-world.c
// World state management implementation
// Handles creation, initialization, and cleanup of world state
//
// External functions: world_create, world_destroy

#include "004-world.h"
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
