// src/016-ramp.h
// Ramp obstacle type for diagonal ball deflection
// Ramps redirect balls along their surface with sliding physics

#ifndef RAMP_H
#define RAMP_H

// {{{ RampDirection enum
// Determines which direction balls are deflected
typedef enum RampDirection {
    RAMP_LEFT,   // Slopes down-left, deflects balls leftward
    RAMP_RIGHT   // Slopes down-right, deflects balls rightward
} RampDirection;
// }}}

// {{{ typedef struct Ramp
// Ramp is a diagonal surface that redirects balls.
// Balls slide along the ramp surface with low restitution.
typedef struct Ramp {
    float x, y;            // Position (top-left corner of bounding box)
    float width;           // Horizontal extent
    float height;          // Vertical extent
    RampDirection dir;     // Direction of deflection

    // Derived for collision (calculated by ramp_create)
    float x1, y1;          // Start point of ramp line (top)
    float x2, y2;          // End point of ramp line (bottom)
    float nx, ny;          // Surface normal (pointing away from solid)
    float tx, ty;          // Tangent vector (along ramp surface)
    float length;          // Length of ramp surface
} Ramp;
// }}}

// Ramp physics constants
#define RAMP_RESTITUTION 0.1f       // Very low - sliding, not bouncing
#define RAMP_GRAVITY_ASSIST 30.0f   // Extra velocity along ramp direction

// =============================================================================
// Ramp creation and rendering
// =============================================================================

// {{{ ramp_create
// Creates a ramp with the given dimensions and direction.
// Calculates derived collision values (endpoints, normal, tangent).
//
// Parameters:
//   x, y: Top-left corner of ramp bounding box
//   width: Horizontal extent of ramp
//   height: Vertical extent of ramp
//   dir: RAMP_LEFT or RAMP_RIGHT
//
// Returns:
//   Initialized Ramp struct
Ramp ramp_create(float x, float y, float width, float height, RampDirection dir);
// }}}

// {{{ ramp_create_line
// Creates a ramp from two endpoints and thickness.
// Used for custom stages with line-based obstacles.
//
// Parameters:
//   x1, y1: Start point of line
//   x2, y2: End point of line
//   thickness: Line thickness (used for collision radius)
//
// Returns:
//   Initialized Ramp struct
Ramp ramp_create_line(float x1, float y1, float x2, float y2, float thickness);
// }}}

// {{{ ramp_render
// Renders a ramp as a filled wedge shape.
// Color indicates direction (warm = right, cool = left).
void ramp_render(Ramp* ramp);
// }}}

// {{{ ramp_render_mirrored
// Renders a ramp for the adversary board (upside-down perspective).
// Used when balls travel upward through the stage.
void ramp_render_mirrored(Ramp* ramp);
// }}}

// =============================================================================
// Ramp collision detection and response
// =============================================================================

// Forward declaration for Ball (defined in 006-ball.h)
typedef struct Ball Ball;

// {{{ ramp_check_collision
// Checks if a ball collides with a ramp surface.
//
// Parameters:
//   ball: Ball to check
//   ramp: Ramp to check against
//   penetration: Output - depth of penetration into ramp
//   contact_x, contact_y: Output - point of contact on ramp surface
//
// Returns:
//   1 if collision detected, 0 otherwise
int ramp_check_collision(Ball* ball, Ramp* ramp, float* penetration,
                         float* contact_x, float* contact_y);
// }}}

// {{{ ramp_resolve_collision
// Resolves a ball-ramp collision by pushing ball out and adjusting velocity.
// Ball slides along ramp surface with low restitution.
//
// Parameters:
//   ball: Ball to resolve (position and velocity modified)
//   ramp: Ramp that was hit
//   penetration: Depth of penetration
void ramp_resolve_collision(Ball* ball, Ramp* ramp, float penetration);
// }}}

// =============================================================================
// Utility functions
// =============================================================================

// {{{ closest_point_on_segment
// Finds the closest point on a line segment to a given point.
//
// Parameters:
//   px, py: Point to find closest point to
//   x1, y1: Start of line segment
//   x2, y2: End of line segment
//   out_x, out_y: Output - closest point on segment
void closest_point_on_segment(float px, float py,
                              float x1, float y1, float x2, float y2,
                              float* out_x, float* out_y);
// }}}

#endif // RAMP_H
