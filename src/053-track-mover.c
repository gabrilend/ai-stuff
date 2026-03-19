// src/053-track-mover.c
// Track mover physics implementation (issues 902c, 902d)
// Updates mover positions along tracks and moves attached payload

#include "052-track-mover.h"
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

// =============================================================================
// Helper Functions
// =============================================================================

// {{{ mover_physics_init
// Initializes a MoverPhysics struct to default values.
static void mover_physics_init(MoverPhysics* mover) {
    mover->current_segment = 0;
    mover->position_on_segment = 0.0f;
    mover->direction = 1;
    mover->speed = 100.0f;
    mover->world_x = 0.0f;
    mover->world_y = 0.0f;
    mover->payload = NULL;
    mover->payload_count = 0;
    mover->payload_capacity = 0;
    mover->connected_line_indices = NULL;
    mover->connected_line_count = 0;
    mover->connected_peg_indices = NULL;
    mover->connected_peg_count = 0;
}
// }}}

// {{{ mover_physics_cleanup
// Frees resources associated with a MoverPhysics struct.
static void mover_physics_cleanup(MoverPhysics* mover) {
    if (mover->payload) {
        free(mover->payload);
        mover->payload = NULL;
    }
    if (mover->connected_line_indices) {
        free(mover->connected_line_indices);
        mover->connected_line_indices = NULL;
    }
    if (mover->connected_peg_indices) {
        free(mover->connected_peg_indices);
        mover->connected_peg_indices = NULL;
    }
    mover->payload_count = 0;
    mover->payload_capacity = 0;
    mover->connected_line_count = 0;
    mover->connected_peg_count = 0;
}
// }}}

// {{{ segment_get_world_endpoints
// Gets the world pixel coordinates for a track segment's endpoints.
static void segment_get_world_endpoints(TrackSegment* seg, float origin_x, float origin_y,
                                        float cell_size, float* x1, float* y1,
                                        float* x2, float* y2) {
    *x1 = origin_x + seg->col1 * cell_size;
    *y1 = origin_y + seg->row1 * cell_size;
    *x2 = origin_x + seg->col2 * cell_size;
    *y2 = origin_y + seg->row2 * cell_size;
}
// }}}

// {{{ segment_get_length
// Calculates segment length in pixels.
static float segment_get_length(TrackSegment* seg, float cell_size) {
    float dx = (seg->col2 - seg->col1) * cell_size;
    float dy = (seg->row2 - seg->row1) * cell_size;
    return sqrtf(dx * dx + dy * dy);
}
// }}}

// {{{ interpolate_position
// Interpolates position along a segment (t from 0 to 1).
static void interpolate_position(float x1, float y1, float x2, float y2,
                                 float t, float* out_x, float* out_y) {
    *out_x = x1 + (x2 - x1) * t;
    *out_y = y1 + (y2 - y1) * t;
}
// }}}

// {{{ point_touches_object
// Checks if a point (mover position) touches a board object.
// Uses grid proximity for pegs, segment proximity for lines.
// Returns 1 if touching, 0 otherwise.
static int point_touches_object(float px, float py, BoardObject* obj,
                                float origin_x, float origin_y, float cell_size) {
    // Tolerance for "touching" in grid units (1 = adjacent cell)
    float tolerance = cell_size * 1.1f;

    if (obj->type == OBJECT_PEG) {
        float ox = origin_x + obj->col * cell_size;
        float oy = origin_y + obj->row * cell_size;
        float dx = px - ox;
        float dy = py - oy;
        return (dx * dx + dy * dy) <= (tolerance * tolerance);
    } else if (obj->type == OBJECT_LINE) {
        // Check if point is near either endpoint or along the line
        float x1 = origin_x + obj->col * cell_size;
        float y1 = origin_y + obj->row * cell_size;
        float x2 = origin_x + obj->end_col * cell_size;
        float y2 = origin_y + obj->end_row * cell_size;

        // Check endpoints
        float d1_sq = (px - x1) * (px - x1) + (py - y1) * (py - y1);
        float d2_sq = (px - x2) * (px - x2) + (py - y2) * (py - y2);
        if (d1_sq <= tolerance * tolerance || d2_sq <= tolerance * tolerance) {
            return 1;
        }

        // Check along line segment (point-to-line distance)
        float line_len_sq = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1);
        if (line_len_sq < 0.001f) return 0;

        float t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / line_len_sq;
        if (t < 0.0f || t > 1.0f) return 0;  // Beyond segment ends

        float closest_x = x1 + t * (x2 - x1);
        float closest_y = y1 + t * (y2 - y1);
        float dist_sq = (px - closest_x) * (px - closest_x) +
                        (py - closest_y) * (py - closest_y);
        return dist_sq <= tolerance * tolerance;
    }
    return 0;
}
// }}}

// {{{ detect_payload_bfs
// Detects connected objects using BFS from mover position.
// Sets connected arrays in the mover physics struct.
// Issue 902c: Payload detection algorithm
static void detect_payload_bfs(MoverPhysics* mover, BoardData* board,
                               float mover_x, float mover_y,
                               float origin_x, float origin_y, float cell_size) {
    // Track which objects are connected
    int* visited = (int*)calloc(board->object_count, sizeof(int));
    if (!visited) return;

    // BFS queue (object indices)
    int* queue = (int*)malloc(sizeof(int) * board->object_count);
    if (!queue) {
        free(visited);
        return;
    }
    int queue_head = 0;
    int queue_tail = 0;

    // Find initial objects touching mover position
    for (int i = 0; i < board->object_count; i++) {
        BoardObject* obj = &board->objects[i];
        if (point_touches_object(mover_x, mover_y, obj,
                                 origin_x, origin_y, cell_size)) {
            visited[i] = 1;
            queue[queue_tail++] = i;
        }
    }

    // BFS to find transitively connected objects
    while (queue_head < queue_tail) {
        int current_idx = queue[queue_head++];
        BoardObject* current = &board->objects[current_idx];

        // Get current object's world position
        float cx, cy;
        if (current->type == OBJECT_PEG) {
            cx = origin_x + current->col * cell_size;
            cy = origin_y + current->row * cell_size;
        } else {
            // For lines, use midpoint
            cx = origin_x + (current->col + current->end_col) * 0.5f * cell_size;
            cy = origin_y + (current->row + current->end_row) * 0.5f * cell_size;
        }

        // Check all other objects for adjacency
        for (int i = 0; i < board->object_count; i++) {
            if (visited[i]) continue;
            BoardObject* obj = &board->objects[i];

            // Check if current object touches this object
            int touches = 0;
            if (current->type == OBJECT_LINE) {
                // Line endpoints
                float lx1 = origin_x + current->col * cell_size;
                float ly1 = origin_y + current->row * cell_size;
                float lx2 = origin_x + current->end_col * cell_size;
                float ly2 = origin_y + current->end_row * cell_size;
                touches = point_touches_object(lx1, ly1, obj, origin_x, origin_y, cell_size) ||
                          point_touches_object(lx2, ly2, obj, origin_x, origin_y, cell_size);
            } else {
                // Peg center
                touches = point_touches_object(cx, cy, obj, origin_x, origin_y, cell_size);
            }

            if (touches) {
                visited[i] = 1;
                queue[queue_tail++] = i;
            }
        }
    }

    // Count connected objects by type
    int line_count = 0;
    int peg_count = 0;
    for (int i = 0; i < board->object_count; i++) {
        if (visited[i]) {
            if (board->objects[i].type == OBJECT_LINE) line_count++;
            else if (board->objects[i].type == OBJECT_PEG) peg_count++;
        }
    }

    // Allocate payload arrays
    if (line_count > 0) {
        mover->connected_line_indices = (int*)malloc(sizeof(int) * line_count);
        mover->payload = (MoverPayload*)realloc(mover->payload,
            sizeof(MoverPayload) * (mover->payload_count + line_count));
    }
    if (peg_count > 0) {
        mover->connected_peg_indices = (int*)malloc(sizeof(int) * peg_count);
        if (!mover->payload) {
            mover->payload = (MoverPayload*)malloc(sizeof(MoverPayload) * peg_count);
        } else {
            mover->payload = (MoverPayload*)realloc(mover->payload,
                sizeof(MoverPayload) * (mover->payload_count + line_count + peg_count));
        }
    }

    // Map connected objects to World indices and store offsets
    // World lines/pegs are added in order from BoardData
    int world_line_idx = 0;
    int world_peg_idx = 0;
    int connected_line_idx = 0;
    int connected_peg_idx = 0;

    for (int i = 0; i < board->object_count; i++) {
        BoardObject* obj = &board->objects[i];
        int is_connected = visited[i];

        if (obj->type == OBJECT_LINE) {
            if (is_connected && line_count > 0 && mover->connected_line_indices) {
                mover->connected_line_indices[connected_line_idx] = world_line_idx;

                // Store payload offset (line midpoint relative to mover)
                float lx = origin_x + (obj->col + obj->end_col) * 0.5f * cell_size;
                float ly = origin_y + (obj->row + obj->end_row) * 0.5f * cell_size;

                // Calculate line half dimensions for runtime reconstruction
                float half_dx = (obj->end_col - obj->col) * 0.5f * cell_size;
                float half_dy = (obj->end_row - obj->row) * 0.5f * cell_size;

                MoverPayload* pl = &mover->payload[mover->payload_count++];
                pl->object_index = i;
                pl->object_type = OBJECT_LINE;
                pl->offset_x = lx - mover_x;
                pl->offset_y = ly - mover_y;
                pl->line_half_dx = half_dx;
                pl->line_half_dy = half_dy;

                connected_line_idx++;
            }
            world_line_idx++;
        } else if (obj->type == OBJECT_PEG) {
            if (is_connected && peg_count > 0 && mover->connected_peg_indices) {
                mover->connected_peg_indices[connected_peg_idx] = world_peg_idx;

                // Store payload offset (peg center relative to mover)
                float px = origin_x + obj->col * cell_size;
                float py = origin_y + obj->row * cell_size;

                MoverPayload* pl = &mover->payload[mover->payload_count++];
                pl->object_index = i;
                pl->object_type = OBJECT_PEG;
                pl->offset_x = px - mover_x;
                pl->offset_y = py - mover_y;
                pl->line_half_dx = 0.0f;  // Not used for pegs
                pl->line_half_dy = 0.0f;

                connected_peg_idx++;
            }
            world_peg_idx++;
        }
    }

    mover->connected_line_count = connected_line_idx;
    mover->connected_peg_count = connected_peg_idx;

    free(visited);
    free(queue);

    printf("Mover payload detected: %d lines, %d pegs\n",
           mover->connected_line_count, mover->connected_peg_count);
}
// }}}

// =============================================================================
// Manager Functions
// =============================================================================

// {{{ track_mover_manager_create
TrackMoverManager* track_mover_manager_create(World* world) {
    TrackMoverManager* manager = (TrackMoverManager*)malloc(sizeof(TrackMoverManager));
    if (!manager) return NULL;

    manager->movers = NULL;
    manager->mover_count = 0;
    manager->mover_capacity = 0;
    manager->world = world;
    manager->segments = NULL;
    manager->segment_count = 0;
    manager->origin_x = 0.0f;
    manager->origin_y = 0.0f;
    manager->cell_size = 43.0f;

    return manager;
}
// }}}

// {{{ track_mover_manager_destroy
void track_mover_manager_destroy(TrackMoverManager* manager) {
    if (!manager) return;

    track_mover_manager_clear(manager);
    if (manager->movers) {
        free(manager->movers);
    }
    free(manager);
}
// }}}

// {{{ track_mover_manager_clear
void track_mover_manager_clear(TrackMoverManager* manager) {
    if (!manager) return;

    for (int i = 0; i < manager->mover_count; i++) {
        mover_physics_cleanup(&manager->movers[i]);
    }
    manager->mover_count = 0;
    manager->segments = NULL;
    manager->segment_count = 0;
}
// }}}

// {{{ track_mover_manager_add_from_board
int track_mover_manager_add_from_board(TrackMoverManager* manager, BoardData* board,
                                        float origin_x, float origin_y, float cell_size) {
    if (!manager || !board || board->track_mover_count == 0) return 0;

    // Store grid parameters
    manager->origin_x = origin_x;
    manager->origin_y = origin_y;
    manager->cell_size = cell_size;

    // Store segment references
    manager->segments = board->track_segments;
    manager->segment_count = board->track_segment_count;

    // Ensure capacity
    int needed = manager->mover_count + board->track_mover_count;
    if (needed > manager->mover_capacity) {
        int new_capacity = needed + 4;
        MoverPhysics* new_movers = (MoverPhysics*)realloc(
            manager->movers, sizeof(MoverPhysics) * new_capacity);
        if (!new_movers) return 0;
        manager->movers = new_movers;
        manager->mover_capacity = new_capacity;
    }

    int added = 0;

    for (int m = 0; m < board->track_mover_count; m++) {
        TrackMover* src = &board->track_movers[m];
        MoverPhysics* dst = &manager->movers[manager->mover_count];
        mover_physics_init(dst);

        // Copy basic properties
        dst->current_segment = src->current_segment;
        dst->position_on_segment = src->position_on_segment;
        dst->direction = src->direction;
        dst->speed = src->speed * cell_size;  // Convert grid units/sec to pixels/sec

        // Validate segment index
        if (dst->current_segment < 0 || dst->current_segment >= board->track_segment_count) {
            printf("Warning: Mover %d has invalid segment %d, skipping\n",
                   m, dst->current_segment);
            continue;
        }

        // Calculate initial world position
        TrackSegment* seg = &board->track_segments[dst->current_segment];
        float x1, y1, x2, y2;
        segment_get_world_endpoints(seg, origin_x, origin_y, cell_size,
                                    &x1, &y1, &x2, &y2);
        interpolate_position(x1, y1, x2, y2, dst->position_on_segment,
                            &dst->world_x, &dst->world_y);

        // Detect payload (issue 902c)
        detect_payload_bfs(dst, board, dst->world_x, dst->world_y,
                          origin_x, origin_y, cell_size);

        manager->mover_count++;
        added++;

        printf("Added mover at (%.1f, %.1f) on segment %d, speed=%.1f px/s\n",
               dst->world_x, dst->world_y, dst->current_segment, dst->speed);
    }

    return added;
}
// }}}

// {{{ handle_segment_transition
// Handles transition when mover reaches segment endpoint.
// Updates current segment, position, and direction.
// Issue 902d: Segment transition logic
static void handle_segment_transition(MoverPhysics* mover, TrackMoverManager* manager,
                                       int endpoint) {
    if (manager->segment_count == 0) return;

    TrackSegment* seg = &manager->segments[mover->current_segment];

    // Get connections at the reached endpoint
    int* connections;
    int connection_count;
    if (endpoint == 1) {  // Reached end point (position > 1.0)
        connections = seg->connections_end;
        connection_count = seg->connections_end_count;
    } else {  // Reached start point (position < 0.0)
        connections = seg->connections_start;
        connection_count = seg->connections_start_count;
    }

    if (connection_count == 0) {
        // Dead end - reverse direction (issue 902f behavior)
        mover->direction = -mover->direction;
        mover->position_on_segment = (endpoint == 1) ? 1.0f : 0.0f;
        return;
    }

    // Select next segment (for now, just take first connection)
    // Issue 902e will add proper intersection path selection
    int next_segment = connections[0];
    TrackSegment* next = &manager->segments[next_segment];

    // Determine which end of the new segment we're entering from
    int entry_end;
    float seg_end_col = (endpoint == 1) ? seg->col2 : seg->col1;
    float seg_end_row = (endpoint == 1) ? seg->row2 : seg->row1;

    // Check if we enter at start or end of next segment
    if (next->col1 == seg_end_col && next->row1 == seg_end_row) {
        // Entering at start of next segment
        entry_end = 0;
        mover->position_on_segment = 0.0f;
        mover->direction = 1;
    } else {
        // Entering at end of next segment
        entry_end = 1;
        mover->position_on_segment = 1.0f;
        mover->direction = -1;
    }

    // Handle position overflow/underflow
    float overflow = (endpoint == 1) ?
        (mover->position_on_segment - 1.0f) :
        (-mover->position_on_segment);

    mover->current_segment = next_segment;
    mover->position_on_segment += mover->direction * overflow;
}
// }}}

// {{{ update_payload_positions
// Updates world positions of all payload objects based on mover position.
// Issue 902c: Payload follows mover
// Uses stored geometry data instead of BoardData for runtime independence.
static void update_payload_positions(MoverPhysics* mover, World* world) {
    if (!world) return;

    // Track which line/peg index we're at in connected arrays
    int line_payload_idx = 0;
    int peg_payload_idx = 0;

    // Iterate through all payload items
    for (int p = 0; p < mover->payload_count; p++) {
        MoverPayload* pl = &mover->payload[p];

        if (pl->object_type == OBJECT_LINE) {
            // Get world line index from connected array
            if (line_payload_idx >= mover->connected_line_count) continue;
            int line_idx = mover->connected_line_indices[line_payload_idx];
            line_payload_idx++;

            if (line_idx < 0 || line_idx >= world->line_count) continue;
            Line* line = &world->lines[line_idx];

            // Calculate new line position from stored geometry
            float new_mid_x = mover->world_x + pl->offset_x;
            float new_mid_y = mover->world_y + pl->offset_y;

            line->x1 = new_mid_x - pl->line_half_dx;
            line->y1 = new_mid_y - pl->line_half_dy;
            line->x2 = new_mid_x + pl->line_half_dx;
            line->y2 = new_mid_y + pl->line_half_dy;

        } else if (pl->object_type == OBJECT_PEG) {
            // Get world peg index from connected array
            if (peg_payload_idx >= mover->connected_peg_count) continue;
            int peg_idx = mover->connected_peg_indices[peg_payload_idx];
            peg_payload_idx++;

            if (peg_idx < 0 || peg_idx >= world->peg_count) continue;
            Peg* peg = &world->pegs[peg_idx];

            // Update peg position from stored offset
            peg->x = mover->world_x + pl->offset_x;
            peg->y = mover->world_y + pl->offset_y;
        }
    }
}
// }}}

// {{{ track_mover_manager_update
void track_mover_manager_update(TrackMoverManager* manager, float dt) {
    if (!manager || !manager->world || manager->segment_count == 0) return;

    for (int m = 0; m < manager->mover_count; m++) {
        MoverPhysics* mover = &manager->movers[m];

        // Get current segment
        if (mover->current_segment < 0 ||
            mover->current_segment >= manager->segment_count) continue;

        TrackSegment* seg = &manager->segments[mover->current_segment];

        // Calculate segment length
        float seg_length = segment_get_length(seg, manager->cell_size);
        if (seg_length < 0.001f) continue;

        // Advance position along segment
        // Issue 902d: Track following physics
        float distance = mover->speed * dt;
        float position_delta = distance / seg_length;
        mover->position_on_segment += position_delta * mover->direction;

        // Check for segment end
        if (mover->position_on_segment > 1.0f) {
            handle_segment_transition(mover, manager, 1);
        } else if (mover->position_on_segment < 0.0f) {
            handle_segment_transition(mover, manager, 0);
        }

        // Clamp position (in case of edge cases)
        if (mover->position_on_segment < 0.0f) mover->position_on_segment = 0.0f;
        if (mover->position_on_segment > 1.0f) mover->position_on_segment = 1.0f;

        // Update world position
        float x1, y1, x2, y2;
        segment_get_world_endpoints(&manager->segments[mover->current_segment],
                                    manager->origin_x, manager->origin_y,
                                    manager->cell_size, &x1, &y1, &x2, &y2);
        interpolate_position(x1, y1, x2, y2, mover->position_on_segment,
                            &mover->world_x, &mover->world_y);

        // Update payload positions (issue 902c)
        // Uses stored geometry data - no BoardData needed at runtime
        update_payload_positions(mover, manager->world);
    }
}
// }}}

// {{{ track_mover_get_world_position
void track_mover_get_world_position(TrackMoverManager* manager, int mover_index,
                                     float* out_x, float* out_y) {
    if (!manager || mover_index < 0 || mover_index >= manager->mover_count) {
        if (out_x) *out_x = 0.0f;
        if (out_y) *out_y = 0.0f;
        return;
    }

    MoverPhysics* mover = &manager->movers[mover_index];
    if (out_x) *out_x = mover->world_x;
    if (out_y) *out_y = mover->world_y;
}
// }}}

// {{{ track_mover_get_line_velocity
int track_mover_get_line_velocity(TrackMoverManager* manager, int line_index,
                                   float collision_x, float collision_y,
                                   float* out_vx, float* out_vy) {
    if (!manager || !out_vx || !out_vy) return 0;

    *out_vx = 0.0f;
    *out_vy = 0.0f;

    // Find which mover (if any) this line is connected to
    for (int m = 0; m < manager->mover_count; m++) {
        MoverPhysics* mover = &manager->movers[m];

        for (int i = 0; i < mover->connected_line_count; i++) {
            if (mover->connected_line_indices[i] == line_index) {
                // Found the mover - calculate velocity along track
                if (mover->current_segment < 0 ||
                    mover->current_segment >= manager->segment_count) return 0;

                TrackSegment* seg = &manager->segments[mover->current_segment];

                // Segment direction vector (normalized)
                float dx = (seg->col2 - seg->col1) * manager->cell_size;
                float dy = (seg->row2 - seg->row1) * manager->cell_size;
                float len = sqrtf(dx * dx + dy * dy);
                if (len < 0.001f) return 0;

                // Velocity is speed along segment direction
                float dir = (float)mover->direction;
                *out_vx = (dx / len) * mover->speed * dir;
                *out_vy = (dy / len) * mover->speed * dir;

                return 1;
            }
        }
    }

    return 0;
}
// }}}
