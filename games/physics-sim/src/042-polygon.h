// src/042-polygon.h
// Closed polygon detection and fill system for pachinko board
// Detects when lines form closed loops and provides physics collision

#ifndef POLYGON_H
#define POLYGON_H

#include "raylib.h"

// Forward declarations
typedef struct BoardData BoardData;

// =============================================================================
// Constants
// =============================================================================

#define POLYGON_MAX_VERTICES 32      // Max vertices per polygon
#define POLYGON_MAX_TRIANGLES 30     // Max triangles per polygon (n-2 for convex)
#define VERTEX_MERGE_THRESHOLD 2.0f  // Pixels - vertices closer than this merge
#define MAX_LINE_INTERSECTIONS 256   // Max pairwise intersections to track
#define MAX_POLYGONS 64              // Max polygons per board

// =============================================================================
// Data Structures
// =============================================================================

// {{{ typedef struct PolyVertex
// A vertex in the line graph - either a line endpoint or intersection point.
// Vertices are identified by position and track which line segments connect.
typedef struct PolyVertex {
    float x, y;              // Position in pixels
    int* segment_indices;    // Indices of segments meeting here
    int segment_count;       // Number of connected segments
    int segment_capacity;    // Allocated capacity
} PolyVertex;
// }}}

// {{{ typedef struct PolySegment
// A segment in the line graph - represents a portion of a line between vertices.
// Lines are split at intersection points, so one BoardObject line may become
// multiple PolySegments.
typedef struct PolySegment {
    int vertex_a;            // Index of first vertex
    int vertex_b;            // Index of second vertex
    int source_line;         // Index of original BoardObject line (-1 for guard rail)
    int is_guard_rail;       // 1 if this is a board boundary segment
} PolySegment;
// }}}

// {{{ typedef struct LineGraph
// Graph representation of all lines on the board.
// Vertices come from endpoints and intersection points.
// Segments connect vertices and may be subdivisions of original lines.
typedef struct LineGraph {
    PolyVertex* vertices;
    int vertex_count;
    int vertex_capacity;

    PolySegment* segments;
    int segment_count;
    int segment_capacity;
} LineGraph;
// }}}

// {{{ typedef struct Polygon
// A closed polygon formed by connected line segments.
// Contains cached triangulation for rendering and physics data.
typedef struct Polygon {
    // Ordered vertices (clockwise or counter-clockwise)
    Vector2 vertices[POLYGON_MAX_VERTICES];
    int vertex_count;

    // Triangulation for fill rendering (indices into vertices array)
    int triangle_indices[POLYGON_MAX_TRIANGLES * 3];
    int triangle_count;

    // Bounding data for broad-phase collision
    Vector2 centroid;
    float bounding_radius;

    // Visual properties (fill is cosmetic only)
    Color fill_color;
    int fill_visible;        // 1 = render fill, 0 = invisible (physics still active)

    // Physics properties derived from constituent lines
    unsigned char restitution;
    unsigned char friction;

    // Source line indices (for editing - which lines form this polygon)
    int line_indices[POLYGON_MAX_VERTICES];
    int line_count;

    // Guard rail flags
    int uses_left_wall;
    int uses_right_wall;
    int uses_bottom_wall;
} Polygon;
// }}}

// {{{ typedef struct PolygonManager
// Manages all detected polygons on a board.
// Polygons are recomputed when lines change.
typedef struct PolygonManager {
    Polygon* polygons;
    int polygon_count;
    int polygon_capacity;

    // Cached line graph (rebuilt when lines change)
    LineGraph* graph;

    // Board dimensions for guard rails
    float board_width;
    float board_height;
} PolygonManager;
// }}}

// =============================================================================
// PolygonManager Lifecycle
// =============================================================================

// {{{ polygon_manager_create
// Creates a polygon manager for the given board dimensions.
// Board dimensions are needed for guard rail segments.
// Returns NULL on allocation failure.
PolygonManager* polygon_manager_create(float board_width, float board_height);
// }}}

// {{{ polygon_manager_destroy
// Frees all resources associated with a polygon manager.
void polygon_manager_destroy(PolygonManager* manager);
// }}}

// =============================================================================
// Polygon Detection
// =============================================================================

// {{{ polygon_manager_rebuild
// Rebuilds the polygon list from the current board lines.
// Extracts line segments, finds intersections, builds graph, detects cycles.
// Call this whenever lines are added, removed, or modified.
//
// Parameters:
//   manager: PolygonManager instance
//   board: BoardData containing line objects
//   cell_width, cell_height: Grid cell dimensions for coordinate conversion (issue 1003)
void polygon_manager_rebuild(PolygonManager* manager, BoardData* board,
                             float cell_width, float cell_height);
// }}}

// {{{ polygon_manager_rebuild_offset
// Same as polygon_manager_rebuild but with origin offset for world coordinates.
// Use this when the board is placed at a position other than (0,0).
//
// Parameters:
//   manager: PolygonManager instance
//   board: BoardData containing line objects
//   cell_width, cell_height: Grid cell dimensions for coordinate conversion (issue 1003)
//   origin_x, origin_y: Offset to add to all vertex positions
void polygon_manager_rebuild_offset(PolygonManager* manager, BoardData* board,
                                     float cell_width, float cell_height,
                                     float origin_x, float origin_y);
// }}}

// {{{ polygon_manager_clear
// Removes all detected polygons.
// Does not free the manager itself.
void polygon_manager_clear(PolygonManager* manager);
// }}}

// =============================================================================
// Line-Line Intersection
// =============================================================================

// {{{ line_intersection
// Tests if two line segments intersect and returns intersection point.
// Uses parametric line equations to find intersection.
//
// Parameters:
//   a1, a2: First line segment endpoints
//   b1, b2: Second line segment endpoints
//   out_point: Output intersection point (if return is 1)
//
// Returns: 1 if segments intersect, 0 otherwise
int line_intersection(Vector2 a1, Vector2 a2, Vector2 b1, Vector2 b2,
                      Vector2* out_point);
// }}}

// =============================================================================
// Point-in-Polygon Test
// =============================================================================

// {{{ point_in_polygon
// Tests if a point is inside a polygon using ray casting algorithm.
// Ray is cast horizontally to the right; odd crossings = inside.
//
// Parameters:
//   x, y: Point to test
//   poly: Polygon to test against
//
// Returns: 1 if point is inside, 0 otherwise
int point_in_polygon(float x, float y, Polygon* poly);
// }}}

// {{{ polygon_manager_get_polygon_at
// Finds the polygon containing a given point.
// Returns NULL if point is not inside any polygon.
//
// Parameters:
//   manager: PolygonManager instance
//   x, y: Point to test
//
// Returns: Pointer to polygon containing point, or NULL
Polygon* polygon_manager_get_polygon_at(PolygonManager* manager, float x, float y);
// }}}

// =============================================================================
// Ball-Polygon Collision
// =============================================================================

// {{{ polygon_check_ball_collision
// Checks if a ball is inside a polygon and computes ejection response.
// If ball center is inside, finds nearest edge and computes push direction.
//
// Parameters:
//   poly: Polygon to check
//   ball_x, ball_y: Ball center position
//   ball_radius: Ball radius
//   out_push_x, out_push_y: Output push direction (normalized)
//   out_push_dist: Output distance to push ball
//
// Returns: 1 if collision occurred, 0 otherwise
int polygon_check_ball_collision(Polygon* poly,
                                  float ball_x, float ball_y, float ball_radius,
                                  float* out_push_x, float* out_push_y,
                                  float* out_push_dist);
// }}}

// =============================================================================
// Rendering
// =============================================================================

// {{{ polygon_render
// Renders a polygon's filled interior using triangulation.
// Uses the polygon's fill_color and respects fill_visible flag.
//
// Parameters:
//   poly: Polygon to render
void polygon_render(Polygon* poly);
// }}}

// {{{ polygon_manager_render_all
// Renders all visible polygons in the manager.
//
// Parameters:
//   manager: PolygonManager instance
void polygon_manager_render_all(PolygonManager* manager);
// }}}

// =============================================================================
// Triangulation
// =============================================================================

// {{{ polygon_triangulate
// Computes triangulation of a polygon using ear clipping algorithm.
// Fills triangle_indices and triangle_count in the polygon.
// Works for simple (non-self-intersecting) polygons, convex or concave.
//
// Parameters:
//   poly: Polygon to triangulate (modified in place)
//
// Returns: 1 on success, 0 if triangulation failed
int polygon_triangulate(Polygon* poly);
// }}}

// =============================================================================
// Utility
// =============================================================================

// {{{ polygon_compute_centroid
// Computes centroid and bounding radius of a polygon.
// Updates centroid and bounding_radius fields.
//
// Parameters:
//   poly: Polygon to compute (modified in place)
void polygon_compute_centroid(Polygon* poly);
// }}}

// {{{ point_to_segment_distance
// Computes shortest distance from a point to a line segment.
// Also outputs the normal direction from segment to point.
//
// Parameters:
//   px, py: Point position
//   a, b: Segment endpoints
//   out_normal_x, out_normal_y: Output normal direction (normalized)
//
// Returns: Distance from point to segment
float point_to_segment_distance(float px, float py, Vector2 a, Vector2 b,
                                float* out_normal_x, float* out_normal_y);
// }}}

#endif // POLYGON_H
