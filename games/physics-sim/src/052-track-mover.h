// src/052-track-mover.h
// Track mover physics system for platforms moving along tracks (issues 902c, 902d)
// Movers follow predefined track paths, carrying attached objects (payload)
//
// External functions: track_mover_manager_create, track_mover_manager_destroy,
//                     track_mover_manager_update, track_mover_get_world_position

#ifndef TRACK_MOVER_H
#define TRACK_MOVER_H

#include "020-board-data.h"
#include "004-world.h"
#include "022-grid.h"
#include "003-threadpool.h"

// {{{ MoverPayload
// Payload item attached to a mover.
// Stores relative offset from mover position (no rotation unlike rotors).
// For lines, also stores half dimensions to reconstruct endpoints.
typedef struct MoverPayload {
    int object_index;       // Index into board objects array
    ObjectType object_type; // Type of object (PEG or LINE)
    float offset_x;         // X offset from mover position in pixels
    float offset_y;         // Y offset from mover position in pixels
    // Line-specific: half dimensions from midpoint to endpoints
    float line_half_dx;     // (end_x - start_x) / 2
    float line_half_dy;     // (end_y - start_y) / 2
} MoverPayload;
// }}}

// {{{ MoverPhysics
// Runtime mover state for physics simulation.
// Tracks position along current segment and attached payload.
typedef struct MoverPhysics {
    // Track position
    int current_segment;        // Index of segment mover is on
    float position_on_segment;  // 0.0 (start) to 1.0 (end) along segment
    int direction;              // +1 (toward end) or -1 (toward start)
    float speed;                // Pixels per second

    // World position (computed each frame)
    float world_x;
    float world_y;

    // Payload (objects moving with this mover)
    MoverPayload* payload;
    int payload_count;
    int payload_capacity;

    // Connected line and peg indices (mapped to World arrays)
    int* connected_line_indices;
    int connected_line_count;
    int* connected_peg_indices;
    int connected_peg_count;
} MoverPhysics;
// }}}

// Forward declaration for task data
struct TrackMoverManager;

// {{{ MoverTaskData
// Per-mover task data for parallel updates (issue 902h)
// Each task updates a single mover's position and payload
typedef struct MoverTaskData {
    MoverPhysics* mover;              // Mover to update
    struct TrackMoverManager* manager; // Manager for segment/world access
    float dt;                          // Delta time for this frame
} MoverTaskData;
// }}}

// {{{ TrackMoverManager
// Manages all track movers in the game world.
// Provides centralized update and query interface.
typedef struct TrackMoverManager {
    MoverPhysics* movers;
    int mover_count;
    int mover_capacity;

    // Reference to world for updating line/peg positions
    World* world;

    // Track segment data for path following
    TrackSegment* segments;
    int segment_count;

    // Intersection data for path selection (issue 902e)
    TrackIntersection* intersections;
    int intersection_count;

    // Grid data for coordinate conversion
    // Issue 1003: Supports rectangular cells
    float origin_x;
    float origin_y;
    float cell_width;
    float cell_height;

    // Parallel task data (issue 902h)
    MoverTaskData* task_data;
    int task_data_capacity;
} TrackMoverManager;
// }}}

// {{{ track_mover_manager_create
// Creates a track mover manager for the given world.
// Returns NULL on allocation failure.
TrackMoverManager* track_mover_manager_create(World* world);
// }}}

// {{{ track_mover_manager_destroy
// Destroys a track mover manager and frees all resources.
void track_mover_manager_destroy(TrackMoverManager* manager);
// }}}

// {{{ track_mover_manager_clear
// Removes all movers from the manager.
void track_mover_manager_clear(TrackMoverManager* manager);
// }}}

// {{{ track_mover_manager_add_from_board
// Adds movers from BoardData to the manager.
// Converts grid coordinates to pixel positions using provided parameters.
// Detects payload connections and stores initial offsets.
// Issue 1003: Takes cell_width and cell_height for rectangular cell support.
// Returns number of movers added.
int track_mover_manager_add_from_board(TrackMoverManager* manager, BoardData* board,
                                        float origin_x, float origin_y,
                                        float cell_width, float cell_height);
// }}}

// {{{ track_mover_manager_update
// Updates all mover positions along tracks and moves payload.
// Call once per physics frame before ball collision checks.
// dt: Delta time in seconds
// NOTE: For sequential update. Use prepare/submit/wait pattern for parallel.
void track_mover_manager_update(TrackMoverManager* manager, float dt);
// }}}

// {{{ track_mover_manager_prepare_tasks
// Prepares task data for parallel mover updates (issue 902h).
// Sets up mover pointers, manager reference, and dt for each task.
// Call once per frame before submitting tasks to threadpool.
void track_mover_manager_prepare_tasks(TrackMoverManager* manager, float dt);
// }}}

// {{{ track_mover_manager_submit_tasks
// Submits mover update tasks to the threadpool (issue 902h).
// Each task updates a single mover independently.
// Call after prepare_tasks, before threadpool_wait_all.
void track_mover_manager_submit_tasks(TrackMoverManager* manager, ThreadPool* pool);
// }}}

// {{{ track_mover_get_world_position
// Gets the current world position of a mover.
// Returns position via out_x and out_y pointers.
void track_mover_get_world_position(TrackMoverManager* manager, int mover_index,
                                     float* out_x, float* out_y);
// }}}

// {{{ track_mover_get_line_velocity
// Gets the velocity of a line attached to a mover at a collision point.
// Used to add momentum transfer during ball-line collision.
// Returns 0 if line is not connected to any mover, 1 if velocity calculated.
int track_mover_get_line_velocity(TrackMoverManager* manager, int line_index,
                                   float collision_x, float collision_y,
                                   float* out_vx, float* out_vy);
// }}}

#endif // TRACK_MOVER_H
