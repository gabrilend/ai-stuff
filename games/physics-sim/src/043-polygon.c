// src/043-polygon.c
// Closed polygon detection and fill implementation
// Handles graph building, cycle detection, triangulation, and collision

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "042-polygon.h"
#include "020-board-data.h"

// =============================================================================
// Internal Constants
// =============================================================================

#define INITIAL_VERTEX_CAPACITY 64
#define INITIAL_SEGMENT_CAPACITY 64
#define EPSILON 0.0001f

// =============================================================================
// Internal Helper Prototypes
// =============================================================================

static void line_graph_destroy(LineGraph* graph);
static LineGraph* line_graph_create(void);
static int line_graph_add_vertex(LineGraph* graph, float x, float y);
static int line_graph_find_vertex(LineGraph* graph, float x, float y);
static int line_graph_add_segment(LineGraph* graph, int va, int vb, int source_line, int is_guard_rail);
static void vertex_add_segment(PolyVertex* vertex, int segment_index);

static void find_all_intersections(LineGraph* graph, BoardData* board,
                                   float cell_width, float cell_height,
                                   float board_width, float board_height);
static void detect_cycles(PolygonManager* manager, LineGraph* graph);
static int is_ear(Vector2* verts, int n, int prev, int curr, int next);
static float cross_2d(Vector2 a, Vector2 b, Vector2 c);

// =============================================================================
// PolygonManager Lifecycle
// =============================================================================

// {{{ polygon_manager_create
PolygonManager* polygon_manager_create(float board_width, float board_height) {
    PolygonManager* manager = (PolygonManager*)calloc(1, sizeof(PolygonManager));
    if (!manager) {
        fprintf(stderr, "ERROR: Failed to allocate PolygonManager\n");
        return NULL;
    }

    manager->polygon_capacity = 16;
    manager->polygons = (Polygon*)calloc(manager->polygon_capacity, sizeof(Polygon));
    if (!manager->polygons) {
        fprintf(stderr, "ERROR: Failed to allocate polygon array\n");
        free(manager);
        return NULL;
    }
    manager->polygon_count = 0;

    manager->graph = NULL;
    manager->board_width = board_width;
    manager->board_height = board_height;

    return manager;
}
// }}}

// {{{ polygon_manager_destroy
void polygon_manager_destroy(PolygonManager* manager) {
    if (!manager) return;

    if (manager->polygons) {
        free(manager->polygons);
    }

    if (manager->graph) {
        line_graph_destroy(manager->graph);
    }

    free(manager);
}
// }}}

// {{{ polygon_manager_clear
void polygon_manager_clear(PolygonManager* manager) {
    if (!manager) return;

    manager->polygon_count = 0;

    if (manager->graph) {
        line_graph_destroy(manager->graph);
        manager->graph = NULL;
    }
}
// }}}

// =============================================================================
// LineGraph Management
// =============================================================================

// {{{ line_graph_create
static LineGraph* line_graph_create(void) {
    LineGraph* graph = (LineGraph*)calloc(1, sizeof(LineGraph));
    if (!graph) return NULL;

    graph->vertex_capacity = INITIAL_VERTEX_CAPACITY;
    graph->vertices = (PolyVertex*)calloc(graph->vertex_capacity, sizeof(PolyVertex));
    if (!graph->vertices) {
        free(graph);
        return NULL;
    }

    graph->segment_capacity = INITIAL_SEGMENT_CAPACITY;
    graph->segments = (PolySegment*)calloc(graph->segment_capacity, sizeof(PolySegment));
    if (!graph->segments) {
        free(graph->vertices);
        free(graph);
        return NULL;
    }

    return graph;
}
// }}}

// {{{ line_graph_destroy
static void line_graph_destroy(LineGraph* graph) {
    if (!graph) return;

    if (graph->vertices) {
        for (int i = 0; i < graph->vertex_count; i++) {
            if (graph->vertices[i].segment_indices) {
                free(graph->vertices[i].segment_indices);
            }
        }
        free(graph->vertices);
    }

    if (graph->segments) {
        free(graph->segments);
    }

    free(graph);
}
// }}}

// {{{ line_graph_find_vertex
// Finds an existing vertex within merge threshold, or returns -1.
static int line_graph_find_vertex(LineGraph* graph, float x, float y) {
    float threshold_sq = VERTEX_MERGE_THRESHOLD * VERTEX_MERGE_THRESHOLD;

    for (int i = 0; i < graph->vertex_count; i++) {
        float dx = graph->vertices[i].x - x;
        float dy = graph->vertices[i].y - y;
        if (dx * dx + dy * dy < threshold_sq) {
            return i;
        }
    }

    return -1;
}
// }}}

// {{{ line_graph_add_vertex
// Adds a new vertex or returns existing if within merge threshold.
static int line_graph_add_vertex(LineGraph* graph, float x, float y) {
    // Check for existing vertex
    int existing = line_graph_find_vertex(graph, x, y);
    if (existing >= 0) {
        return existing;
    }

    // Grow array if needed
    if (graph->vertex_count >= graph->vertex_capacity) {
        int new_cap = graph->vertex_capacity * 2;
        PolyVertex* new_verts = (PolyVertex*)realloc(graph->vertices,
                                                      new_cap * sizeof(PolyVertex));
        if (!new_verts) return -1;
        graph->vertices = new_verts;
        graph->vertex_capacity = new_cap;
    }

    // Add new vertex
    int idx = graph->vertex_count;
    PolyVertex* v = &graph->vertices[idx];
    v->x = x;
    v->y = y;
    v->segment_indices = NULL;
    v->segment_count = 0;
    v->segment_capacity = 0;

    graph->vertex_count++;
    return idx;
}
// }}}

// {{{ vertex_add_segment
static void vertex_add_segment(PolyVertex* vertex, int segment_index) {
    // Grow if needed
    if (vertex->segment_count >= vertex->segment_capacity) {
        int new_cap = vertex->segment_capacity == 0 ? 4 : vertex->segment_capacity * 2;
        int* new_segs = (int*)realloc(vertex->segment_indices, new_cap * sizeof(int));
        if (!new_segs) return;
        vertex->segment_indices = new_segs;
        vertex->segment_capacity = new_cap;
    }

    vertex->segment_indices[vertex->segment_count++] = segment_index;
}
// }}}

// {{{ line_graph_add_segment
static int line_graph_add_segment(LineGraph* graph, int va, int vb, int source_line, int is_guard_rail) {
    // Don't add degenerate segments
    if (va == vb) return -1;

    // Grow array if needed
    if (graph->segment_count >= graph->segment_capacity) {
        int new_cap = graph->segment_capacity * 2;
        PolySegment* new_segs = (PolySegment*)realloc(graph->segments,
                                                       new_cap * sizeof(PolySegment));
        if (!new_segs) return -1;
        graph->segments = new_segs;
        graph->segment_capacity = new_cap;
    }

    int idx = graph->segment_count;
    PolySegment* seg = &graph->segments[idx];
    seg->vertex_a = va;
    seg->vertex_b = vb;
    seg->source_line = source_line;
    seg->is_guard_rail = is_guard_rail;

    // Update vertex connectivity
    vertex_add_segment(&graph->vertices[va], idx);
    vertex_add_segment(&graph->vertices[vb], idx);

    graph->segment_count++;
    return idx;
}
// }}}

// =============================================================================
// Line-Line Intersection
// =============================================================================

// {{{ line_intersection
int line_intersection(Vector2 a1, Vector2 a2, Vector2 b1, Vector2 b2,
                      Vector2* out_point) {
    float d = (a1.x - a2.x) * (b1.y - b2.y) - (a1.y - a2.y) * (b1.x - b2.x);

    // Parallel lines
    if (fabsf(d) < EPSILON) {
        return 0;
    }

    float t = ((a1.x - b1.x) * (b1.y - b2.y) - (a1.y - b1.y) * (b1.x - b2.x)) / d;
    float u = -((a1.x - a2.x) * (a1.y - b1.y) - (a1.y - a2.y) * (a1.x - b1.x)) / d;

    // Check if intersection is within both segments
    // Use small epsilon to avoid endpoint intersections being double-counted
    if (t > EPSILON && t < (1.0f - EPSILON) && u > EPSILON && u < (1.0f - EPSILON)) {
        if (out_point) {
            out_point->x = a1.x + t * (a2.x - a1.x);
            out_point->y = a1.y + t * (a2.y - a1.y);
        }
        return 1;
    }

    return 0;
}
// }}}

// =============================================================================
// Graph Building
// =============================================================================

// {{{ find_all_intersections
// Builds the line graph from BoardData lines, finding all intersections
// and splitting lines at intersection points.
// Issue 1003: Takes cell_width and cell_height for rectangular cell support
static void find_all_intersections(LineGraph* graph, BoardData* board,
                                   float cell_width, float cell_height,
                                   float board_width, float board_height) {
    if (!graph || !board) return;

    // Temporary storage for line endpoints in pixel coords
    typedef struct {
        Vector2 start;
        Vector2 end;
        int board_index;
    } LineInfo;

    int line_count = 0;
    for (int i = 0; i < board->object_count; i++) {
        if (board->objects[i].type == OBJECT_LINE) {
            line_count++;
        }
    }

    if (line_count == 0) return;

    LineInfo* lines = (LineInfo*)malloc((line_count + 3) * sizeof(LineInfo));
    if (!lines) return;

    // Collect board lines
    // Use same coordinate system as grid_to_pixel: no half-cell offset (issue 1001b)
    // Previously added cell_size/2 which caused polygon fills to be offset from lines
    // Issue 1003: Use cell_width for X, cell_height for Y
    int li = 0;
    for (int i = 0; i < board->object_count; i++) {
        BoardObject* obj = &board->objects[i];
        if (obj->type != OBJECT_LINE) continue;

        lines[li].start.x = obj->col * cell_width;
        lines[li].start.y = obj->row * cell_height;
        lines[li].end.x = obj->end_col * cell_width;
        lines[li].end.y = obj->end_row * cell_height;
        lines[li].board_index = i;
        li++;
    }

    // Add guard rails as virtual lines (issue 837 design: guard rails count as lines)
    // Left wall
    lines[li].start = (Vector2){0, 0};
    lines[li].end = (Vector2){0, board_height};
    lines[li].board_index = -1;  // Guard rail marker
    li++;

    // Right wall
    lines[li].start = (Vector2){board_width, 0};
    lines[li].end = (Vector2){board_width, board_height};
    lines[li].board_index = -2;
    li++;

    // Bottom wall
    lines[li].start = (Vector2){0, board_height};
    lines[li].end = (Vector2){board_width, board_height};
    lines[li].board_index = -3;
    li++;

    int total_lines = li;

    // Find all pairwise intersections
    typedef struct {
        int line_a;
        int line_b;
        Vector2 point;
    } Intersection;

    Intersection* intersections = (Intersection*)malloc(MAX_LINE_INTERSECTIONS * sizeof(Intersection));
    int intersection_count = 0;

    for (int i = 0; i < total_lines && intersection_count < MAX_LINE_INTERSECTIONS; i++) {
        for (int j = i + 1; j < total_lines && intersection_count < MAX_LINE_INTERSECTIONS; j++) {
            Vector2 point;
            if (line_intersection(lines[i].start, lines[i].end,
                                  lines[j].start, lines[j].end, &point)) {
                intersections[intersection_count].line_a = i;
                intersections[intersection_count].line_b = j;
                intersections[intersection_count].point = point;
                intersection_count++;
            }
        }
    }

    // For each line, collect all split points (endpoints + intersections)
    // Then create segments between consecutive points
    for (int i = 0; i < total_lines; i++) {
        // Collect points on this line
        Vector2 points[MAX_LINE_INTERSECTIONS + 2];
        int point_count = 0;

        // Add endpoints
        points[point_count++] = lines[i].start;
        points[point_count++] = lines[i].end;

        // Add intersection points on this line
        for (int j = 0; j < intersection_count; j++) {
            if (intersections[j].line_a == i || intersections[j].line_b == i) {
                points[point_count++] = intersections[j].point;
            }
        }

        // Sort points by parameter along line
        // Calculate t for each point: t = distance from start / total length
        float dx = lines[i].end.x - lines[i].start.x;
        float dy = lines[i].end.y - lines[i].start.y;
        float length_sq = dx * dx + dy * dy;

        if (length_sq < EPSILON) continue;  // Degenerate line

        // Simple bubble sort by t parameter
        for (int a = 0; a < point_count - 1; a++) {
            for (int b = a + 1; b < point_count; b++) {
                float ta = (points[a].x - lines[i].start.x) * dx +
                           (points[a].y - lines[i].start.y) * dy;
                float tb = (points[b].x - lines[i].start.x) * dx +
                           (points[b].y - lines[i].start.y) * dy;
                if (ta > tb) {
                    Vector2 tmp = points[a];
                    points[a] = points[b];
                    points[b] = tmp;
                }
            }
        }

        // Create segments between consecutive points
        int is_guard = (lines[i].board_index < 0) ? 1 : 0;
        int source = is_guard ? -1 : lines[i].board_index;

        for (int p = 0; p < point_count - 1; p++) {
            // Skip very short segments
            float seg_dx = points[p + 1].x - points[p].x;
            float seg_dy = points[p + 1].y - points[p].y;
            if (seg_dx * seg_dx + seg_dy * seg_dy < VERTEX_MERGE_THRESHOLD * VERTEX_MERGE_THRESHOLD) {
                continue;
            }

            int va = line_graph_add_vertex(graph, points[p].x, points[p].y);
            int vb = line_graph_add_vertex(graph, points[p + 1].x, points[p + 1].y);

            if (va >= 0 && vb >= 0) {
                line_graph_add_segment(graph, va, vb, source, is_guard);
            }
        }
    }

    free(lines);
    free(intersections);
}
// }}}

// =============================================================================
// Cycle Detection (Finding Closed Polygons)
// =============================================================================

// {{{ detect_cycles
// Uses a face-finding algorithm for planar graphs.
// For each edge, we walk around minimal cycles by always turning "right"
// (choosing the next edge with smallest counter-clockwise angle).
static void detect_cycles(PolygonManager* manager, LineGraph* graph) {
    if (!manager || !graph || graph->segment_count == 0) return;

    // Track which directed edges have been visited
    // Each segment has 2 directions: A->B and B->A
    int* visited = (int*)calloc(graph->segment_count * 2, sizeof(int));
    if (!visited) return;

    // For each unvisited directed edge, try to find a cycle
    for (int start_seg = 0; start_seg < graph->segment_count; start_seg++) {
        for (int start_dir = 0; start_dir < 2; start_dir++) {
            int edge_id = start_seg * 2 + start_dir;
            if (visited[edge_id]) continue;

            // Current edge
            int curr_seg = start_seg;
            int curr_from = start_dir == 0 ?
                            graph->segments[start_seg].vertex_a :
                            graph->segments[start_seg].vertex_b;
            int curr_to = start_dir == 0 ?
                          graph->segments[start_seg].vertex_b :
                          graph->segments[start_seg].vertex_a;

            // Collect cycle vertices
            Vector2 cycle_verts[POLYGON_MAX_VERTICES];
            int cycle_lines[POLYGON_MAX_VERTICES];
            int cycle_len = 0;
            int valid_cycle = 1;

            int iter_count = 0;
            int max_iters = graph->segment_count * 2 + 10;

            while (iter_count++ < max_iters) {
                // Mark this directed edge as visited
                int dir = (graph->segments[curr_seg].vertex_a == curr_from) ? 0 : 1;
                visited[curr_seg * 2 + dir] = 1;

                // Add vertex to cycle
                if (cycle_len < POLYGON_MAX_VERTICES) {
                    cycle_verts[cycle_len].x = graph->vertices[curr_to].x;
                    cycle_verts[cycle_len].y = graph->vertices[curr_to].y;
                    cycle_lines[cycle_len] = graph->segments[curr_seg].source_line;
                    cycle_len++;
                } else {
                    valid_cycle = 0;
                    break;
                }

                // Check if we've completed the cycle
                if (curr_to == (start_dir == 0 ?
                                graph->segments[start_seg].vertex_a :
                                graph->segments[start_seg].vertex_b)) {
                    break;
                }

                // Find next edge: turn "right" (smallest CCW angle from incoming direction)
                PolyVertex* v = &graph->vertices[curr_to];
                if (v->segment_count < 2) {
                    valid_cycle = 0;
                    break;
                }

                // Incoming direction
                float in_dx = graph->vertices[curr_to].x - graph->vertices[curr_from].x;
                float in_dy = graph->vertices[curr_to].y - graph->vertices[curr_from].y;
                float in_angle = atan2f(in_dy, in_dx);

                // Find edge with smallest CCW turn from incoming direction
                int best_seg = -1;
                int best_next = -1;
                float best_turn = 999.0f;

                for (int i = 0; i < v->segment_count; i++) {
                    int seg = v->segment_indices[i];
                    if (seg == curr_seg) continue;  // Don't go back

                    int next_v = graph->segments[seg].vertex_a == curr_to ?
                                 graph->segments[seg].vertex_b :
                                 graph->segments[seg].vertex_a;

                    float out_dx = graph->vertices[next_v].x - graph->vertices[curr_to].x;
                    float out_dy = graph->vertices[next_v].y - graph->vertices[curr_to].y;
                    float out_angle = atan2f(out_dy, out_dx);

                    // CCW turn amount (positive = left turn)
                    float turn = out_angle - in_angle;
                    // Normalize to [0, 2*PI) - we want smallest positive turn (rightmost)
                    while (turn < 0) turn += 2.0f * 3.14159265f;
                    while (turn >= 2.0f * 3.14159265f) turn -= 2.0f * 3.14159265f;

                    // We want the smallest turn (rightmost path)
                    // But exclude turn of 0 (going straight back)
                    if (turn > EPSILON && turn < best_turn) {
                        best_turn = turn;
                        best_seg = seg;
                        best_next = next_v;
                    }
                }

                if (best_seg < 0) {
                    valid_cycle = 0;
                    break;
                }

                curr_from = curr_to;
                curr_to = best_next;
                curr_seg = best_seg;
            }

            // Validate and add cycle as polygon
            if (valid_cycle && cycle_len >= 3 && cycle_len <= POLYGON_MAX_VERTICES) {
                // Check if cycle is clockwise (positive area = CCW, negative = CW)
                // We want CW for proper rendering
                float area = 0.0f;
                for (int i = 0; i < cycle_len; i++) {
                    int j = (i + 1) % cycle_len;
                    area += cycle_verts[i].x * cycle_verts[j].y;
                    area -= cycle_verts[j].x * cycle_verts[i].y;
                }
                area *= 0.5f;

                // Skip the outer boundary (largest area, usually CCW)
                // We only want interior faces
                if (fabsf(area) < 100.0f) continue;  // Too small
                if (area > 0) continue;  // CCW = exterior face

                // Grow polygon array if needed
                if (manager->polygon_count >= manager->polygon_capacity) {
                    int new_cap = manager->polygon_capacity * 2;
                    Polygon* new_polys = (Polygon*)realloc(manager->polygons,
                                                            new_cap * sizeof(Polygon));
                    if (!new_polys) continue;
                    manager->polygons = new_polys;
                    manager->polygon_capacity = new_cap;
                }

                // Create polygon
                Polygon* poly = &manager->polygons[manager->polygon_count];
                memset(poly, 0, sizeof(Polygon));

                poly->vertex_count = cycle_len;
                for (int i = 0; i < cycle_len; i++) {
                    poly->vertices[i] = cycle_verts[i];
                }

                // Collect unique source lines
                poly->line_count = 0;
                for (int i = 0; i < cycle_len && poly->line_count < POLYGON_MAX_VERTICES; i++) {
                    int src = cycle_lines[i];
                    if (src < 0) {
                        // Guard rail
                        if (src == -1) poly->uses_left_wall = 1;
                        else if (src == -2) poly->uses_right_wall = 1;
                        else if (src == -3) poly->uses_bottom_wall = 1;
                        continue;
                    }

                    // Check if already in list
                    int found = 0;
                    for (int j = 0; j < poly->line_count; j++) {
                        if (poly->line_indices[j] == src) {
                            found = 1;
                            break;
                        }
                    }
                    if (!found) {
                        poly->line_indices[poly->line_count++] = src;
                    }
                }

                // Default visual properties
                poly->fill_color = (Color){100, 100, 150, 100};
                poly->fill_visible = 1;
                poly->restitution = 178;  // Default
                poly->friction = 51;

                // Compute centroid and bounding radius
                polygon_compute_centroid(poly);

                // Triangulate for rendering
                polygon_triangulate(poly);

                manager->polygon_count++;
            }
        }
    }

    free(visited);
}
// }}}

// =============================================================================
// Polygon Manager Rebuild
// =============================================================================

// {{{ polygon_manager_rebuild_internal
// Internal rebuild function with optional origin offset.
// Issue 1003: Takes cell_width and cell_height for rectangular cell support
static void polygon_manager_rebuild_internal(PolygonManager* manager, BoardData* board,
                                              float cell_width, float cell_height,
                                              float origin_x, float origin_y) {
    if (!manager || !board) return;

    // Clear existing
    polygon_manager_clear(manager);

    // Create fresh graph
    manager->graph = line_graph_create();
    if (!manager->graph) return;

    // Build graph with intersections
    find_all_intersections(manager->graph, board, cell_width, cell_height,
                           manager->board_width, manager->board_height);

    // Detect cycles to find polygons
    detect_cycles(manager, manager->graph);

    // Apply origin offset to all polygon vertices if needed
    if (origin_x != 0.0f || origin_y != 0.0f) {
        for (int p = 0; p < manager->polygon_count; p++) {
            Polygon* poly = &manager->polygons[p];
            for (int v = 0; v < poly->vertex_count; v++) {
                poly->vertices[v].x += origin_x;
                poly->vertices[v].y += origin_y;
            }
            // Recompute centroid with offset
            polygon_compute_centroid(poly);
        }
    }

    printf("Polygon detection: found %d polygons from %d vertices, %d segments\n",
           manager->polygon_count, manager->graph->vertex_count, manager->graph->segment_count);
}
// }}}

// {{{ polygon_manager_rebuild
// Issue 1003: Takes cell_width and cell_height for rectangular cell support
void polygon_manager_rebuild(PolygonManager* manager, BoardData* board,
                             float cell_width, float cell_height) {
    polygon_manager_rebuild_internal(manager, board, cell_width, cell_height, 0.0f, 0.0f);
}
// }}}

// {{{ polygon_manager_rebuild_offset
// Issue 1003: Takes cell_width and cell_height for rectangular cell support
void polygon_manager_rebuild_offset(PolygonManager* manager, BoardData* board,
                                     float cell_width, float cell_height,
                                     float origin_x, float origin_y) {
    polygon_manager_rebuild_internal(manager, board, cell_width, cell_height, origin_x, origin_y);
}
// }}}

// =============================================================================
// Point-in-Polygon Test
// =============================================================================

// {{{ point_in_polygon
int point_in_polygon(float x, float y, Polygon* poly) {
    if (!poly || poly->vertex_count < 3) return 0;

    int inside = 0;

    for (int i = 0, j = poly->vertex_count - 1; i < poly->vertex_count; j = i++) {
        float xi = poly->vertices[i].x, yi = poly->vertices[i].y;
        float xj = poly->vertices[j].x, yj = poly->vertices[j].y;

        if (((yi > y) != (yj > y)) &&
            (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
            inside = !inside;
        }
    }

    return inside;
}
// }}}

// {{{ polygon_manager_get_polygon_at
Polygon* polygon_manager_get_polygon_at(PolygonManager* manager, float x, float y) {
    if (!manager) return NULL;

    for (int i = 0; i < manager->polygon_count; i++) {
        Polygon* poly = &manager->polygons[i];

        // Broad phase: bounding circle
        float dx = x - poly->centroid.x;
        float dy = y - poly->centroid.y;
        if (dx * dx + dy * dy > poly->bounding_radius * poly->bounding_radius) {
            continue;
        }

        // Narrow phase: point-in-polygon
        if (point_in_polygon(x, y, poly)) {
            return poly;
        }
    }

    return NULL;
}
// }}}

// =============================================================================
// Utility Functions
// =============================================================================

// {{{ polygon_compute_centroid
void polygon_compute_centroid(Polygon* poly) {
    if (!poly || poly->vertex_count < 3) return;

    // Compute centroid as average of vertices
    float cx = 0, cy = 0;
    for (int i = 0; i < poly->vertex_count; i++) {
        cx += poly->vertices[i].x;
        cy += poly->vertices[i].y;
    }
    poly->centroid.x = cx / poly->vertex_count;
    poly->centroid.y = cy / poly->vertex_count;

    // Compute bounding radius (max distance from centroid)
    float max_dist_sq = 0;
    for (int i = 0; i < poly->vertex_count; i++) {
        float dx = poly->vertices[i].x - poly->centroid.x;
        float dy = poly->vertices[i].y - poly->centroid.y;
        float dist_sq = dx * dx + dy * dy;
        if (dist_sq > max_dist_sq) {
            max_dist_sq = dist_sq;
        }
    }
    poly->bounding_radius = sqrtf(max_dist_sq);
}
// }}}

// {{{ point_to_segment_distance
float point_to_segment_distance(float px, float py, Vector2 a, Vector2 b,
                                float* out_normal_x, float* out_normal_y) {
    float abx = b.x - a.x;
    float aby = b.y - a.y;
    float apx = px - a.x;
    float apy = py - a.y;

    float ab_sq = abx * abx + aby * aby;
    if (ab_sq < EPSILON) {
        // Degenerate segment
        float dx = px - a.x;
        float dy = py - a.y;
        float dist = sqrtf(dx * dx + dy * dy);
        if (dist > EPSILON && out_normal_x && out_normal_y) {
            *out_normal_x = dx / dist;
            *out_normal_y = dy / dist;
        }
        return dist;
    }

    float t = (apx * abx + apy * aby) / ab_sq;
    t = fmaxf(0.0f, fminf(1.0f, t));

    float closest_x = a.x + t * abx;
    float closest_y = a.y + t * aby;

    float dx = px - closest_x;
    float dy = py - closest_y;
    float dist = sqrtf(dx * dx + dy * dy);

    if (dist > EPSILON && out_normal_x && out_normal_y) {
        *out_normal_x = dx / dist;
        *out_normal_y = dy / dist;
    } else if (out_normal_x && out_normal_y) {
        // Point is on segment, use perpendicular
        float len = sqrtf(ab_sq);
        *out_normal_x = -aby / len;
        *out_normal_y = abx / len;
    }

    return dist;
}
// }}}

// =============================================================================
// Ball-Polygon Collision
// =============================================================================

// {{{ polygon_check_ball_collision
int polygon_check_ball_collision(Polygon* poly,
                                  float ball_x, float ball_y, float ball_radius,
                                  float* out_push_x, float* out_push_y,
                                  float* out_push_dist) {
    if (!poly || poly->vertex_count < 3) return 0;

    // Broad phase
    float dx = ball_x - poly->centroid.x;
    float dy = ball_y - poly->centroid.y;
    if (dx * dx + dy * dy > (poly->bounding_radius + ball_radius) * (poly->bounding_radius + ball_radius)) {
        return 0;
    }

    // Narrow phase: is ball center inside?
    if (!point_in_polygon(ball_x, ball_y, poly)) {
        return 0;
    }

    // Ball is inside - find nearest edge and compute ejection
    float min_dist = 1e10f;
    float best_nx = 0, best_ny = 0;

    for (int i = 0; i < poly->vertex_count; i++) {
        int j = (i + 1) % poly->vertex_count;
        Vector2 a = poly->vertices[i];
        Vector2 b = poly->vertices[j];

        float nx, ny;
        float dist = point_to_segment_distance(ball_x, ball_y, a, b, &nx, &ny);

        if (dist < min_dist) {
            min_dist = dist;
            best_nx = nx;
            best_ny = ny;
        }
    }

    if (out_push_x) *out_push_x = best_nx;
    if (out_push_y) *out_push_y = best_ny;
    if (out_push_dist) *out_push_dist = ball_radius - min_dist + 1.0f;  // +1 for bias

    return 1;
}
// }}}

// =============================================================================
// Triangulation (Ear Clipping)
// =============================================================================

// {{{ cross_2d
// 2D cross product for three points: (b-a) x (c-a)
// Positive = CCW, Negative = CW
static float cross_2d(Vector2 a, Vector2 b, Vector2 c) {
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
}
// }}}

// {{{ is_ear
// Checks if vertex 'curr' forms an ear (convex and no other vertices inside)
static int is_ear(Vector2* verts, int n, int prev, int curr, int next) {
    Vector2 a = verts[prev];
    Vector2 b = verts[curr];
    Vector2 c = verts[next];

    // Must be convex (CW winding for our polygons = cross < 0)
    if (cross_2d(a, b, c) >= 0) {
        return 0;  // Reflex vertex
    }

    // Check no other vertex is inside triangle abc
    for (int i = 0; i < n; i++) {
        if (i == prev || i == curr || i == next) continue;

        Vector2 p = verts[i];

        // Point in triangle test using cross products
        float d1 = cross_2d(a, b, p);
        float d2 = cross_2d(b, c, p);
        float d3 = cross_2d(c, a, p);

        // All same sign (all negative for CW) means inside
        if (d1 < 0 && d2 < 0 && d3 < 0) {
            return 0;  // Point inside, not an ear
        }
    }

    return 1;
}
// }}}

// {{{ polygon_triangulate
int polygon_triangulate(Polygon* poly) {
    if (!poly || poly->vertex_count < 3) return 0;

    int n = poly->vertex_count;
    if (n == 3) {
        // Already a triangle
        poly->triangle_indices[0] = 0;
        poly->triangle_indices[1] = 1;
        poly->triangle_indices[2] = 2;
        poly->triangle_count = 1;
        return 1;
    }

    // Working copy of vertex indices
    int indices[POLYGON_MAX_VERTICES];
    for (int i = 0; i < n; i++) {
        indices[i] = i;
    }

    int remaining = n;
    poly->triangle_count = 0;

    // Ear clipping: repeatedly find and remove ears
    int iter = 0;
    int max_iter = n * n;  // Safety limit

    while (remaining > 3 && iter++ < max_iter) {
        int found_ear = 0;

        for (int i = 0; i < remaining; i++) {
            int prev = (i + remaining - 1) % remaining;
            int next = (i + 1) % remaining;

            if (is_ear(poly->vertices, n, indices[prev], indices[i], indices[next])) {
                // Add triangle
                int ti = poly->triangle_count * 3;
                poly->triangle_indices[ti + 0] = indices[prev];
                poly->triangle_indices[ti + 1] = indices[i];
                poly->triangle_indices[ti + 2] = indices[next];
                poly->triangle_count++;

                // Remove ear vertex
                for (int j = i; j < remaining - 1; j++) {
                    indices[j] = indices[j + 1];
                }
                remaining--;

                found_ear = 1;
                break;
            }
        }

        if (!found_ear) {
            // Couldn't find an ear - polygon might be degenerate
            break;
        }
    }

    // Add final triangle
    if (remaining == 3 && poly->triangle_count < POLYGON_MAX_TRIANGLES) {
        int ti = poly->triangle_count * 3;
        poly->triangle_indices[ti + 0] = indices[0];
        poly->triangle_indices[ti + 1] = indices[1];
        poly->triangle_indices[ti + 2] = indices[2];
        poly->triangle_count++;
    }

    return poly->triangle_count > 0;
}
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ polygon_render
void polygon_render(Polygon* poly) {
    if (!poly || !poly->fill_visible || poly->triangle_count == 0) return;

    for (int i = 0; i < poly->triangle_count; i++) {
        int i0 = poly->triangle_indices[i * 3 + 0];
        int i1 = poly->triangle_indices[i * 3 + 1];
        int i2 = poly->triangle_indices[i * 3 + 2];

        DrawTriangle(
            poly->vertices[i0],
            poly->vertices[i1],
            poly->vertices[i2],
            poly->fill_color
        );
    }
}
// }}}

// {{{ polygon_manager_render_all
void polygon_manager_render_all(PolygonManager* manager) {
    if (!manager) return;

    for (int i = 0; i < manager->polygon_count; i++) {
        polygon_render(&manager->polygons[i]);
    }
}
// }}}
