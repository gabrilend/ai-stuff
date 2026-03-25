# 704 - Ramp Obstacle Type

## Current Behavior

The only collision obstacles are:
- **Pegs**: Circular obstacles that balls bounce off with restitution
- **Bumpers**: Low-restitution collision points at gate dividers
- **Walls**: Vertical rails at table edges

There is no diagonal or sloped surface that redirects balls horizontally.

## Intended Behavior

Introduce Ramp obstacles that deflect balls along a diagonal surface:

**Ramp properties:**
- Angled surface (e.g., 30-45 degrees from horizontal)
- Direction: LEFT or RIGHT (determines which way balls are deflected)
- Balls rolling along ramp gain/maintain horizontal velocity
- Smooth sliding rather than bouncing (low restitution on surface)

**Ramp collision physics:**
- Ball contacts ramp surface
- Velocity is projected along ramp direction
- Ball slides along ramp until reaching edge or leaving contact
- Small gravity component pulls ball down ramp

**Visual appearance:**
- Solid diagonal line/wedge shape
- Color indicates direction (warm = right, cool = left)
- Slight 3D beveled appearance for depth

## Suggested Implementation Steps

### Step 1: Define Ramp struct

```c
// New in 004-world.h or 016-ramp.h

typedef enum RampDirection {
    RAMP_LEFT,   // Deflects balls to the left
    RAMP_RIGHT   // Deflects balls to the right
} RampDirection;

typedef struct Ramp {
    float x, y;            // Position (center or left corner)
    float width;           // Horizontal extent
    float height;          // Vertical extent
    float angle;           // Angle in radians (from horizontal)
    RampDirection dir;     // Direction of deflection

    // Derived for collision
    float x1, y1;          // Start point of ramp line
    float x2, y2;          // End point of ramp line
    float nx, ny;          // Surface normal (pointing up)
} Ramp;
```

### Step 2: Ramp creation function

```c
Ramp ramp_create(float x, float y, float width, float height,
                 RampDirection dir) {
    Ramp ramp;
    ramp.x = x;
    ramp.y = y;
    ramp.width = width;
    ramp.height = height;
    ramp.dir = dir;

    // Calculate angle
    ramp.angle = atan2f(height, width);

    // Calculate endpoints
    if (dir == RAMP_RIGHT) {
        // Slopes down-right: ball enters top-left, exits bottom-right
        ramp.x1 = x;
        ramp.y1 = y;
        ramp.x2 = x + width;
        ramp.y2 = y + height;
    } else {
        // Slopes down-left: ball enters top-right, exits bottom-left
        ramp.x1 = x + width;
        ramp.y1 = y;
        ramp.x2 = x;
        ramp.y2 = y + height;
    }

    // Calculate normal (perpendicular to surface, pointing up)
    float dx = ramp.x2 - ramp.x1;
    float dy = ramp.y2 - ramp.y1;
    float len = sqrtf(dx*dx + dy*dy);
    ramp.nx = -dy / len;  // Perpendicular
    ramp.ny = dx / len;
    if (ramp.ny < 0) {
        ramp.nx = -ramp.nx;
        ramp.ny = -ramp.ny;
    }

    return ramp;
}
```

### Step 3: Ball-ramp collision detection

```c
int ball_check_ramp_collision(Ball* ball, Ramp* ramp, float* penetration,
                              float* contact_x, float* contact_y) {
    // Find closest point on ramp line segment to ball center
    float px, py;
    closest_point_on_segment(ball->x, ball->y,
                             ramp->x1, ramp->y1,
                             ramp->x2, ramp->y2,
                             &px, &py);

    // Check distance
    float dx = ball->x - px;
    float dy = ball->y - py;
    float dist = sqrtf(dx*dx + dy*dy);

    if (dist < ball->radius) {
        *penetration = ball->radius - dist;
        *contact_x = px;
        *contact_y = py;
        return 1;
    }
    return 0;
}
```

### Step 4: Ball-ramp collision response

```c
void ball_resolve_ramp_collision(Ball* ball, Ramp* ramp,
                                 float penetration) {
    // Push ball out along normal
    ball->x += ramp->nx * penetration;
    ball->y += ramp->ny * penetration;

    // Project velocity onto ramp surface (low restitution slide)
    float dot_normal = ball->vx * ramp->nx + ball->vy * ramp->ny;

    if (dot_normal < 0) {
        // Ball moving into ramp - remove normal component, keep tangent
        float restitution = 0.1f;  // Very low - sliding, not bouncing
        ball->vx -= (1.0f + restitution) * dot_normal * ramp->nx;
        ball->vy -= (1.0f + restitution) * dot_normal * ramp->ny;

        // Add small velocity along ramp direction (gravity assist)
        float tangent_x = ramp->x2 - ramp->x1;
        float tangent_y = ramp->y2 - ramp->y1;
        float len = sqrtf(tangent_x*tangent_x + tangent_y*tangent_y);
        tangent_x /= len;
        tangent_y /= len;

        ball->vx += tangent_x * 20.0f;  // Gentle push along ramp
        ball->vy += tangent_y * 20.0f;
    }
}
```

### Step 5: Ramp rendering

```c
void ramp_render(Ramp* ramp) {
    // Draw filled triangle/wedge
    Color color = (ramp->dir == RAMP_RIGHT) ? ORANGE : SKYBLUE;

    // Triangle vertices for wedge appearance
    Vector2 v1 = { ramp->x1, ramp->y1 };
    Vector2 v2 = { ramp->x2, ramp->y2 };
    Vector2 v3 = (ramp->dir == RAMP_RIGHT)
        ? (Vector2){ ramp->x1, ramp->y2 }   // Bottom-left corner
        : (Vector2){ ramp->x2, ramp->y2 };  // Bottom-right corner

    DrawTriangle(v1, v2, v3, color);

    // Draw surface line for emphasis
    DrawLineEx(v1, v2, 3.0f, ColorBrightness(color, -0.3f));
}
```

### Step 6: Integrate with Stage system

```c
// In Stage struct
Ramp* ramps;
int ramp_count;

// In ball physics update
void ball_update_ramp_collisions(Ball* ball, Stage* stage) {
    for (int i = 0; i < stage->ramp_count; i++) {
        float pen, cx, cy;
        if (ball_check_ramp_collision(ball, &stage->ramps[i], &pen, &cx, &cy)) {
            ball_resolve_ramp_collision(ball, &stage->ramps[i], pen);
        }
    }
}
```

## Files to Create

- `src/016-ramp.h` - Ramp structure and function declarations
- `src/017-ramp.c` - Ramp collision and rendering implementation

## Files to Modify

- `src/007-ball.c` - Ball-ramp collision checks in physics update
- `src/014-stage.h` - Ramp array in Stage struct

## Dependencies

- Issue 1002 (Stage system architecture)

## Testing

1. Ball approaches ramp from above - slides along surface
2. Ball velocity redirected in ramp direction
3. Ball maintains momentum through ramp contact
4. Left ramp deflects left, right ramp deflects right
5. Ramps render with correct orientation and color
6. Multiple ramps in sequence work correctly
