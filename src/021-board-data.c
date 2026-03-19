// src/021-board-data.c
// Board data implementation with JSON serialization
// Uses cJSON library for parsing and generating JSON

#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <dirent.h>
#include "020-board-data.h"
#include "022-grid.h"  // For BOARD_WIDTH, BOARD_HEIGHT (issue 838)
#include "cJSON.h"

#define INITIAL_CAPACITY 32

// =============================================================================
// BoardData Creation and Destruction
// =============================================================================

// {{{ board_data_create
BoardData* board_data_create(int grid_cols, int grid_rows, int cell_size) {
    BoardData* data = (BoardData*)calloc(1, sizeof(BoardData));
    if (!data) {
        fprintf(stderr, "ERROR: Failed to allocate BoardData\n");
        return NULL;
    }

    data->version = 1;
    strcpy(data->name, "Untitled");

    data->cell_size = cell_size;
    data->grid_cols = grid_cols;
    data->grid_rows = grid_rows;
    data->board_width = grid_cols * cell_size;
    data->board_height = grid_rows * cell_size;

    // Allocate object array
    data->object_capacity = INITIAL_CAPACITY;
    data->objects = (BoardObject*)calloc(data->object_capacity, sizeof(BoardObject));
    if (!data->objects) {
        fprintf(stderr, "ERROR: Failed to allocate object array\n");
        free(data);
        return NULL;
    }
    data->object_count = 0;

    // Allocate zone array
    data->zone_capacity = INITIAL_CAPACITY;
    data->zones = (BoardZone*)calloc(data->zone_capacity, sizeof(BoardZone));
    if (!data->zones) {
        fprintf(stderr, "ERROR: Failed to allocate zone array\n");
        free(data->objects);
        free(data);
        return NULL;
    }
    data->zone_count = 0;

    // Initialize rotor array (issue 901a)
    data->rotor_capacity = 8;  // Smaller initial capacity, rotors are less common
    data->rotors = (Rotor*)calloc(data->rotor_capacity, sizeof(Rotor));
    if (!data->rotors) {
        fprintf(stderr, "ERROR: Failed to allocate rotor array\n");
        free(data->zones);
        free(data->objects);
        free(data);
        return NULL;
    }
    data->rotor_count = 0;

    // Initialize track segment array (issue 902a)
    data->track_segment_capacity = 16;
    data->track_segments = (TrackSegment*)calloc(data->track_segment_capacity,
                                                  sizeof(TrackSegment));
    if (!data->track_segments) {
        fprintf(stderr, "ERROR: Failed to allocate track segment array\n");
        free(data->rotors);
        free(data->zones);
        free(data->objects);
        free(data);
        return NULL;
    }
    data->track_segment_count = 0;

    // Track intersections are computed, not allocated upfront
    data->track_intersections = NULL;
    data->track_intersection_count = 0;

    // Initialize track mover array
    data->track_mover_capacity = 8;
    data->track_movers = (TrackMover*)calloc(data->track_mover_capacity,
                                              sizeof(TrackMover));
    if (!data->track_movers) {
        fprintf(stderr, "ERROR: Failed to allocate track mover array\n");
        free(data->track_segments);
        free(data->rotors);
        free(data->zones);
        free(data->objects);
        free(data);
        return NULL;
    }
    data->track_mover_count = 0;

    return data;
}
// }}}

// {{{ board_data_destroy
void board_data_destroy(BoardData* data) {
    if (!data) return;

    if (data->objects) {
        free(data->objects);
    }
    if (data->zones) {
        free(data->zones);
    }

    // Free rotor connections and rotors (issue 901a)
    if (data->rotors) {
        for (int i = 0; i < data->rotor_count; i++) {
            if (data->rotors[i].connections) {
                free(data->rotors[i].connections);
            }
        }
        free(data->rotors);
    }

    // Free track segments and their connection arrays (issue 902a)
    if (data->track_segments) {
        for (int i = 0; i < data->track_segment_count; i++) {
            if (data->track_segments[i].connections_start) {
                free(data->track_segments[i].connections_start);
            }
            if (data->track_segments[i].connections_end) {
                free(data->track_segments[i].connections_end);
            }
        }
        free(data->track_segments);
    }

    // Free track intersections
    if (data->track_intersections) {
        for (int i = 0; i < data->track_intersection_count; i++) {
            TrackIntersection* inter = &data->track_intersections[i];
            if (inter->segment_indices) {
                free(inter->segment_indices);
            }
            if (inter->approach_paths) {
                for (int j = 0; j < inter->segment_count; j++) {
                    if (inter->approach_paths[j]) {
                        free(inter->approach_paths[j]);
                    }
                }
                free(inter->approach_paths);
            }
            if (inter->approach_path_counts) {
                free(inter->approach_path_counts);
            }
        }
        free(data->track_intersections);
    }

    // Free track movers and their payloads
    if (data->track_movers) {
        for (int i = 0; i < data->track_mover_count; i++) {
            if (data->track_movers[i].payload_indices) {
                free(data->track_movers[i].payload_indices);
            }
            if (data->track_movers[i].payload_offsets_x) {
                free(data->track_movers[i].payload_offsets_x);
            }
            if (data->track_movers[i].payload_offsets_y) {
                free(data->track_movers[i].payload_offsets_y);
            }
        }
        free(data->track_movers);
    }

    free(data);
}
// }}}

// =============================================================================
// Internal Helpers
// =============================================================================

// {{{ ensure_object_capacity
static int ensure_object_capacity(BoardData* data) {
    if (data->object_count < data->object_capacity) {
        return 1;  // Already have room
    }

    int new_capacity = data->object_capacity * 2;
    BoardObject* new_objects = (BoardObject*)realloc(
        data->objects, new_capacity * sizeof(BoardObject));

    if (!new_objects) {
        fprintf(stderr, "ERROR: Failed to grow object array\n");
        return 0;
    }

    data->objects = new_objects;
    data->object_capacity = new_capacity;
    return 1;
}
// }}}

// {{{ ensure_zone_capacity
static int ensure_zone_capacity(BoardData* data) {
    if (data->zone_count < data->zone_capacity) {
        return 1;
    }

    int new_capacity = data->zone_capacity * 2;
    BoardZone* new_zones = (BoardZone*)realloc(
        data->zones, new_capacity * sizeof(BoardZone));

    if (!new_zones) {
        fprintf(stderr, "ERROR: Failed to grow zone array\n");
        return 0;
    }

    data->zones = new_zones;
    data->zone_capacity = new_capacity;
    return 1;
}
// }}}

// {{{ ensure_rotor_capacity
// Ensures there's room for at least one more rotor.
// Doubles capacity when full.
static int ensure_rotor_capacity(BoardData* data) {
    if (data->rotor_count < data->rotor_capacity) {
        return 1;
    }

    int new_capacity = data->rotor_capacity * 2;
    Rotor* new_rotors = (Rotor*)realloc(
        data->rotors, new_capacity * sizeof(Rotor));

    if (!new_rotors) {
        fprintf(stderr, "ERROR: Failed to grow rotor array\n");
        return 0;
    }

    data->rotors = new_rotors;
    data->rotor_capacity = new_capacity;
    return 1;
}
// }}}

// {{{ ensure_rotor_connection_capacity
// Ensures a rotor has room for at least one more connection.
static int ensure_rotor_connection_capacity(Rotor* rotor) {
    if (rotor->connection_count < rotor->connection_capacity) {
        return 1;
    }

    int new_capacity = rotor->connection_capacity == 0 ? 4 : rotor->connection_capacity * 2;
    RotorConnection* new_conns = (RotorConnection*)realloc(
        rotor->connections, new_capacity * sizeof(RotorConnection));

    if (!new_conns) {
        fprintf(stderr, "ERROR: Failed to grow rotor connection array\n");
        return 0;
    }

    rotor->connections = new_conns;
    rotor->connection_capacity = new_capacity;
    return 1;
}
// }}}

// {{{ ensure_track_segment_capacity
static int ensure_track_segment_capacity(BoardData* data) {
    if (data->track_segment_count < data->track_segment_capacity) {
        return 1;
    }

    int new_capacity = data->track_segment_capacity * 2;
    TrackSegment* new_segments = (TrackSegment*)realloc(
        data->track_segments, new_capacity * sizeof(TrackSegment));

    if (!new_segments) {
        fprintf(stderr, "ERROR: Failed to grow track segment array\n");
        return 0;
    }

    data->track_segments = new_segments;
    data->track_segment_capacity = new_capacity;
    return 1;
}
// }}}

// {{{ ensure_track_mover_capacity
static int ensure_track_mover_capacity(BoardData* data) {
    if (data->track_mover_count < data->track_mover_capacity) {
        return 1;
    }

    int new_capacity = data->track_mover_capacity * 2;
    TrackMover* new_movers = (TrackMover*)realloc(
        data->track_movers, new_capacity * sizeof(TrackMover));

    if (!new_movers) {
        fprintf(stderr, "ERROR: Failed to grow track mover array\n");
        return 0;
    }

    data->track_movers = new_movers;
    data->track_mover_capacity = new_capacity;
    return 1;
}
// }}}

// =============================================================================
// Object Management
// =============================================================================

// {{{ board_data_add_peg
int board_data_add_peg(BoardData* data, int col, int row) {
    return board_data_add_peg_ex(data, col, row,
                                  DEFAULT_RESTITUTION,
                                  DEFAULT_FRICTION,
                                  DEFAULT_POINT_BONUS);
}
// }}}

// {{{ board_data_add_peg_ex
int board_data_add_peg_ex(BoardData* data, int col, int row,
                          unsigned char restitution, unsigned char friction,
                          unsigned char point_bonus) {
    if (!data) return 0;
    if (!ensure_object_capacity(data)) return 0;

    BoardObject* obj = &data->objects[data->object_count];
    obj->type = OBJECT_PEG;
    obj->col = col;
    obj->row = row;
    obj->radius = 12.0f;  // Default peg radius
    obj->end_col = 0;
    obj->end_row = 0;
    obj->thickness = 0;
    obj->restitution = restitution;
    obj->friction = friction;
    obj->point_bonus = point_bonus;
    // Issue 901e: Initialize dynamic object flags
    // Objects start as static; set is_dynamic=1 when attached to rotor
    obj->is_dynamic = 0;
    obj->rotor_index = -1;

    data->object_count++;
    return 1;
}
// }}}

// {{{ board_data_add_line
int board_data_add_line(BoardData* data, int start_col, int start_row,
                        int end_col, int end_row, float thickness) {
    return board_data_add_line_ex(data, start_col, start_row,
                                   end_col, end_row, thickness,
                                   DEFAULT_RESTITUTION,
                                   DEFAULT_FRICTION,
                                   DEFAULT_POINT_BONUS);
}
// }}}

// {{{ board_data_add_line_ex
int board_data_add_line_ex(BoardData* data, int start_col, int start_row,
                           int end_col, int end_row, float thickness,
                           unsigned char restitution, unsigned char friction,
                           unsigned char point_bonus) {
    if (!data) return 0;
    if (!ensure_object_capacity(data)) return 0;

    BoardObject* obj = &data->objects[data->object_count];
    obj->type = OBJECT_LINE;
    obj->col = start_col;
    obj->row = start_row;
    obj->radius = 0;
    obj->end_col = end_col;
    obj->end_row = end_row;
    obj->thickness = thickness;
    obj->restitution = restitution;
    obj->friction = friction;
    obj->point_bonus = point_bonus;
    // Issue 901e: Initialize dynamic object flags
    // Objects start as static; set is_dynamic=1 when attached to rotor
    obj->is_dynamic = 0;
    obj->rotor_index = -1;

    data->object_count++;
    return 1;
}
// }}}

// {{{ board_data_has_object_at
int board_data_has_object_at(BoardData* data, int col, int row) {
    return board_data_get_object_at(data, col, row) != NULL;
}
// }}}

// {{{ board_data_get_object_at
BoardObject* board_data_get_object_at(BoardData* data, int col, int row) {
    if (!data) return NULL;

    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];

        if (obj->type == OBJECT_PEG) {
            if (obj->col == col && obj->row == row) {
                return obj;
            }
        } else if (obj->type == OBJECT_LINE) {
            // Check if point is on the line segment (grid coordinates)
            // For simplicity, check if it's the start or end point
            // A more thorough check would test points along the line
            if ((obj->col == col && obj->row == row) ||
                (obj->end_col == col && obj->end_row == row)) {
                return obj;
            }
        }
    }

    return NULL;
}
// }}}

// {{{ board_data_remove_object_at
int board_data_remove_object_at(BoardData* data, int col, int row) {
    if (!data) return 0;

    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        int found = 0;

        if (obj->type == OBJECT_PEG) {
            found = (obj->col == col && obj->row == row);
        } else if (obj->type == OBJECT_LINE) {
            found = ((obj->col == col && obj->row == row) ||
                     (obj->end_col == col && obj->end_row == row));
        }

        if (found) {
            // Shift remaining objects down
            for (int j = i; j < data->object_count - 1; j++) {
                data->objects[j] = data->objects[j + 1];
            }
            data->object_count--;
            return 1;
        }
    }

    return 0;
}
// }}}

// =============================================================================
// Zone Management
// =============================================================================

// {{{ board_data_add_score_zone
int board_data_add_score_zone(BoardData* data, int col, int row,
                              int width, int height, int points, int multiplier) {
    if (!data) return 0;
    if (!ensure_zone_capacity(data)) return 0;

    BoardZone* zone = &data->zones[data->zone_count];
    zone->type = ZONE_SCORE;
    zone->col = col;
    zone->row = row;
    zone->width = width;
    zone->height = height;
    zone->points = points;
    zone->multiplier = multiplier;
    zone->channel = 0;
    zone->direction = PORTAL_ENTRY;

    data->zone_count++;
    return 1;
}
// }}}

// {{{ board_data_add_portal
int board_data_add_portal(BoardData* data, int col, int row,
                          int width, int height, int channel,
                          PortalDirection direction) {
    if (!data) return 0;
    if (!ensure_zone_capacity(data)) return 0;

    BoardZone* zone = &data->zones[data->zone_count];
    zone->type = ZONE_PORTAL;
    zone->col = col;
    zone->row = row;
    zone->width = width;
    zone->height = height;
    zone->points = 0;
    zone->multiplier = 0;
    zone->channel = channel;
    zone->direction = direction;

    data->zone_count++;
    return 1;
}
// }}}

// {{{ board_data_remove_zone_at
int board_data_remove_zone_at(BoardData* data, int col, int row) {
    if (!data) return 0;

    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* zone = &data->zones[i];

        // Check if point is within zone bounds
        if (col >= zone->col && col < zone->col + zone->width &&
            row >= zone->row && row < zone->row + zone->height) {
            // Shift remaining zones down
            for (int j = i; j < data->zone_count - 1; j++) {
                data->zones[j] = data->zones[j + 1];
            }
            data->zone_count--;
            return 1;
        }
    }

    return 0;
}
// }}}

// =============================================================================
// Rotor Management (issue 901a)
// =============================================================================

// {{{ board_data_add_rotor
int board_data_add_rotor(BoardData* data, int col, int row, float speed) {
    if (!data) return -1;
    if (!ensure_rotor_capacity(data)) return -1;

    int index = data->rotor_count;
    Rotor* rotor = &data->rotors[index];

    rotor->col = col;
    rotor->row = row;
    rotor->rotation_speed = speed;
    rotor->current_angle = 0.0f;
    rotor->connections = NULL;
    rotor->connection_count = 0;
    rotor->connection_capacity = 0;

    data->rotor_count++;
    return index;
}
// }}}

// {{{ board_data_remove_rotor
int board_data_remove_rotor(BoardData* data, int rotor_index) {
    if (!data) return 0;
    if (rotor_index < 0 || rotor_index >= data->rotor_count) return 0;

    // Free connections for the rotor being removed
    if (data->rotors[rotor_index].connections) {
        free(data->rotors[rotor_index].connections);
    }

    // Shift remaining rotors down
    for (int i = rotor_index; i < data->rotor_count - 1; i++) {
        data->rotors[i] = data->rotors[i + 1];
    }
    data->rotor_count--;
    return 1;
}
// }}}

// {{{ board_data_rotor_add_connection
int board_data_rotor_add_connection(BoardData* data, int rotor_index,
                                    int object_index, float relative_angle,
                                    float relative_distance) {
    if (!data) return 0;
    if (rotor_index < 0 || rotor_index >= data->rotor_count) return 0;
    if (object_index < 0 || object_index >= data->object_count) return 0;

    Rotor* rotor = &data->rotors[rotor_index];
    if (!ensure_rotor_connection_capacity(rotor)) return 0;

    RotorConnection* conn = &rotor->connections[rotor->connection_count];
    conn->object_index = object_index;
    conn->relative_angle = relative_angle;
    conn->relative_distance = relative_distance;

    rotor->connection_count++;
    return 1;
}
// }}}

// {{{ board_data_rotor_clear_connections
void board_data_rotor_clear_connections(BoardData* data, int rotor_index) {
    if (!data) return;
    if (rotor_index < 0 || rotor_index >= data->rotor_count) return;

    Rotor* rotor = &data->rotors[rotor_index];
    rotor->connection_count = 0;
    // Keep allocated capacity for reuse
}
// }}}

// =============================================================================
// Touch Detection Helpers (issue 901d)
// =============================================================================

// Touch threshold in grid units - objects within this distance are "touching"
#define TOUCH_THRESHOLD 0.5f

// {{{ point_to_segment_distance_sq
// Returns squared distance from point (px, py) to line segment (x1,y1)-(x2,y2)
static float point_to_segment_distance_sq(float px, float py,
                                          float x1, float y1,
                                          float x2, float y2) {
    float dx = x2 - x1;
    float dy = y2 - y1;
    float len_sq = dx * dx + dy * dy;

    if (len_sq < 0.0001f) {
        // Degenerate segment (point)
        float dpx = px - x1;
        float dpy = py - y1;
        return dpx * dpx + dpy * dpy;
    }

    // Project point onto line, clamped to segment
    float t = ((px - x1) * dx + (py - y1) * dy) / len_sq;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;

    float proj_x = x1 + t * dx;
    float proj_y = y1 + t * dy;

    float dpx = px - proj_x;
    float dpy = py - proj_y;
    return dpx * dpx + dpy * dpy;
}
// }}}

// {{{ segments_intersect_or_close
// Returns 1 if two line segments intersect or are within threshold distance
static int segments_intersect_or_close(float ax1, float ay1, float ax2, float ay2,
                                       float bx1, float by1, float bx2, float by2,
                                       float threshold) {
    float thresh_sq = threshold * threshold;

    // Check if any endpoint of A is close to segment B
    if (point_to_segment_distance_sq(ax1, ay1, bx1, by1, bx2, by2) <= thresh_sq) return 1;
    if (point_to_segment_distance_sq(ax2, ay2, bx1, by1, bx2, by2) <= thresh_sq) return 1;

    // Check if any endpoint of B is close to segment A
    if (point_to_segment_distance_sq(bx1, by1, ax1, ay1, ax2, ay2) <= thresh_sq) return 1;
    if (point_to_segment_distance_sq(bx2, by2, ax1, ay1, ax2, ay2) <= thresh_sq) return 1;

    // Check for actual intersection (cross product method)
    float d1x = ax2 - ax1, d1y = ay2 - ay1;
    float d2x = bx2 - bx1, d2y = by2 - by1;
    float cross = d1x * d2y - d1y * d2x;

    if (fabsf(cross) < 0.0001f) return 0;  // Parallel

    float t = ((bx1 - ax1) * d2y - (by1 - ay1) * d2x) / cross;
    float u = ((bx1 - ax1) * d1y - (by1 - ay1) * d1x) / cross;

    return (t >= 0.0f && t <= 1.0f && u >= 0.0f && u <= 1.0f);
}
// }}}

// {{{ objects_touch
// Returns 1 if two board objects are touching (within threshold distance)
static int objects_touch(BoardObject* a, BoardObject* b, float threshold) {
    float thresh_sq = threshold * threshold;

    if (a->type == OBJECT_PEG && b->type == OBJECT_PEG) {
        // Peg to peg: check center distance
        float dx = (float)(b->col - a->col);
        float dy = (float)(b->row - a->row);
        return (dx * dx + dy * dy) <= thresh_sq;
    }

    if (a->type == OBJECT_PEG && b->type == OBJECT_LINE) {
        // Peg to line: check distance from peg center to line segment
        float dist_sq = point_to_segment_distance_sq(
            (float)a->col, (float)a->row,
            (float)b->col, (float)b->row,
            (float)b->end_col, (float)b->end_row);
        return dist_sq <= thresh_sq;
    }

    if (a->type == OBJECT_LINE && b->type == OBJECT_PEG) {
        // Line to peg: same as peg to line
        float dist_sq = point_to_segment_distance_sq(
            (float)b->col, (float)b->row,
            (float)a->col, (float)a->row,
            (float)a->end_col, (float)a->end_row);
        return dist_sq <= thresh_sq;
    }

    if (a->type == OBJECT_LINE && b->type == OBJECT_LINE) {
        // Line to line: check intersection or close endpoints
        return segments_intersect_or_close(
            (float)a->col, (float)a->row, (float)a->end_col, (float)a->end_row,
            (float)b->col, (float)b->row, (float)b->end_col, (float)b->end_row,
            threshold);
    }

    return 0;
}
// }}}

// {{{ object_touches_point
// Returns 1 if object touches the given grid point (within threshold)
static int object_touches_point(BoardObject* obj, int col, int row, float threshold) {
    float thresh_sq = threshold * threshold;
    float px = (float)col;
    float py = (float)row;

    if (obj->type == OBJECT_PEG) {
        float dx = (float)obj->col - px;
        float dy = (float)obj->row - py;
        return (dx * dx + dy * dy) <= thresh_sq;
    }

    if (obj->type == OBJECT_LINE) {
        float dist_sq = point_to_segment_distance_sq(
            px, py,
            (float)obj->col, (float)obj->row,
            (float)obj->end_col, (float)obj->end_row);
        return dist_sq <= thresh_sq;
    }

    return 0;
}
// }}}

// {{{ board_data_rotor_detect_connections
// BFS-based connection detection (issue 901d)
// Finds objects that touch the rotor center, then transitively finds
// all objects touching those objects.
int board_data_rotor_detect_connections(BoardData* data, int rotor_index,
                                        int max_distance) {
    if (!data) return 0;
    if (rotor_index < 0 || rotor_index >= data->rotor_count) return 0;
    (void)max_distance;  // Now using touch detection, not distance limit

    // Clear existing connections
    board_data_rotor_clear_connections(data, rotor_index);

    Rotor* rotor = &data->rotors[rotor_index];
    int rotor_col = rotor->col;
    int rotor_row = rotor->row;

    // visited[i] = 1 if object i has been added to connections
    int* visited = (int*)calloc(data->object_count, sizeof(int));
    if (!visited) return 0;

    // BFS queue: indices of objects to process
    int* queue = (int*)malloc(sizeof(int) * data->object_count);
    if (!queue) {
        free(visited);
        return 0;
    }
    int queue_head = 0;
    int queue_tail = 0;

    // Seed: find all objects that directly touch the rotor center
    for (int i = 0; i < data->object_count; i++) {
        if (object_touches_point(&data->objects[i], rotor_col, rotor_row, TOUCH_THRESHOLD)) {
            visited[i] = 1;
            queue[queue_tail++] = i;

            // Calculate relative position for this object
            BoardObject* obj = &data->objects[i];
            float dx, dy;
            if (obj->type == OBJECT_PEG) {
                dx = (float)(obj->col - rotor_col);
                dy = (float)(obj->row - rotor_row);
            } else {
                // For lines, use the start point
                dx = (float)(obj->col - rotor_col);
                dy = (float)(obj->row - rotor_row);
            }
            float angle = atan2f(dy, dx);
            float dist = sqrtf(dx * dx + dy * dy);
            board_data_rotor_add_connection(data, rotor_index, i, angle, dist);
        }
    }

    // BFS: find all transitively connected objects
    while (queue_head < queue_tail) {
        int current_idx = queue[queue_head++];
        BoardObject* current = &data->objects[current_idx];

        // Check all other objects for touching
        for (int i = 0; i < data->object_count; i++) {
            if (visited[i]) continue;

            if (objects_touch(current, &data->objects[i], TOUCH_THRESHOLD)) {
                visited[i] = 1;
                queue[queue_tail++] = i;

                // Calculate relative position
                BoardObject* obj = &data->objects[i];
                float dx, dy;
                if (obj->type == OBJECT_PEG) {
                    dx = (float)(obj->col - rotor_col);
                    dy = (float)(obj->row - rotor_row);
                } else {
                    dx = (float)(obj->col - rotor_col);
                    dy = (float)(obj->row - rotor_row);
                }
                float angle = atan2f(dy, dx);
                float dist = sqrtf(dx * dx + dy * dy);
                board_data_rotor_add_connection(data, rotor_index, i, angle, dist);
            }
        }
    }

    free(visited);
    free(queue);

    return rotor->connection_count;
}
// }}}

// =============================================================================
// Track Management (issue 902a)
// =============================================================================

// {{{ board_data_add_track_segment
int board_data_add_track_segment(BoardData* data, int col1, int row1,
                                 int col2, int row2) {
    if (!data) return -1;
    if (!ensure_track_segment_capacity(data)) return -1;

    int index = data->track_segment_count;
    TrackSegment* seg = &data->track_segments[index];

    seg->id = index;
    seg->col1 = col1;
    seg->row1 = row1;
    seg->col2 = col2;
    seg->row2 = row2;

    // Calculate length in grid units (will be scaled to pixels at runtime)
    int dx = col2 - col1;
    int dy = row2 - row1;
    seg->length = sqrtf((float)(dx * dx + dy * dy));

    // Initialize connectivity (computed later)
    seg->connections_start = NULL;
    seg->connections_start_count = 0;
    seg->connections_end = NULL;
    seg->connections_end_count = 0;

    data->track_segment_count++;
    return index;
}
// }}}

// {{{ board_data_remove_track_segment
int board_data_remove_track_segment(BoardData* data, int segment_index) {
    if (!data) return 0;
    if (segment_index < 0 || segment_index >= data->track_segment_count) return 0;

    // Free connection arrays
    TrackSegment* seg = &data->track_segments[segment_index];
    if (seg->connections_start) free(seg->connections_start);
    if (seg->connections_end) free(seg->connections_end);

    // Shift remaining segments down
    for (int i = segment_index; i < data->track_segment_count - 1; i++) {
        data->track_segments[i] = data->track_segments[i + 1];
    }
    data->track_segment_count--;

    // Update segment IDs and any references in movers
    for (int i = segment_index; i < data->track_segment_count; i++) {
        data->track_segments[i].id = i;
    }
    // Update mover references to segments
    for (int i = 0; i < data->track_mover_count; i++) {
        if (data->track_movers[i].current_segment > segment_index) {
            data->track_movers[i].current_segment--;
        } else if (data->track_movers[i].current_segment == segment_index) {
            // Mover was on removed segment - place on segment 0 or mark invalid
            data->track_movers[i].current_segment = 0;
            data->track_movers[i].position_on_segment = 0.0f;
        }
    }

    return 1;
}
// }}}

// {{{ board_data_add_track_mover
int board_data_add_track_mover(BoardData* data, int segment_index,
                               float position, float speed) {
    if (!data) return -1;
    if (segment_index < 0 || segment_index >= data->track_segment_count) return -1;
    if (!ensure_track_mover_capacity(data)) return -1;

    int index = data->track_mover_count;
    TrackMover* mover = &data->track_movers[index];

    mover->id = index;
    mover->current_segment = segment_index;
    mover->position_on_segment = position;
    mover->direction = 1;  // Start moving toward end
    mover->speed = speed;
    mover->payload_indices = NULL;
    mover->payload_count = 0;
    mover->payload_offsets_x = NULL;
    mover->payload_offsets_y = NULL;

    data->track_mover_count++;
    return index;
}
// }}}

// {{{ board_data_remove_track_mover
int board_data_remove_track_mover(BoardData* data, int mover_index) {
    if (!data) return 0;
    if (mover_index < 0 || mover_index >= data->track_mover_count) return 0;

    // Free payload arrays
    TrackMover* mover = &data->track_movers[mover_index];
    if (mover->payload_indices) free(mover->payload_indices);
    if (mover->payload_offsets_x) free(mover->payload_offsets_x);
    if (mover->payload_offsets_y) free(mover->payload_offsets_y);

    // Shift remaining movers down
    for (int i = mover_index; i < data->track_mover_count - 1; i++) {
        data->track_movers[i] = data->track_movers[i + 1];
    }
    data->track_mover_count--;

    // Update mover IDs
    for (int i = mover_index; i < data->track_mover_count; i++) {
        data->track_movers[i].id = i;
    }

    return 1;
}
// }}}

// {{{ board_data_track_mover_add_payload
int board_data_track_mover_add_payload(BoardData* data, int mover_index,
                                       int object_index, float offset_x,
                                       float offset_y) {
    if (!data) return 0;
    if (mover_index < 0 || mover_index >= data->track_mover_count) return 0;
    if (object_index < 0 || object_index >= data->object_count) return 0;

    TrackMover* mover = &data->track_movers[mover_index];
    int new_count = mover->payload_count + 1;

    // Reallocate arrays
    int* new_indices = (int*)realloc(mover->payload_indices, new_count * sizeof(int));
    float* new_x = (float*)realloc(mover->payload_offsets_x, new_count * sizeof(float));
    float* new_y = (float*)realloc(mover->payload_offsets_y, new_count * sizeof(float));

    if (!new_indices || !new_x || !new_y) {
        fprintf(stderr, "ERROR: Failed to grow mover payload arrays\n");
        return 0;
    }

    mover->payload_indices = new_indices;
    mover->payload_offsets_x = new_x;
    mover->payload_offsets_y = new_y;

    mover->payload_indices[mover->payload_count] = object_index;
    mover->payload_offsets_x[mover->payload_count] = offset_x;
    mover->payload_offsets_y[mover->payload_count] = offset_y;
    mover->payload_count = new_count;

    return 1;
}
// }}}

// {{{ board_data_compute_track_connectivity
void board_data_compute_track_connectivity(BoardData* data) {
    if (!data) return;

    // Clear existing connectivity
    for (int i = 0; i < data->track_segment_count; i++) {
        TrackSegment* seg = &data->track_segments[i];
        if (seg->connections_start) {
            free(seg->connections_start);
            seg->connections_start = NULL;
        }
        if (seg->connections_end) {
            free(seg->connections_end);
            seg->connections_end = NULL;
        }
        seg->connections_start_count = 0;
        seg->connections_end_count = 0;
    }

    // For each segment, find other segments that share endpoints
    for (int i = 0; i < data->track_segment_count; i++) {
        TrackSegment* seg_i = &data->track_segments[i];

        // Count connections at each endpoint first
        int start_conns = 0;
        int end_conns = 0;

        for (int j = 0; j < data->track_segment_count; j++) {
            if (i == j) continue;
            TrackSegment* seg_j = &data->track_segments[j];

            // Check if seg_j connects to seg_i's start point
            if ((seg_j->col1 == seg_i->col1 && seg_j->row1 == seg_i->row1) ||
                (seg_j->col2 == seg_i->col1 && seg_j->row2 == seg_i->row1)) {
                start_conns++;
            }
            // Check if seg_j connects to seg_i's end point
            if ((seg_j->col1 == seg_i->col2 && seg_j->row1 == seg_i->row2) ||
                (seg_j->col2 == seg_i->col2 && seg_j->row2 == seg_i->row2)) {
                end_conns++;
            }
        }

        // Allocate and fill connection arrays
        if (start_conns > 0) {
            seg_i->connections_start = (int*)malloc(start_conns * sizeof(int));
            int idx = 0;
            for (int j = 0; j < data->track_segment_count; j++) {
                if (i == j) continue;
                TrackSegment* seg_j = &data->track_segments[j];
                if ((seg_j->col1 == seg_i->col1 && seg_j->row1 == seg_i->row1) ||
                    (seg_j->col2 == seg_i->col1 && seg_j->row2 == seg_i->row1)) {
                    seg_i->connections_start[idx++] = j;
                }
            }
            seg_i->connections_start_count = start_conns;
        }

        if (end_conns > 0) {
            seg_i->connections_end = (int*)malloc(end_conns * sizeof(int));
            int idx = 0;
            for (int j = 0; j < data->track_segment_count; j++) {
                if (i == j) continue;
                TrackSegment* seg_j = &data->track_segments[j];
                if ((seg_j->col1 == seg_i->col2 && seg_j->row1 == seg_i->row2) ||
                    (seg_j->col2 == seg_i->col2 && seg_j->row2 == seg_i->row2)) {
                    seg_i->connections_end[idx++] = j;
                }
            }
            seg_i->connections_end_count = end_conns;
        }
    }
}
// }}}

// {{{ board_data_compute_track_intersections
void board_data_compute_track_intersections(BoardData* data) {
    if (!data) return;

    // Free existing intersections
    if (data->track_intersections) {
        for (int i = 0; i < data->track_intersection_count; i++) {
            TrackIntersection* inter = &data->track_intersections[i];
            if (inter->segment_indices) free(inter->segment_indices);
            if (inter->approach_paths) {
                for (int j = 0; j < inter->segment_count; j++) {
                    if (inter->approach_paths[j]) free(inter->approach_paths[j]);
                }
                free(inter->approach_paths);
            }
            if (inter->approach_path_counts) free(inter->approach_path_counts);
        }
        free(data->track_intersections);
        data->track_intersections = NULL;
        data->track_intersection_count = 0;
    }

    // First pass: count unique intersection points
    // An intersection is any point where 3+ segment endpoints meet
    // (2 endpoints = simple connection, not an intersection)

    // Collect all endpoints
    int endpoint_capacity = data->track_segment_count * 2;
    int* ep_cols = (int*)malloc(endpoint_capacity * sizeof(int));
    int* ep_rows = (int*)malloc(endpoint_capacity * sizeof(int));
    int* ep_counts = (int*)calloc(endpoint_capacity, sizeof(int));
    int ep_count = 0;

    if (!ep_cols || !ep_rows || !ep_counts) {
        if (ep_cols) free(ep_cols);
        if (ep_rows) free(ep_rows);
        if (ep_counts) free(ep_counts);
        return;
    }

    // Helper to find or add endpoint
    for (int i = 0; i < data->track_segment_count; i++) {
        TrackSegment* seg = &data->track_segments[i];

        // Process start point
        int found_start = -1;
        for (int j = 0; j < ep_count; j++) {
            if (ep_cols[j] == seg->col1 && ep_rows[j] == seg->row1) {
                found_start = j;
                break;
            }
        }
        if (found_start >= 0) {
            ep_counts[found_start]++;
        } else {
            ep_cols[ep_count] = seg->col1;
            ep_rows[ep_count] = seg->row1;
            ep_counts[ep_count] = 1;
            ep_count++;
        }

        // Process end point
        int found_end = -1;
        for (int j = 0; j < ep_count; j++) {
            if (ep_cols[j] == seg->col2 && ep_rows[j] == seg->row2) {
                found_end = j;
                break;
            }
        }
        if (found_end >= 0) {
            ep_counts[found_end]++;
        } else {
            ep_cols[ep_count] = seg->col2;
            ep_rows[ep_count] = seg->row2;
            ep_counts[ep_count] = 1;
            ep_count++;
        }
    }

    // Count intersections (points with 3+ segments)
    int intersection_count = 0;
    for (int i = 0; i < ep_count; i++) {
        if (ep_counts[i] >= 3) intersection_count++;
    }

    if (intersection_count == 0) {
        free(ep_cols);
        free(ep_rows);
        free(ep_counts);
        return;
    }

    // Allocate intersections
    data->track_intersections = (TrackIntersection*)calloc(intersection_count,
                                                            sizeof(TrackIntersection));
    data->track_intersection_count = intersection_count;

    // Fill intersection data
    int inter_idx = 0;
    for (int i = 0; i < ep_count; i++) {
        if (ep_counts[i] < 3) continue;

        TrackIntersection* inter = &data->track_intersections[inter_idx];
        inter->col = ep_cols[i];
        inter->row = ep_rows[i];
        inter->segment_count = ep_counts[i];
        inter->segment_indices = (int*)malloc(ep_counts[i] * sizeof(int));
        inter->approach_paths = (int**)calloc(ep_counts[i], sizeof(int*));
        inter->approach_path_counts = (int*)calloc(ep_counts[i], sizeof(int));

        // Find all segments at this point
        int seg_idx = 0;
        for (int j = 0; j < data->track_segment_count; j++) {
            TrackSegment* seg = &data->track_segments[j];
            if ((seg->col1 == ep_cols[i] && seg->row1 == ep_rows[i]) ||
                (seg->col2 == ep_cols[i] && seg->row2 == ep_rows[i])) {
                inter->segment_indices[seg_idx++] = j;
            }
        }

        // Compute approach paths:
        // When approaching from segment A, valid exits are all other segments
        for (int a = 0; a < inter->segment_count; a++) {
            int exit_count = inter->segment_count - 1;
            inter->approach_paths[a] = (int*)malloc(exit_count * sizeof(int));
            inter->approach_path_counts[a] = exit_count;

            int exit_idx = 0;
            for (int b = 0; b < inter->segment_count; b++) {
                if (a != b) {
                    inter->approach_paths[a][exit_idx++] = inter->segment_indices[b];
                }
            }
        }

        inter_idx++;
    }

    free(ep_cols);
    free(ep_rows);
    free(ep_counts);
}
// }}}

// =============================================================================
// Property Conversion
// =============================================================================

// {{{ property_to_float
float property_to_float(unsigned char value) {
    return (float)value / 255.0f;
}
// }}}

// {{{ float_to_property
unsigned char float_to_property(float value) {
    if (value < 0.0f) value = 0.0f;
    if (value > 1.0f) value = 1.0f;
    return (unsigned char)(value * 255.0f);
}
// }}}

// =============================================================================
// JSON Loading
// =============================================================================

// {{{ board_data_load_json
BoardData* board_data_load_json(const char* filename) {
    // Read file contents
    FILE* file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "ERROR: Cannot open board file: %s\n", filename);
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* json_string = (char*)malloc(length + 1);
    if (!json_string) {
        fprintf(stderr, "ERROR: Cannot allocate memory for JSON\n");
        fclose(file);
        return NULL;
    }

    size_t read_len = fread(json_string, 1, length, file);
    json_string[read_len] = '\0';
    fclose(file);

    // Parse JSON
    cJSON* root = cJSON_Parse(json_string);
    free(json_string);

    if (!root) {
        const char* error = cJSON_GetErrorPtr();
        fprintf(stderr, "ERROR: JSON parse error: %s\n", error ? error : "unknown");
        return NULL;
    }

    // Extract grid settings
    cJSON* grid = cJSON_GetObjectItem(root, "grid");
    if (!grid) {
        fprintf(stderr, "ERROR: Missing 'grid' in JSON\n");
        cJSON_Delete(root);
        return NULL;
    }

    cJSON* cols_json = cJSON_GetObjectItem(grid, "columns");
    cJSON* rows_json = cJSON_GetObjectItem(grid, "rows");

    int cols = cols_json ? cols_json->valueint : DEFAULT_GRID_COLS;
    int rows = rows_json ? rows_json->valueint : DEFAULT_GRID_ROWS;

    // Issue 838: Calculate cell_size from fixed board dimensions
    // Board dimensions are constant, cell size adapts to grid density
    // Use minimum of width/cols and height/rows to ensure square cells that fit
    int cell_width = (int)(BOARD_WIDTH / cols);
    int cell_height = (int)(BOARD_HEIGHT / rows);
    int cell_size = (cell_width < cell_height) ? cell_width : cell_height;

    // Create board data
    BoardData* data = board_data_create(cols, rows, cell_size);
    if (!data) {
        cJSON_Delete(root);
        return NULL;
    }

    // Extract name
    cJSON* name = cJSON_GetObjectItem(root, "name");
    if (name && cJSON_IsString(name)) {
        strncpy(data->name, name->valuestring, 63);
        data->name[63] = '\0';
    }

    // Extract version
    cJSON* version = cJSON_GetObjectItem(root, "version");
    if (version && cJSON_IsNumber(version)) {
        data->version = version->valueint;
    }

    // Extract in_progress flag (issue 1224)
    cJSON* in_progress = cJSON_GetObjectItem(root, "in_progress");
    if (in_progress && cJSON_IsBool(in_progress)) {
        data->in_progress = cJSON_IsTrue(in_progress) ? 1 : 0;
    }

    // Parse objects array
    cJSON* objects = cJSON_GetObjectItem(root, "objects");
    if (objects && cJSON_IsArray(objects)) {
        cJSON* obj_json;
        cJSON_ArrayForEach(obj_json, objects) {
            cJSON* type_json = cJSON_GetObjectItem(obj_json, "type");
            if (!type_json || !cJSON_IsString(type_json)) continue;

            const char* type_str = type_json->valuestring;

            cJSON* col_json = cJSON_GetObjectItem(obj_json, "col");
            cJSON* row_json = cJSON_GetObjectItem(obj_json, "row");
            int col = col_json ? col_json->valueint : 0;
            int row = row_json ? row_json->valueint : 0;

            // Get RGB properties (use defaults if not specified)
            cJSON* rest_json = cJSON_GetObjectItem(obj_json, "restitution");
            cJSON* fric_json = cJSON_GetObjectItem(obj_json, "friction");
            cJSON* bonus_json = cJSON_GetObjectItem(obj_json, "point_bonus");

            unsigned char restitution = rest_json ? (unsigned char)rest_json->valueint : DEFAULT_RESTITUTION;
            unsigned char friction = fric_json ? (unsigned char)fric_json->valueint : DEFAULT_FRICTION;
            unsigned char point_bonus = bonus_json ? (unsigned char)bonus_json->valueint : DEFAULT_POINT_BONUS;

            if (strcmp(type_str, "peg") == 0) {
                board_data_add_peg_ex(data, col, row, restitution, friction, point_bonus);
            } else if (strcmp(type_str, "line") == 0) {
                cJSON* end_col_json = cJSON_GetObjectItem(obj_json, "end_col");
                cJSON* end_row_json = cJSON_GetObjectItem(obj_json, "end_row");
                cJSON* thickness_json = cJSON_GetObjectItem(obj_json, "thickness");

                int end_col = end_col_json ? end_col_json->valueint : col;
                int end_row = end_row_json ? end_row_json->valueint : row;
                float thickness = thickness_json ? (float)thickness_json->valuedouble : 20.0f;

                board_data_add_line_ex(data, col, row, end_col, end_row, thickness,
                                       restitution, friction, point_bonus);
            }
        }
    }

    // Parse zones array
    cJSON* zones = cJSON_GetObjectItem(root, "zones");
    if (zones && cJSON_IsArray(zones)) {
        cJSON* zone_json;
        cJSON_ArrayForEach(zone_json, zones) {
            cJSON* type_json = cJSON_GetObjectItem(zone_json, "type");
            if (!type_json || !cJSON_IsString(type_json)) continue;

            const char* type_str = type_json->valuestring;

            cJSON* col_json = cJSON_GetObjectItem(zone_json, "col");
            cJSON* row_json = cJSON_GetObjectItem(zone_json, "row");
            cJSON* width_json = cJSON_GetObjectItem(zone_json, "width");
            cJSON* height_json = cJSON_GetObjectItem(zone_json, "height");

            int col = col_json ? col_json->valueint : 0;
            int row = row_json ? row_json->valueint : 0;
            int width = width_json ? width_json->valueint : 1;
            int height = height_json ? height_json->valueint : 1;

            if (strcmp(type_str, "score") == 0) {
                cJSON* points_json = cJSON_GetObjectItem(zone_json, "points");
                cJSON* mult_json = cJSON_GetObjectItem(zone_json, "multiplier");

                int points = points_json ? points_json->valueint : 100;
                int multiplier = mult_json ? mult_json->valueint : 1;

                board_data_add_score_zone(data, col, row, width, height, points, multiplier);
            } else if (strcmp(type_str, "portal") == 0) {
                cJSON* channel_json = cJSON_GetObjectItem(zone_json, "channel");
                cJSON* dir_json = cJSON_GetObjectItem(zone_json, "direction");

                int channel = channel_json ? channel_json->valueint : 1;
                PortalDirection dir = PORTAL_ENTRY;
                if (dir_json && cJSON_IsString(dir_json)) {
                    if (strcmp(dir_json->valuestring, "exit") == 0) {
                        dir = PORTAL_EXIT;
                    }
                }

                board_data_add_portal(data, col, row, width, height, channel, dir);
            }
        }
    }

    // Parse rotors array (issue 901a)
    cJSON* rotors = cJSON_GetObjectItem(root, "rotors");
    if (rotors && cJSON_IsArray(rotors)) {
        cJSON* rotor_json;
        cJSON_ArrayForEach(rotor_json, rotors) {
            cJSON* col_json = cJSON_GetObjectItem(rotor_json, "col");
            cJSON* row_json = cJSON_GetObjectItem(rotor_json, "row");
            cJSON* speed_json = cJSON_GetObjectItem(rotor_json, "speed");
            cJSON* dir_json = cJSON_GetObjectItem(rotor_json, "direction");

            int col = col_json ? col_json->valueint : 0;
            int row = row_json ? row_json->valueint : 0;
            float speed = speed_json ? (float)speed_json->valuedouble : 1.0f;

            // Direction "ccw" makes speed negative
            if (dir_json && cJSON_IsString(dir_json)) {
                if (strcmp(dir_json->valuestring, "ccw") == 0) {
                    speed = -fabsf(speed);
                }
            }

            int rotor_idx = board_data_add_rotor(data, col, row, speed);

            // Parse connections array
            cJSON* connections = cJSON_GetObjectItem(rotor_json, "connections");
            if (connections && cJSON_IsArray(connections) && rotor_idx >= 0) {
                cJSON* conn_json;
                cJSON_ArrayForEach(conn_json, connections) {
                    if (cJSON_IsNumber(conn_json)) {
                        // Simple format: just object index (auto-detect relative position)
                        int obj_idx = conn_json->valueint;
                        if (obj_idx >= 0 && obj_idx < data->object_count) {
                            // Calculate relative position from object and rotor coords
                            BoardObject* obj = &data->objects[obj_idx];
                            int dx = obj->col - col;
                            int dy = obj->row - row;
                            float angle = atan2f((float)dy, (float)dx);
                            float dist = sqrtf((float)(dx * dx + dy * dy));
                            board_data_rotor_add_connection(data, rotor_idx, obj_idx, angle, dist);
                        }
                    }
                }
            }
        }
    }

    // Parse tracks object (issue 902a)
    cJSON* tracks = cJSON_GetObjectItem(root, "tracks");
    if (tracks && cJSON_IsObject(tracks)) {
        // Parse segments array
        cJSON* segments = cJSON_GetObjectItem(tracks, "segments");
        if (segments && cJSON_IsArray(segments)) {
            cJSON* seg_json;
            cJSON_ArrayForEach(seg_json, segments) {
                cJSON* start = cJSON_GetObjectItem(seg_json, "start");
                cJSON* end = cJSON_GetObjectItem(seg_json, "end");

                if (start && end && cJSON_IsArray(start) && cJSON_IsArray(end)) {
                    int col1 = cJSON_GetArrayItem(start, 0)->valueint;
                    int row1 = cJSON_GetArrayItem(start, 1)->valueint;
                    int col2 = cJSON_GetArrayItem(end, 0)->valueint;
                    int row2 = cJSON_GetArrayItem(end, 1)->valueint;

                    board_data_add_track_segment(data, col1, row1, col2, row2);
                }
            }
        }

        // Parse movers array
        cJSON* movers = cJSON_GetObjectItem(tracks, "movers");
        if (movers && cJSON_IsArray(movers)) {
            cJSON* mover_json;
            cJSON_ArrayForEach(mover_json, movers) {
                cJSON* segment_json = cJSON_GetObjectItem(mover_json, "segment");
                cJSON* position_json = cJSON_GetObjectItem(mover_json, "position");
                cJSON* speed_json = cJSON_GetObjectItem(mover_json, "speed");

                int segment = segment_json ? segment_json->valueint : 0;
                float position = position_json ? (float)position_json->valuedouble : 0.0f;
                float speed = speed_json ? (float)speed_json->valuedouble : 50.0f;

                int mover_idx = board_data_add_track_mover(data, segment, position, speed);

                // Parse payload array
                cJSON* payload = cJSON_GetObjectItem(mover_json, "payload");
                if (payload && cJSON_IsArray(payload) && mover_idx >= 0) {
                    cJSON* payload_json;
                    cJSON_ArrayForEach(payload_json, payload) {
                        if (cJSON_IsNumber(payload_json)) {
                            // Simple format: just object index (offset computed from positions)
                            int obj_idx = payload_json->valueint;
                            if (obj_idx >= 0 && obj_idx < data->object_count) {
                                // Compute offset from mover position to object
                                // For now, use 0,0 offset - proper offsets computed at runtime
                                board_data_track_mover_add_payload(data, mover_idx, obj_idx, 0.0f, 0.0f);
                            }
                        }
                    }
                }
            }
        }

        // Compute track connectivity and intersections after loading
        board_data_compute_track_connectivity(data);
        board_data_compute_track_intersections(data);
    }

    cJSON_Delete(root);
    printf("Loaded board: %s (%d objects, %d zones, %d rotors, %d track segments)\n",
           data->name, data->object_count, data->zone_count,
           data->rotor_count, data->track_segment_count);

    return data;
}
// }}}

// =============================================================================
// JSON Saving
// =============================================================================

// {{{ board_data_to_json_string
char* board_data_to_json_string(BoardData* data) {
    if (!data) return NULL;

    cJSON* root = cJSON_CreateObject();

    // Version and name
    cJSON_AddNumberToObject(root, "version", data->version);
    cJSON_AddStringToObject(root, "name", data->name);

    // In-progress flag (issue 1224) - only write if true
    if (data->in_progress) {
        cJSON_AddBoolToObject(root, "in_progress", 1);
    }

    // Grid settings (issue 838: only store columns and rows)
    // Board dimensions and cell_size are calculated at load time from constants
    cJSON* grid = cJSON_CreateObject();
    cJSON_AddNumberToObject(grid, "columns", data->grid_cols);
    cJSON_AddNumberToObject(grid, "rows", data->grid_rows);
    cJSON_AddItemToObject(root, "grid", grid);

    // Note: board dimensions section removed (issue 838)
    // Board size is fixed - all boards use BOARD_WIDTH x BOARD_HEIGHT

    // Objects array
    cJSON* objects = cJSON_CreateArray();
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        cJSON* obj_json = cJSON_CreateObject();

        if (obj->type == OBJECT_PEG) {
            cJSON_AddStringToObject(obj_json, "type", "peg");
            cJSON_AddNumberToObject(obj_json, "col", obj->col);
            cJSON_AddNumberToObject(obj_json, "row", obj->row);
        } else if (obj->type == OBJECT_LINE) {
            cJSON_AddStringToObject(obj_json, "type", "line");
            cJSON_AddNumberToObject(obj_json, "col", obj->col);
            cJSON_AddNumberToObject(obj_json, "row", obj->row);
            cJSON_AddNumberToObject(obj_json, "end_col", obj->end_col);
            cJSON_AddNumberToObject(obj_json, "end_row", obj->end_row);
            cJSON_AddNumberToObject(obj_json, "thickness", obj->thickness);
        }

        // RGB properties (only if non-default)
        if (obj->restitution != DEFAULT_RESTITUTION) {
            cJSON_AddNumberToObject(obj_json, "restitution", obj->restitution);
        }
        if (obj->friction != DEFAULT_FRICTION) {
            cJSON_AddNumberToObject(obj_json, "friction", obj->friction);
        }
        if (obj->point_bonus != DEFAULT_POINT_BONUS) {
            cJSON_AddNumberToObject(obj_json, "point_bonus", obj->point_bonus);
        }

        cJSON_AddItemToArray(objects, obj_json);
    }
    cJSON_AddItemToObject(root, "objects", objects);

    // Zones array
    cJSON* zones = cJSON_CreateArray();
    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* zone = &data->zones[i];
        cJSON* zone_json = cJSON_CreateObject();

        if (zone->type == ZONE_SCORE) {
            cJSON_AddStringToObject(zone_json, "type", "score");
            cJSON_AddNumberToObject(zone_json, "col", zone->col);
            cJSON_AddNumberToObject(zone_json, "row", zone->row);
            cJSON_AddNumberToObject(zone_json, "width", zone->width);
            cJSON_AddNumberToObject(zone_json, "height", zone->height);
            cJSON_AddNumberToObject(zone_json, "points", zone->points);
            cJSON_AddNumberToObject(zone_json, "multiplier", zone->multiplier);
        } else if (zone->type == ZONE_PORTAL) {
            cJSON_AddStringToObject(zone_json, "type", "portal");
            cJSON_AddNumberToObject(zone_json, "col", zone->col);
            cJSON_AddNumberToObject(zone_json, "row", zone->row);
            cJSON_AddNumberToObject(zone_json, "width", zone->width);
            cJSON_AddNumberToObject(zone_json, "height", zone->height);
            cJSON_AddNumberToObject(zone_json, "channel", zone->channel);
            cJSON_AddStringToObject(zone_json, "direction",
                zone->direction == PORTAL_ENTRY ? "entry" : "exit");
        }

        cJSON_AddItemToArray(zones, zone_json);
    }
    cJSON_AddItemToObject(root, "zones", zones);

    // Rotors array (issue 901a)
    if (data->rotor_count > 0) {
        cJSON* rotors = cJSON_CreateArray();
        for (int i = 0; i < data->rotor_count; i++) {
            Rotor* rotor = &data->rotors[i];
            cJSON* rotor_json = cJSON_CreateObject();

            cJSON_AddNumberToObject(rotor_json, "col", rotor->col);
            cJSON_AddNumberToObject(rotor_json, "row", rotor->row);
            cJSON_AddNumberToObject(rotor_json, "speed", fabsf(rotor->rotation_speed));
            cJSON_AddStringToObject(rotor_json, "direction",
                rotor->rotation_speed >= 0 ? "cw" : "ccw");

            // Serialize connections as simple object indices
            if (rotor->connection_count > 0) {
                cJSON* connections = cJSON_CreateArray();
                for (int j = 0; j < rotor->connection_count; j++) {
                    cJSON_AddItemToArray(connections,
                        cJSON_CreateNumber(rotor->connections[j].object_index));
                }
                cJSON_AddItemToObject(rotor_json, "connections", connections);
            }

            cJSON_AddItemToArray(rotors, rotor_json);
        }
        cJSON_AddItemToObject(root, "rotors", rotors);
    }

    // Tracks object (issue 902a)
    if (data->track_segment_count > 0 || data->track_mover_count > 0) {
        cJSON* tracks = cJSON_CreateObject();

        // Serialize segments
        if (data->track_segment_count > 0) {
            cJSON* segments = cJSON_CreateArray();
            for (int i = 0; i < data->track_segment_count; i++) {
                TrackSegment* seg = &data->track_segments[i];
                cJSON* seg_json = cJSON_CreateObject();

                cJSON* start = cJSON_CreateArray();
                cJSON_AddItemToArray(start, cJSON_CreateNumber(seg->col1));
                cJSON_AddItemToArray(start, cJSON_CreateNumber(seg->row1));
                cJSON_AddItemToObject(seg_json, "start", start);

                cJSON* end = cJSON_CreateArray();
                cJSON_AddItemToArray(end, cJSON_CreateNumber(seg->col2));
                cJSON_AddItemToArray(end, cJSON_CreateNumber(seg->row2));
                cJSON_AddItemToObject(seg_json, "end", end);

                cJSON_AddItemToArray(segments, seg_json);
            }
            cJSON_AddItemToObject(tracks, "segments", segments);
        }

        // Serialize movers
        if (data->track_mover_count > 0) {
            cJSON* movers = cJSON_CreateArray();
            for (int i = 0; i < data->track_mover_count; i++) {
                TrackMover* mover = &data->track_movers[i];
                cJSON* mover_json = cJSON_CreateObject();

                cJSON_AddNumberToObject(mover_json, "segment", mover->current_segment);
                cJSON_AddNumberToObject(mover_json, "position", mover->position_on_segment);
                cJSON_AddNumberToObject(mover_json, "speed", mover->speed);

                if (mover->payload_count > 0) {
                    cJSON* payload = cJSON_CreateArray();
                    for (int j = 0; j < mover->payload_count; j++) {
                        cJSON_AddItemToArray(payload,
                            cJSON_CreateNumber(mover->payload_indices[j]));
                    }
                    cJSON_AddItemToObject(mover_json, "payload", payload);
                }

                cJSON_AddItemToArray(movers, mover_json);
            }
            cJSON_AddItemToObject(tracks, "movers", movers);
        }

        cJSON_AddItemToObject(root, "tracks", tracks);
    }

    // Generate formatted JSON string
    char* json_string = cJSON_Print(root);
    cJSON_Delete(root);

    return json_string;
}
// }}}

// {{{ board_data_save_json
int board_data_save_json(BoardData* data, const char* filename) {
    char* json_string = board_data_to_json_string(data);
    if (!json_string) {
        fprintf(stderr, "ERROR: Failed to serialize board data\n");
        return 0;
    }

    FILE* file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "ERROR: Cannot open file for writing: %s\n", filename);
        free(json_string);
        return 0;
    }

    fputs(json_string, file);
    fclose(file);
    free(json_string);

    printf("Board saved to: %s\n", filename);
    return 1;
}
// }}}

// =============================================================================
// Board Loading (BoardData -> Game World)
// =============================================================================

#include "004-world.h"
#include "022-grid.h"

// {{{ rgb_to_color
// Converts RGB properties to a visual Color.
// R=restitution maps to red intensity, G=friction to green, B=point_bonus to blue.
static Color rgb_to_color(unsigned char r, unsigned char g, unsigned char b) {
    // Base steel color, tinted by properties
    // Higher restitution = more red/orange (bouncy)
    // Higher friction = more green (grippy)
    // Higher point_bonus = more blue (valuable)
    int red = 140 + (r * 115 / 255);    // 140-255
    int green = 140 + (g * 60 / 255);   // 140-200
    int blue = 140 + (b * 115 / 255);   // 140-255

    return (Color){(unsigned char)red, (unsigned char)green, (unsigned char)blue, 255};
}
// }}}

// {{{ board_data_apply_pegs_to_world
void board_data_apply_pegs_to_world(BoardData* data, struct World* world,
                                    struct Grid* grid) {
    if (!data || !world || !grid) return;

    // Count pegs in BoardData
    int peg_count = 0;
    for (int i = 0; i < data->object_count; i++) {
        if (data->objects[i].type == OBJECT_PEG) {
            peg_count++;
        }
    }

    if (peg_count == 0) {
        // No pegs to add - clear existing
        if (world->pegs) {
            free(world->pegs);
            world->pegs = NULL;
        }
        world->peg_count = 0;
        return;
    }

    // Free existing pegs
    if (world->pegs) {
        free(world->pegs);
    }

    // Allocate new peg array
    world->pegs = (Peg*)malloc(sizeof(Peg) * peg_count);
    if (!world->pegs) {
        fprintf(stderr, "ERROR: Failed to allocate pegs from board data\n");
        world->peg_count = 0;
        return;
    }
    world->peg_count = peg_count;

    // Convert BoardObjects to Pegs
    int peg_idx = 0;
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        if (obj->type != OBJECT_PEG) continue;

        Peg* peg = &world->pegs[peg_idx];

        // Convert grid position to pixel position
        peg->x = grid_to_pixel_x(grid, obj->col, obj->row);
        peg->y = grid_to_pixel_y(grid, obj->col, obj->row);
        peg->radius = PEG_RADIUS;

        // Convert RGB properties
        peg->restitution = property_to_float(obj->restitution);
        peg->friction = property_to_float(obj->friction);
        peg->point_bonus = obj->point_bonus;

        // Generate color from RGB properties
        peg->color = rgb_to_color(obj->restitution, obj->friction, obj->point_bonus);

        peg_idx++;
    }

    printf("Applied %d pegs from board data\n", peg_count);
}
// }}}

// {{{ board_data_apply_zones_to_world
void board_data_apply_zones_to_world(BoardData* data, struct World* world,
                                     struct Grid* grid) {
    if (!data || !world || !grid) return;

    // Count score zones in BoardData (portals handled separately)
    int zone_count = 0;
    for (int i = 0; i < data->zone_count; i++) {
        if (data->zones[i].type == ZONE_SCORE) {
            zone_count++;
        }
    }

    if (zone_count == 0) {
        // No zones to add - clear existing
        if (world->zones) {
            free(world->zones);
            world->zones = NULL;
        }
        world->zone_count = 0;
        return;
    }

    // Free existing zones
    if (world->zones) {
        free(world->zones);
    }

    // Allocate new zone array
    world->zones = (ScoreZone*)malloc(sizeof(ScoreZone) * zone_count);
    if (!world->zones) {
        fprintf(stderr, "ERROR: Failed to allocate zones from board data\n");
        world->zone_count = 0;
        return;
    }
    world->zone_count = zone_count;

    // Convert BoardZones to ScoreZones
    int zone_idx = 0;
    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* bz = &data->zones[i];
        if (bz->type != ZONE_SCORE) continue;

        ScoreZone* sz = &world->zones[zone_idx];

        // Convert grid bounds to pixel bounds
        // Zone starts at top-left of grid cell
        float cell_x = grid->origin_x + bz->col * grid->cell_size;
        float cell_y = grid->origin_y + bz->row * grid->cell_size;

        sz->x_min = cell_x;
        sz->x_max = cell_x + bz->width * grid->cell_size;
        sz->y_min = cell_y;
        sz->y_max = cell_y + bz->height * grid->cell_size;
        sz->points = bz->points * bz->multiplier;

        zone_idx++;
    }

    printf("Applied %d score zones from board data\n", zone_count);
}
// }}}

// {{{ board_data_apply_to_world
void board_data_apply_to_world(BoardData* data, struct World* world,
                               struct Grid* grid) {
    if (!data || !world || !grid) return;

    // Apply pegs
    board_data_apply_pegs_to_world(data, world, grid);

    // Apply score zones
    board_data_apply_zones_to_world(data, world, grid);

    // Note: Lines (ramps) and portals require additional systems
    // and will be handled by separate issues (1110, 1112)

    printf("Board data applied to world: %s\n", data->name);
}
// }}}

// =============================================================================
// Directory Scanning
// =============================================================================

// {{{ board_scan_directory
BoardFileList* board_scan_directory(const char* directory) {
    BoardFileList* list = (BoardFileList*)malloc(sizeof(BoardFileList));
    if (!list) return NULL;

    list->count = 0;
    list->capacity = 16;
    list->filenames = (char**)malloc(sizeof(char*) * list->capacity);
    if (!list->filenames) {
        free(list);
        return NULL;
    }

    DIR* dir = opendir(directory);
    if (!dir) {
        fprintf(stderr, "WARNING: Cannot open directory: %s\n", directory);
        return list;  // Return empty list
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        // Check for .json extension
        const char* name = entry->d_name;
        size_t len = strlen(name);
        if (len > 5 && strcmp(name + len - 5, ".json") == 0) {
            // Grow array if needed
            if (list->count >= list->capacity) {
                list->capacity *= 2;
                list->filenames = (char**)realloc(list->filenames,
                                                   sizeof(char*) * list->capacity);
            }

            // Store full path (directory/filename)
            size_t dir_len = strlen(directory);
            size_t path_len = dir_len + 1 + len + 1;  // dir + '/' + name + '\0'
            char* full_path = (char*)malloc(path_len);
            if (full_path) {
                snprintf(full_path, path_len, "%s/%s", directory, name);
                list->filenames[list->count] = full_path;
                list->count++;
            }
        }
    }

    closedir(dir);
    printf("Found %d board files in %s\n", list->count, directory);
    return list;
}
// }}}

// {{{ board_file_list_destroy
void board_file_list_destroy(BoardFileList* list) {
    if (!list) return;

    for (int i = 0; i < list->count; i++) {
        free(list->filenames[i]);
    }
    free(list->filenames);
    free(list);
}
// }}}

// =============================================================================
// Validation
// =============================================================================

// {{{ board_data_validate_portals
int board_data_validate_portals(BoardData* data, int* orphan_channel) {
    if (!data) {
        if (orphan_channel) *orphan_channel = -1;
        return 1;  // No data = valid
    }

    // Count entries and exits per channel
    // Using 17 to account for channels 1-16 (index 0 unused)
    int entry_count[17] = {0};
    int exit_count[17] = {0};

    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* zone = &data->zones[i];
        if (zone->type != ZONE_PORTAL) continue;

        int ch = zone->channel;
        if (ch < 1 || ch > 16) continue;  // Invalid channel, skip

        if (zone->direction == PORTAL_ENTRY) {
            entry_count[ch]++;
        } else {
            exit_count[ch]++;
        }
    }

    // Check for orphan channels (entries without exits)
    for (int ch = 1; ch <= 16; ch++) {
        if (entry_count[ch] > 0 && exit_count[ch] == 0) {
            if (orphan_channel) *orphan_channel = ch;
            return 0;  // Invalid - orphan channel found
        }
    }

    if (orphan_channel) *orphan_channel = -1;
    return 1;  // Valid
}
// }}}
