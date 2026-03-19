# 1312 - Closed Polygon Detection and Fill

## Status: Open

## Parent Phase: Phase 13

## Problem

Lines in the editor can form closed shapes (triangles, quadrilaterals, complex polygons), but these are just individual line segments. Balls can pass through the interior of these shapes. Need to:
1. Detect when lines form a closed polygon
2. Fill the polygon visually (rendering)
3. Fill the polygon physically (balls cannot enter interior)

## Current Behavior

- Lines are independent segments with no relationship tracking
- Each line has collision detection on its own
- Balls collide with line surfaces but can enter enclosed areas
- No visual indication that an area is "inside" a closed shape

## Intended Behavior

- Editor detects when lines form closed loops
- Closed polygons rendered with filled interior (semi-transparent)
- Balls cannot enter polygon interiors (solid collision)
- Works for convex and concave polygons

## Design

### Phase 1: Closed Loop Detection

Lines form a graph where endpoints are nodes and lines are edges.

```c
typedef struct LineGraph {
    // Adjacency list representation
    // Each unique endpoint maps to lines connected to it
    Vector2* vertices;      // Unique endpoints
    int vertex_count;

    int** adjacency;        // adjacency[v] = list of line indices touching vertex v
    int* adjacency_counts;
} LineGraph;

// Build graph from board lines
LineGraph* build_line_graph(BoardData* board);

// Find all cycles (closed polygons) in the graph
// Returns array of vertex index loops
Polygon* find_closed_polygons(LineGraph* graph, int* out_count);
```

**Cycle detection algorithm:**
1. Build adjacency list from line endpoints
2. Use DFS to find all simple cycles
3. Filter to minimal cycles (no nested shortcuts)
4. Order vertices clockwise/counter-clockwise

### Phase 2: Polygon Data Structure

```c
typedef struct Polygon {
    Vector2* vertices;      // Ordered vertex positions
    int vertex_count;

    // Cached for rendering
    int* triangle_indices;  // Triangulated for fill rendering
    int triangle_count;

    // Cached for physics
    Vector2 centroid;       // Center point
    float bounding_radius;  // For broad-phase rejection

    // Properties inherited from constituent lines
    unsigned char restitution;
    unsigned char friction;
} Polygon;
```

### Phase 3: Rendering Fill

```c
void render_polygon_fill(Polygon* poly, Color fill_color) {
    // Use triangulation for arbitrary polygons
    // Ear clipping algorithm works for simple polygons

    for (int i = 0; i < poly->triangle_count; i++) {
        int i0 = poly->triangle_indices[i * 3 + 0];
        int i1 = poly->triangle_indices[i * 3 + 1];
        int i2 = poly->triangle_indices[i * 3 + 2];

        DrawTriangle(
            poly->vertices[i0],
            poly->vertices[i1],
            poly->vertices[i2],
            fill_color
        );
    }
}
```

### Phase 4: Physics - Point-in-Polygon Test

```c
// Ray casting algorithm for point-in-polygon
int point_in_polygon(float x, float y, Polygon* poly) {
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
```

### Phase 5: Physics - Ball Ejection

```c
void check_ball_polygon_collision(Ball* ball, Polygon* poly) {
    // Broad phase: bounding circle check
    float dx = ball->x - poly->centroid.x;
    float dy = ball->y - poly->centroid.y;
    float dist = sqrtf(dx * dx + dy * dy);

    if (dist > poly->bounding_radius + ball->radius) {
        return;  // Too far, skip detailed check
    }

    // Narrow phase: point-in-polygon
    if (!point_in_polygon(ball->x, ball->y, poly)) {
        return;  // Ball center not inside
    }

    // Ball is inside polygon - eject it
    // Find nearest edge and push ball outside
    float min_dist = INFINITY;
    Vector2 eject_normal = {0, 0};

    for (int i = 0; i < poly->vertex_count; i++) {
        int j = (i + 1) % poly->vertex_count;
        Vector2 a = poly->vertices[i];
        Vector2 b = poly->vertices[j];

        // Distance from ball center to edge
        float edge_dist = point_to_segment_distance(ball->x, ball->y, a, b, &eject_normal);

        if (edge_dist < min_dist) {
            min_dist = edge_dist;
            // eject_normal points outward from edge
        }
    }

    // Push ball outside + ball radius
    float push = ball->radius - min_dist + COLLISION_BIAS;
    ball->x += eject_normal.x * push;
    ball->y += eject_normal.y * push;

    // Reflect velocity off the edge normal
    float vdot = ball->vx * eject_normal.x + ball->vy * eject_normal.y;
    ball->vx -= 2.0f * vdot * eject_normal.x * poly->restitution;
    ball->vy -= 2.0f * vdot * eject_normal.y * poly->restitution;
}
```

## Editor Integration

### Visual Feedback

- When a closed polygon is formed, highlight it briefly
- Show filled preview when hovering over enclosed area
- Different fill color for selected polygons

### Polygon Properties Panel

- Display "Polygon detected" when lines form closure
- Allow setting fill color/opacity
- Allow toggling physics fill on/off per polygon

### Line Deletion Warning

- When deleting a line that's part of a polygon, warn user
- "This will break the closed shape. Continue?"

## Data Storage (Board JSON)

Option A: Store polygons explicitly
```json
{
  "polygons": [
    {
      "line_indices": [0, 3, 5, 2],
      "fill_color": [100, 100, 150, 128],
      "physics_solid": true
    }
  ]
}
```

Option B: Detect polygons at load time from lines
- Simpler JSON format
- Recalculate on load
- Risk: detection might differ between saves

Recommend Option A for determinism.

## Implementation Steps

1. Implement line endpoint graph builder
2. Implement cycle detection (DFS-based)
3. Create Polygon data structure
4. Implement ear-clipping triangulation for rendering
5. Implement polygon fill rendering
6. Implement point-in-polygon test
7. Implement ball-polygon collision with ejection
8. Add polygon detection to editor (real-time as lines drawn)
9. Add visual feedback for detected polygons
10. Update board JSON format to store polygon data
11. Test with convex polygons (triangles, rectangles)
12. Test with concave polygons (L-shapes, stars)
13. Test ball collisions at various angles and speeds

## Files to Create

- `src/042-polygon.h` - Polygon struct and detection API
- `src/043-polygon.c` - Graph building, cycle detection, triangulation

## Files to Modify

- `src/020-board-data.h` - Add polygon storage to BoardData
- `src/021-board-data.c` - Polygon serialization/deserialization
- `src/007-ball.c` - Add polygon collision checks
- `src/035-object-render.c` - Add polygon fill rendering
- `src/032-editor-app.c` - Real-time polygon detection feedback

## Edge Cases

### Self-Intersecting Lines
- Lines that cross each other create multiple sub-polygons
- Each minimal cycle is a separate polygon
- Or: reject self-intersecting shapes as invalid

### Shared Edges
- Two polygons sharing an edge (like adjacent rooms)
- Each polygon detected independently
- Balls should collide with both

### Very Small Polygons
- Polygon smaller than ball diameter
- Ball might fully contain polygon
- Skip physics for tiny polygons? Or eject forcefully?

### Lines Not Quite Connected
- Endpoints close but not exact (floating point)
- Use epsilon tolerance for "connected" endpoints
- Grid snapping in editor helps prevent this

## Troubleshooting

### "Polygon not detected"
- Line endpoints not exactly coincident
- Check epsilon tolerance for vertex matching
- Verify lines actually form closed loop

### "Ball phases through polygon edge"
- Ball moving too fast (tunneling)
- Use swept collision or multiple substeps
- Check ball velocity doesn't exceed polygon width per frame

### "Wrong area filled"
- Polygon winding order incorrect (CW vs CCW)
- Check triangulation algorithm
- Verify vertex ordering in cycle detection

### "Performance drops with many polygons"
- Too many point-in-polygon tests
- Use spatial hash for polygons too
- Broad-phase bounding circle check helps

### "Ball stuck inside polygon"
- Ejection direction wrong
- Multiple edges at similar distance
- Check nearest-edge calculation

## Notes

- Ear-clipping triangulation is O(n²) but fine for small polygons
- Could use library like poly2tri for complex cases
- Consider: allow "hollow" polygons (just visual, no physics)?
- Consider: polygon "layers" for overlapping shapes?
