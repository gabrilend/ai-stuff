// src/044-rotor.c
// Rotor physics implementation (issue 901c)
// Updates rotor angles and rotates connected objects each frame

#include "044-rotor.h"
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

// {{{ rotor_physics_init
// Initializes a RotorPhysics struct to default values.
static void rotor_physics_init(RotorPhysics* rotor) {
    rotor->center_x = 0.0f;
    rotor->center_y = 0.0f;
    rotor->rotation_speed = 0.0f;
    rotor->current_angle = 0.0f;
    rotor->connected_line_indices = NULL;
    rotor->connected_line_count = 0;
    rotor->connected_peg_indices = NULL;
    rotor->connected_peg_count = 0;
    rotor->line_endpoint_data = NULL;
    rotor->peg_position_data = NULL;
}
// }}}

// {{{ rotor_physics_cleanup
// Frees resources associated with a RotorPhysics struct.
static void rotor_physics_cleanup(RotorPhysics* rotor) {
    if (rotor->connected_line_indices) {
        free(rotor->connected_line_indices);
        rotor->connected_line_indices = NULL;
    }
    if (rotor->connected_peg_indices) {
        free(rotor->connected_peg_indices);
        rotor->connected_peg_indices = NULL;
    }
    if (rotor->line_endpoint_data) {
        free(rotor->line_endpoint_data);
        rotor->line_endpoint_data = NULL;
    }
    if (rotor->peg_position_data) {
        free(rotor->peg_position_data);
        rotor->peg_position_data = NULL;
    }
    rotor->connected_line_count = 0;
    rotor->connected_peg_count = 0;
}
// }}}

// {{{ rotor_manager_create
RotorManager* rotor_manager_create(World* world) {
    RotorManager* manager = (RotorManager*)malloc(sizeof(RotorManager));
    if (!manager) return NULL;

    manager->rotors = NULL;
    manager->rotor_count = 0;
    manager->rotor_capacity = 0;
    manager->world = world;

    // Issue 901h: Initialize task data for parallel updates
    manager->task_data = NULL;
    manager->task_data_capacity = 0;

    return manager;
}
// }}}

// {{{ rotor_manager_destroy
void rotor_manager_destroy(RotorManager* manager) {
    if (!manager) return;

    rotor_manager_clear(manager);
    if (manager->rotors) {
        free(manager->rotors);
    }
    // Issue 901h: Free task data
    if (manager->task_data) {
        free(manager->task_data);
    }
    free(manager);
}
// }}}

// {{{ rotor_manager_clear
void rotor_manager_clear(RotorManager* manager) {
    if (!manager) return;

    for (int i = 0; i < manager->rotor_count; i++) {
        rotor_physics_cleanup(&manager->rotors[i]);
    }
    manager->rotor_count = 0;
}
// }}}

// {{{ cart_to_polar
// Converts cartesian offset (dx, dy) to polar (distance, angle).
static void cart_to_polar(float dx, float dy, float* out_dist, float* out_angle) {
    *out_dist = sqrtf(dx * dx + dy * dy);
    *out_angle = atan2f(dy, dx);
}
// }}}

// {{{ rotor_manager_add_from_board
// Issue 1003: Takes cell_width and cell_height for rectangular cell support
int rotor_manager_add_from_board(RotorManager* manager, BoardData* board,
                                  float origin_x, float origin_y,
                                  float cell_width, float cell_height) {
    if (!manager || !board || board->rotor_count == 0) return 0;

    // Ensure capacity
    int needed = manager->rotor_count + board->rotor_count;
    if (needed > manager->rotor_capacity) {
        int new_capacity = needed + 8;
        RotorPhysics* new_rotors = (RotorPhysics*)realloc(
            manager->rotors, sizeof(RotorPhysics) * new_capacity);
        if (!new_rotors) return 0;
        manager->rotors = new_rotors;
        manager->rotor_capacity = new_capacity;
    }

    int added = 0;

    for (int r = 0; r < board->rotor_count; r++) {
        Rotor* src = &board->rotors[r];
        RotorPhysics* dst = &manager->rotors[manager->rotor_count];
        rotor_physics_init(dst);

        // Convert grid coords to pixel coords
        // Issue 1003: Use cell_width for X, cell_height for Y
        dst->center_x = origin_x + src->col * cell_width;
        dst->center_y = origin_y + src->row * cell_height;
        dst->rotation_speed = src->rotation_speed;
        dst->current_angle = src->current_angle;

        // Count connected lines and pegs
        // Issue 902b fix: Use correct struct member names
        int line_count = 0;
        int peg_count = 0;
        for (int i = 0; i < src->connection_count; i++) {
            int idx = src->connections[i].object_index;
            if (idx < board->object_count) {
                if (board->objects[idx].type == OBJECT_LINE) line_count++;
                else if (board->objects[idx].type == OBJECT_PEG) peg_count++;
            }
        }

        // Allocate connection arrays
        if (line_count > 0) {
            dst->connected_line_indices = (int*)malloc(sizeof(int) * line_count);
            dst->line_endpoint_data = (float*)malloc(sizeof(float) * line_count * 4);
            if (!dst->connected_line_indices || !dst->line_endpoint_data) {
                rotor_physics_cleanup(dst);
                continue;
            }
        }
        if (peg_count > 0) {
            dst->connected_peg_indices = (int*)malloc(sizeof(int) * peg_count);
            dst->peg_position_data = (float*)malloc(sizeof(float) * peg_count * 2);
            if (!dst->connected_peg_indices || !dst->peg_position_data) {
                rotor_physics_cleanup(dst);
                continue;
            }
        }

        // Populate connection data
        // Track separate indices for lines in World vs BoardData
        // World lines are added in order from BoardData
        int world_line_idx = 0;
        int world_peg_idx = 0;
        int connected_line_idx = 0;
        int connected_peg_idx = 0;

        for (int i = 0; i < board->object_count; i++) {
            BoardObject* obj = &board->objects[i];

            // Check if this object is connected to current rotor
            int is_connected = 0;
            for (int c = 0; c < src->connection_count; c++) {
                if (src->connections[c].object_index == i) {
                    is_connected = 1;
                    break;
                }
            }

            if (obj->type == OBJECT_LINE) {
                if (is_connected && line_count > 0) {
                    dst->connected_line_indices[connected_line_idx] = world_line_idx;

                    // Calculate endpoint positions relative to rotor center
                    // Issue 1003: Use cell_width for X, cell_height for Y
                    float x1 = origin_x + obj->col * cell_width;
                    float y1 = origin_y + obj->row * cell_height;
                    float x2 = origin_x + obj->end_col * cell_width;
                    float y2 = origin_y + obj->end_row * cell_height;

                    float dx1 = x1 - dst->center_x;
                    float dy1 = y1 - dst->center_y;
                    float dx2 = x2 - dst->center_x;
                    float dy2 = y2 - dst->center_y;

                    int data_idx = connected_line_idx * 4;
                    cart_to_polar(dx1, dy1,
                                  &dst->line_endpoint_data[data_idx],
                                  &dst->line_endpoint_data[data_idx + 1]);
                    cart_to_polar(dx2, dy2,
                                  &dst->line_endpoint_data[data_idx + 2],
                                  &dst->line_endpoint_data[data_idx + 3]);

                    connected_line_idx++;
                }
                world_line_idx++;
            } else if (obj->type == OBJECT_PEG) {
                if (is_connected && peg_count > 0) {
                    dst->connected_peg_indices[connected_peg_idx] = world_peg_idx;

                    // Calculate peg position relative to rotor center
                    // Issue 1003: Use cell_width for X, cell_height for Y
                    float x = origin_x + obj->col * cell_width;
                    float y = origin_y + obj->row * cell_height;
                    float dx = x - dst->center_x;
                    float dy = y - dst->center_y;

                    int data_idx = connected_peg_idx * 2;
                    cart_to_polar(dx, dy,
                                  &dst->peg_position_data[data_idx],
                                  &dst->peg_position_data[data_idx + 1]);

                    connected_peg_idx++;
                }
                world_peg_idx++;
            }
        }

        dst->connected_line_count = connected_line_idx;
        dst->connected_peg_count = connected_peg_idx;

        manager->rotor_count++;
        added++;

        printf("Added rotor at (%.1f, %.1f): %d lines, %d pegs connected\n",
               dst->center_x, dst->center_y,
               dst->connected_line_count, dst->connected_peg_count);
    }

    return added;
}
// }}}

// {{{ rotor_manager_update
void rotor_manager_update(RotorManager* manager, float dt) {
    if (!manager || !manager->world) return;

    World* world = manager->world;

    for (int r = 0; r < manager->rotor_count; r++) {
        RotorPhysics* rotor = &manager->rotors[r];

        // Update angle
        rotor->current_angle += rotor->rotation_speed * dt;

        // Keep angle in reasonable range to avoid float precision issues
        while (rotor->current_angle > 6.283185f) rotor->current_angle -= 6.283185f;
        while (rotor->current_angle < 0.0f) rotor->current_angle += 6.283185f;

        // Update connected line positions
        for (int i = 0; i < rotor->connected_line_count; i++) {
            int line_idx = rotor->connected_line_indices[i];
            if (line_idx < 0 || line_idx >= world->line_count) continue;

            Line* line = &world->lines[line_idx];

            // Get original polar coordinates
            int data_idx = i * 4;
            float dist1 = rotor->line_endpoint_data[data_idx];
            float orig_angle1 = rotor->line_endpoint_data[data_idx + 1];
            float dist2 = rotor->line_endpoint_data[data_idx + 2];
            float orig_angle2 = rotor->line_endpoint_data[data_idx + 3];

            // Calculate new cartesian positions
            float new_angle1 = orig_angle1 + rotor->current_angle;
            float new_angle2 = orig_angle2 + rotor->current_angle;

            line->x1 = rotor->center_x + dist1 * cosf(new_angle1);
            line->y1 = rotor->center_y + dist1 * sinf(new_angle1);
            line->x2 = rotor->center_x + dist2 * cosf(new_angle2);
            line->y2 = rotor->center_y + dist2 * sinf(new_angle2);
        }

        // Update connected peg positions
        for (int i = 0; i < rotor->connected_peg_count; i++) {
            int peg_idx = rotor->connected_peg_indices[i];
            if (peg_idx < 0 || peg_idx >= world->peg_count) continue;

            Peg* peg = &world->pegs[peg_idx];

            // Get original polar coordinates
            int data_idx = i * 2;
            float dist = rotor->peg_position_data[data_idx];
            float orig_angle = rotor->peg_position_data[data_idx + 1];

            // Calculate new cartesian position
            float new_angle = orig_angle + rotor->current_angle;
            peg->x = rotor->center_x + dist * cosf(new_angle);
            peg->y = rotor->center_y + dist * sinf(new_angle);
        }
    }
}
// }}}

// {{{ rotor_get_line_velocity
int rotor_get_line_velocity(RotorManager* manager, int line_index,
                            float collision_x, float collision_y,
                            float* out_vx, float* out_vy) {
    if (!manager || !out_vx || !out_vy) return 0;

    *out_vx = 0.0f;
    *out_vy = 0.0f;

    // Find which rotor (if any) this line is connected to
    for (int r = 0; r < manager->rotor_count; r++) {
        RotorPhysics* rotor = &manager->rotors[r];

        for (int i = 0; i < rotor->connected_line_count; i++) {
            if (rotor->connected_line_indices[i] == line_index) {
                // Found the rotor - calculate tangential velocity at collision point
                float dx = collision_x - rotor->center_x;
                float dy = collision_y - rotor->center_y;
                float radius = sqrtf(dx * dx + dy * dy);

                // Tangential velocity = omega * radius
                // Direction is perpendicular to radius (90 degrees rotated)
                float speed = rotor->rotation_speed * radius;

                // Perpendicular direction: rotate (dx, dy) by 90 degrees
                // For CW rotation (positive speed): perpendicular is (-dy, dx)
                // Normalized direction times speed
                if (radius > 0.001f) {
                    *out_vx = -dy / radius * speed;
                    *out_vy = dx / radius * speed;
                }

                return 1;
            }
        }
    }

    return 0;
}
// }}}

// {{{ rotor_update_task
// Task function for parallel rotor updates (issue 901h)
// Updates a single rotor's angle and all connected object positions
static void rotor_update_task(void* data) {
    RotorTaskData* task = (RotorTaskData*)data;
    if (!task || !task->rotor || !task->world) return;

    RotorPhysics* rotor = task->rotor;
    World* world = task->world;
    float dt = task->dt;

    // Update angle
    rotor->current_angle += rotor->rotation_speed * dt;

    // Keep angle in reasonable range to avoid float precision issues
    while (rotor->current_angle > 6.283185f) rotor->current_angle -= 6.283185f;
    while (rotor->current_angle < 0.0f) rotor->current_angle += 6.283185f;

    // Update connected line positions
    for (int i = 0; i < rotor->connected_line_count; i++) {
        int line_idx = rotor->connected_line_indices[i];
        if (line_idx < 0 || line_idx >= world->line_count) continue;

        Line* line = &world->lines[line_idx];

        // Get original polar coordinates
        int data_idx = i * 4;
        float dist1 = rotor->line_endpoint_data[data_idx];
        float orig_angle1 = rotor->line_endpoint_data[data_idx + 1];
        float dist2 = rotor->line_endpoint_data[data_idx + 2];
        float orig_angle2 = rotor->line_endpoint_data[data_idx + 3];

        // Calculate new cartesian positions
        float new_angle1 = orig_angle1 + rotor->current_angle;
        float new_angle2 = orig_angle2 + rotor->current_angle;

        line->x1 = rotor->center_x + dist1 * cosf(new_angle1);
        line->y1 = rotor->center_y + dist1 * sinf(new_angle1);
        line->x2 = rotor->center_x + dist2 * cosf(new_angle2);
        line->y2 = rotor->center_y + dist2 * sinf(new_angle2);
    }

    // Update connected peg positions
    for (int i = 0; i < rotor->connected_peg_count; i++) {
        int peg_idx = rotor->connected_peg_indices[i];
        if (peg_idx < 0 || peg_idx >= world->peg_count) continue;

        Peg* peg = &world->pegs[peg_idx];

        // Get original polar coordinates
        int data_idx = i * 2;
        float dist = rotor->peg_position_data[data_idx];
        float orig_angle = rotor->peg_position_data[data_idx + 1];

        // Calculate new cartesian position
        float new_angle = orig_angle + rotor->current_angle;
        peg->x = rotor->center_x + dist * cosf(new_angle);
        peg->y = rotor->center_y + dist * sinf(new_angle);
    }
}
// }}}

// {{{ rotor_manager_prepare_tasks
void rotor_manager_prepare_tasks(RotorManager* manager, float dt) {
    if (!manager) return;

    // Ensure task_data array has sufficient capacity
    if (manager->rotor_count > manager->task_data_capacity) {
        RotorTaskData* new_data = (RotorTaskData*)realloc(
            manager->task_data,
            sizeof(RotorTaskData) * manager->rotor_count
        );
        if (!new_data) return;  // Allocation failed, fall back to sequential
        manager->task_data = new_data;
        manager->task_data_capacity = manager->rotor_count;
    }

    // Populate task data for each rotor
    for (int r = 0; r < manager->rotor_count; r++) {
        manager->task_data[r].rotor = &manager->rotors[r];
        manager->task_data[r].world = manager->world;
        manager->task_data[r].dt = dt;
    }
}
// }}}

// {{{ rotor_manager_submit_tasks
void rotor_manager_submit_tasks(RotorManager* manager, ThreadPool* pool) {
    if (!manager || !pool) return;

    // Submit a task for each rotor
    // Each rotor writes to disjoint sets of lines/pegs, so no conflicts
    for (int r = 0; r < manager->rotor_count; r++) {
        threadpool_submit(pool, rotor_update_task, &manager->task_data[r]);
    }
}
// }}}
