// src/007-ball.c
// Ball manager implementation with double-buffering support

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "006-ball.h"

// {{{ ball_manager_create
BallManager* ball_manager_create(int capacity) {
    BallManager* manager = (BallManager*)malloc(sizeof(BallManager));
    if (!manager) {
        fprintf(stderr, "ERROR: Failed to allocate ball manager\n");
        return NULL;
    }

    manager->capacity = capacity;
    manager->active_count = 0;

    // Allocate current buffer
    manager->balls_current = (Ball*)calloc(capacity, sizeof(Ball));
    if (!manager->balls_current) {
        fprintf(stderr, "ERROR: Failed to allocate current ball buffer\n");
        free(manager);
        return NULL;
    }

    // Allocate next buffer
    manager->balls_next = (Ball*)calloc(capacity, sizeof(Ball));
    if (!manager->balls_next) {
        fprintf(stderr, "ERROR: Failed to allocate next ball buffer\n");
        free(manager->balls_current);
        free(manager);
        return NULL;
    }

    // Initialize all balls as inactive
    for (int i = 0; i < capacity; i++) {
        manager->balls_current[i].active = 0;
        manager->balls_current[i].radius = BALL_RADIUS;
        manager->balls_next[i].active = 0;
        manager->balls_next[i].radius = BALL_RADIUS;
    }

    return manager;
}
// }}}

// {{{ ball_manager_destroy
void ball_manager_destroy(BallManager* manager) {
    if (!manager) return;

    if (manager->balls_current) {
        free(manager->balls_current);
    }
    if (manager->balls_next) {
        free(manager->balls_next);
    }
    free(manager);
}
// }}}

// {{{ ball_manager_spawn
int ball_manager_spawn(BallManager* manager, float x, float y) {
    if (!manager) return 0;

    // Find an inactive slot in current buffer
    for (int i = 0; i < manager->capacity; i++) {
        if (!manager->balls_current[i].active) {
            Ball* ball = &manager->balls_current[i];
            ball->x = x;
            ball->y = y;
            ball->vx = 0.0f;
            ball->vy = 0.0f;
            ball->radius = BALL_RADIUS;
            ball->active = 1;
            manager->active_count++;
            return 1;
        }
    }

    // No available slots
    return 0;
}
// }}}

// {{{ ball_manager_swap_buffers
void ball_manager_swap_buffers(BallManager* manager) {
    if (!manager) return;

    // Swap the buffer pointers
    Ball* temp = manager->balls_current;
    manager->balls_current = manager->balls_next;
    manager->balls_next = temp;
}
// }}}

// {{{ ball_manager_deactivate
void ball_manager_deactivate(BallManager* manager, int index) {
    if (!manager) return;
    if (index < 0 || index >= manager->capacity) return;

    if (manager->balls_current[index].active) {
        manager->balls_current[index].active = 0;
        manager->active_count--;
    }
}
// }}}
