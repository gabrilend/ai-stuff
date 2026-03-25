// src/044-rotor.h
// Rotor physics system for rotating obstacles (issue 901c)
// Rotors are pivot points that rotate connected lines and pegs
//
// External functions: rotor_physics_create, rotor_physics_destroy,
//                     rotor_physics_update, rotor_physics_get_line_velocity

#ifndef ROTOR_H
#define ROTOR_H

#include "020-board-data.h"
#include "004-world.h"
#include "003-threadpool.h"

// {{{ RotorPhysics
// Runtime rotor state for physics simulation.
// Stores pixel-space positions and velocity data for collision.
typedef struct RotorPhysics {
    // Center position in pixel space
    float center_x;
    float center_y;

    // Rotation state
    float rotation_speed;  // Radians per second (positive = CW)
    float current_angle;   // Current rotation angle in radians

    // Connected object indices (from BoardData connection detection)
    // These indices map into World's lines/pegs arrays
    int* connected_line_indices;
    int connected_line_count;
    int* connected_peg_indices;
    int connected_peg_count;

    // Original positions of connected objects (relative to rotor center)
    // Used to calculate rotated positions each frame
    // For lines: pairs of (distance, angle) for each endpoint
    float* line_endpoint_data;  // [line_count * 4]: dist1, angle1, dist2, angle2
    // For pegs: (distance, angle) pairs
    float* peg_position_data;   // [peg_count * 2]: dist, angle
} RotorPhysics;
// }}}

// {{{ RotorTaskData
// Per-rotor task data for parallel updates (issue 901h)
// Each task updates a single rotor's angle and connected object positions
typedef struct RotorTaskData {
    RotorPhysics* rotor;  // Rotor to update
    World* world;         // World containing lines/pegs to move
    float dt;             // Delta time for this frame
} RotorTaskData;
// }}}

// {{{ RotorManager
// Manages all rotors in the game world.
// Provides centralized update and query interface.
typedef struct RotorManager {
    RotorPhysics* rotors;
    int rotor_count;
    int rotor_capacity;

    // Reference to world for updating line/peg positions
    World* world;

    // Parallel task data (issue 901h)
    RotorTaskData* task_data;
    int task_data_capacity;
} RotorManager;
// }}}

// {{{ rotor_manager_create
// Creates a rotor manager for the given world.
// Returns NULL on allocation failure.
RotorManager* rotor_manager_create(World* world);
// }}}

// {{{ rotor_manager_destroy
// Destroys a rotor manager and frees all resources.
void rotor_manager_destroy(RotorManager* manager);
// }}}

// {{{ rotor_manager_clear
// Removes all rotors from the manager.
void rotor_manager_clear(RotorManager* manager);
// }}}

// {{{ rotor_manager_add_from_board
// Adds rotors from BoardData to the manager.
// Converts grid coordinates to pixel positions using the provided grid.
// Detects connections and stores original positions.
// Issue 1003: Takes cell_width and cell_height for rectangular cell support.
// Returns number of rotors added.
int rotor_manager_add_from_board(RotorManager* manager, BoardData* board,
                                  float origin_x, float origin_y,
                                  float cell_width, float cell_height);
// }}}

// {{{ rotor_manager_update
// Updates all rotor angles and connected object positions.
// Call once per physics frame before ball collision checks.
// dt: Delta time in seconds
// NOTE: For sequential update. Use prepare/submit/wait pattern for parallel.
void rotor_manager_update(RotorManager* manager, float dt);
// }}}

// {{{ rotor_manager_prepare_tasks
// Prepares task data for parallel rotor updates (issue 901h).
// Sets up rotor pointers, world reference, and dt for each task.
// Call once per frame before submitting tasks to threadpool.
void rotor_manager_prepare_tasks(RotorManager* manager, float dt);
// }}}

// {{{ rotor_manager_submit_tasks
// Submits rotor update tasks to the threadpool (issue 901h).
// Each task updates a single rotor independently.
// Call after prepare_tasks, before threadpool_wait_all.
void rotor_manager_submit_tasks(RotorManager* manager, ThreadPool* pool);
// }}}

// {{{ rotor_get_line_velocity
// Gets the velocity of a line at a specific collision point.
// Used to add momentum transfer during ball-line collision.
// Returns velocity via out_vx and out_vy pointers.
// Returns 0 if line is not connected to any rotor, 1 if velocity was calculated.
int rotor_get_line_velocity(RotorManager* manager, int line_index,
                            float collision_x, float collision_y,
                            float* out_vx, float* out_vy);
// }}}

#endif // ROTOR_H
