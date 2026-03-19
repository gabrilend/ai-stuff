# 837 - Closed Polygon Detection and Fill

## Status: awaiting-work

## Depends on

None - can be implemented independently.

## Related Issues

- 839 (Material type selector) - provides material system for polygon edges

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

### Guard Rails as Lines

Board guard rails (left, right, and bottom walls) should count as line segments for polygon detection. This allows polygons to close against the board edges without requiring explicit line placement at walls.

```c
// Virtual lines representing board boundaries
// These are implicit - not stored in board data, generated at detection time
Line guard_rails[3] = {
    { {0, 0}, {0, BOARD_HEIGHT} },           // Left wall
    { {BOARD_WIDTH, 0}, {BOARD_WIDTH, BOARD_HEIGHT} },  // Right wall
    { {0, BOARD_HEIGHT}, {BOARD_WIDTH, BOARD_HEIGHT} }  // Bottom
};
```

When building the line graph, include guard rails as additional line segments. Polygons can form by connecting to these implicit edges.

### Phase 1: Closed Loop Detection

Lines form a graph where vertices come from TWO sources (THREE with guard rails):
1. Line endpoints
2. Line-line intersection points (where lines cross)
3. Guard rail endpoints and intersections with lines

This allows closed regions to form even when no endpoints share coordinates.

**Example: Fish/X shape**
```
    \   /
     \ /
      X  <-- intersection creates vertex here (no endpoint exists)
     / \
    /   \
   *-----*  <-- endpoints converge here
```
Result: 1 closed triangle (bottom), 3 open areas (top/sides)

```c
typedef struct LineGraph {
    // Vertices from endpoints AND intersections
    Vector2* vertices;
    int vertex_count;

    // Each vertex knows which line segments connect to it
    int** adjacency;
    int* adjacency_counts;
} LineGraph;

// Build graph: find all intersections, split lines, build adjacency
LineGraph* build_line_graph(BoardData* board);

// Find all minimal cycles (closed polygons)
Polygon* find_closed_polygons(LineGraph* graph, int* out_count);
```

**Graph building algorithm:**
1. Find all line-line intersections
2. Split lines at intersection points into sub-segments
3. Collect all vertices (original endpoints + intersection points)
4. Merge vertices within proximity threshold (for near-misses)
5. Build adjacency list from segments

**Line-line intersection:**
```c
// Returns 1 if lines intersect, stores intersection point in out_point
int line_intersection(Vector2 a1, Vector2 a2, Vector2 b1, Vector2 b2,
                      Vector2* out_point) {
    float d = (a1.x - a2.x) * (b1.y - b2.y) - (a1.y - a2.y) * (b1.x - b2.x);
    if (fabsf(d) < 0.0001f) return 0;  // Parallel

    float t = ((a1.x - b1.x) * (b1.y - b2.y) - (a1.y - b1.y) * (b1.x - b2.x)) / d;
    float u = -((a1.x - a2.x) * (a1.y - b1.y) - (a1.y - a2.y) * (a1.x - b1.x)) / d;

    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
        out_point->x = a1.x + t * (a2.x - a1.x);
        out_point->y = a1.y + t * (a2.y - a1.y);
        return 1;
    }
    return 0;  // Intersection outside segments
}
```

**Line splitting:**
```c
// After finding all intersections for a line, sort by parameter t
// Split original line into segments between consecutive points
// Example: line A-B with intersections at P1, P2
// Becomes segments: A-P1, P1-P2, P2-B
```

**Cycle detection algorithm:**
1. Use DFS to find all simple cycles in planar graph
2. Filter to minimal cycles (no nested shortcuts)
3. Order vertices clockwise/counter-clockwise
4. Each minimal cycle = one filled polygon

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

    // Visual properties (fill is purely cosmetic)
    Color fill_color;       // Interior fill color
    int fill_visible;       // 0 = invisible fill, 1 = visible fill

    // Line properties (affects physics)
    Color line_color;       // Edge color - determines physics behavior
    unsigned char restitution;  // Derived from line_color
    unsigned char friction;     // Derived from line_color

    // Line indices that form this polygon (for editing)
    int* line_indices;
    int line_count;
} Polygon;

// Line color to physics mapping
// Different colors = different materials with different bounce/friction
typedef struct LineMaterial {
    Color color;
    unsigned char restitution;
    unsigned char friction;
    const char* name;  // For editor display
} LineMaterial;

// Predefined materials
static const LineMaterial LINE_MATERIALS[] = {
    { {128, 128, 128, 255}, 180, 50, "Stone" },      // Gray - standard bounce
    { {200, 100, 50, 255},  220, 30, "Rubber" },     // Orange - high bounce
    { {100, 150, 200, 255}, 100, 80, "Ice" },        // Blue - low friction
    { {50, 50, 50, 255},    50, 90, "Sticky" },      // Dark - absorbs energy
    { {255, 200, 50, 255},  250, 20, "Bouncy" },     // Yellow - maximum bounce
};
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
- Polygons against guard rails render with edge touching the wall

### Click-to-Select Polygon

When clicking inside a filled polygon area in the editor:
1. Point-in-polygon test determines which polygon was clicked
2. Selected polygon gets highlighted border
3. Properties panel appears with editable fields

```c
Polygon* editor_get_polygon_at_point(float x, float y) {
    for (int i = 0; i < polygon_count; i++) {
        if (point_in_polygon(x, y, &polygons[i])) {
            return &polygons[i];
        }
    }
    return NULL;  // No polygon at this point
}
```

### Polygon Properties Panel

When a polygon is selected, show editable properties:

```
┌─────────────────────────────────┐
│ Polygon Properties              │
├─────────────────────────────────┤
│ Fill Color:  [████] [Pick...]   │  ← Visual only, no physics effect
│ ☑ Fill Visible                  │  ← Checkbox to hide fill
│                                 │
│ Line Color:  [████] [Pick...]   │  ← Affects physics (restitution/friction)
│ Material: [Rubber ▼]            │  ← Preset or custom
│   Restitution: 220              │  ← Auto-set from material
│   Friction: 30                  │  ← Auto-set from material
│                                 │
│ [Delete Polygon]                │
└─────────────────────────────────┘
```

**Fill Color** - Purely cosmetic, changes interior rendering only
**Fill Visible** - Checkbox to toggle fill visibility (physics still active)
**Line Color** - Changes edge color AND physics properties
**Material Presets** - Quick selection of predefined physics behaviors

### Line Color → Physics Mapping

Changing line color automatically updates physics:
```c
void polygon_set_line_color(Polygon* poly, Color color) {
    poly->line_color = color;

    // Find closest matching material
    const LineMaterial* mat = find_closest_material(color);
    poly->restitution = mat->restitution;
    poly->friction = mat->friction;

    // Update all constituent lines to match
    for (int i = 0; i < poly->line_count; i++) {
        Line* line = &board->lines[poly->line_indices[i]];
        line->color = color;
        line->restitution = mat->restitution;
    }
}
```

### Line Deletion Behavior

- When deleting a line that's part of a polygon, delete the entire polygon
- No warning needed - polygon simply ceases to exist
- Remaining lines stay as individual line segments
- User can reform polygon by reconnecting lines

## Data Storage (Board JSON)

Option A: Store polygons explicitly (Recommended)
```json
{
  "polygons": [
    {
      "line_indices": [0, 3, 5, 2],
      "uses_guard_rail": true,
      "guard_rail_side": "left",
      "fill_color": [100, 100, 150, 128],
      "fill_visible": true,
      "line_color": [200, 100, 50, 255],
      "physics_solid": true
    }
  ]
}
```

**Field descriptions:**
- `line_indices` - Indices into the board's line array
- `uses_guard_rail` - True if polygon closes against a board edge
- `guard_rail_side` - Which edge: "left", "right", "bottom"
- `fill_color` - RGBA for interior (visual only)
- `fill_visible` - False to hide fill while keeping physics active
- `line_color` - RGBA for edges (determines physics properties)
- `physics_solid` - True if balls collide with interior

Option B: Detect polygons at load time from lines
- Simpler JSON format
- Recalculate on load
- Risk: detection might differ between saves

Recommend Option A for determinism.

## Implementation Steps

1. Implement line endpoint graph builder
2. Add guard rails as virtual lines in graph building
3. Implement cycle detection (DFS-based)
4. Create Polygon data structure with fill/line color separation
5. Implement LineMaterial system for color→physics mapping
6. Implement ear-clipping triangulation for rendering
7. Implement polygon fill rendering with fill_visible toggle
8. Implement point-in-polygon test
9. Implement ball-polygon collision with ejection
10. Add polygon detection to editor (real-time as lines drawn)
11. Add click-to-select polygon functionality
12. Implement polygon properties panel UI
13. Add fill color picker (visual only)
14. Add line color picker with material presets
15. Add "Fill Visible" checkbox
16. Update board JSON format to store polygon data
17. Test with convex polygons (triangles, rectangles)
18. Test with concave polygons (L-shapes, stars)
19. Test polygons closed against guard rails
20. Test ball collisions at various angles and speeds
21. Test invisible fill with active physics

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

### Line Intersections Create Vertices
- Lines crossing in the middle create implicit vertices
- No endpoint needs to exist at the crossing point
- Algorithm detects all pairwise intersections
- Lines are split at intersection points for graph building

### Proximity Threshold for Near-Misses
- After finding intersections, vertices within threshold are merged
- Handles floating point imprecision
- Also catches "almost touching" endpoints

```c
#define VERTEX_MERGE_THRESHOLD 2.0f  // Pixels (small, just for precision)

int vertices_same(Vector2 a, Vector2 b) {
    float dx = a.x - b.x;
    float dy = a.y - b.y;
    return (dx * dx + dy * dy) < (VERTEX_MERGE_THRESHOLD * VERTEX_MERGE_THRESHOLD);
}
```

## Troubleshooting

### "Polygon not detected"
- Lines don't actually form a closed loop
- Check that lines intersect (not just near each other)
- Verify intersection detection is finding crossing points
- Debug: render all vertices (endpoints + intersections) to visualize graph
- Check cycle detection is finding the minimal cycle

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
