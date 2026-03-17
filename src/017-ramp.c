// src/017-ramp.c
// Ramp obstacle implementation
// Handles ramp creation, collision detection, and rendering

#include "016-ramp.h"
#include "006-ball.h"
#include <raylib.h>
#include <math.h>

// =============================================================================
// Utility functions
// =============================================================================

// {{{ closest_point_on_segment
void closest_point_on_segment(float px, float py,
                              float x1, float y1, float x2, float y2,
                              float* out_x, float* out_y) {
    // Vector from segment start to point
    float dx = px - x1;
    float dy = py - y1;

    // Vector along segment
    float sx = x2 - x1;
    float sy = y2 - y1;

    // Project point onto segment line
    float seg_len_sq = sx * sx + sy * sy;

    // Handle degenerate segment (zero length)
    if (seg_len_sq < 0.0001f) {
        *out_x = x1;
        *out_y = y1;
        return;
    }

    // Parameter t along segment (0 = start, 1 = end)
    float t = (dx * sx + dy * sy) / seg_len_sq;

    // Clamp t to [0, 1] to stay on segment
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;

    // Calculate closest point
    *out_x = x1 + t * sx;
    *out_y = y1 + t * sy;
}
// }}}

// =============================================================================
// Ramp creation and rendering
// =============================================================================

// {{{ ramp_create
Ramp ramp_create(float x, float y, float width, float height, RampDirection dir) {
    Ramp ramp;
    ramp.x = x;
    ramp.y = y;
    ramp.width = width;
    ramp.height = height;
    ramp.dir = dir;

    // Calculate endpoints based on direction
    // RAMP_RIGHT: slopes down-right (ball enters top-left, exits bottom-right)
    // RAMP_LEFT: slopes down-left (ball enters top-right, exits bottom-left)
    if (dir == RAMP_RIGHT) {
        ramp.x1 = x;
        ramp.y1 = y;
        ramp.x2 = x + width;
        ramp.y2 = y + height;
    } else {
        ramp.x1 = x + width;
        ramp.y1 = y;
        ramp.x2 = x;
        ramp.y2 = y + height;
    }

    // Calculate length
    float dx = ramp.x2 - ramp.x1;
    float dy = ramp.y2 - ramp.y1;
    ramp.length = sqrtf(dx * dx + dy * dy);

    // Calculate tangent (along ramp, normalized)
    if (ramp.length > 0.0001f) {
        ramp.tx = dx / ramp.length;
        ramp.ty = dy / ramp.length;
    } else {
        ramp.tx = 1.0f;
        ramp.ty = 0.0f;
    }

    // Calculate normal (perpendicular to surface, pointing "up" from ramp)
    // For a ball falling onto the ramp, normal should point toward the ball
    // Perpendicular to tangent: rotate 90 degrees counterclockwise
    ramp.nx = -ramp.ty;
    ramp.ny = ramp.tx;

    // Ensure normal points upward (negative y in screen coords)
    // For ramps, we want the normal to point away from the solid part
    // The solid part is below the line, so normal should point up
    if (ramp.ny > 0) {
        ramp.nx = -ramp.nx;
        ramp.ny = -ramp.ny;
    }

    return ramp;
}
// }}}

// {{{ ramp_render
void ramp_render(Ramp* ramp) {
    if (!ramp) return;

    // Choose color based on direction
    // Warm colors (orange) for right-deflecting ramps
    // Cool colors (blue) for left-deflecting ramps
    Color fill_color = (ramp->dir == RAMP_RIGHT)
        ? (Color){255, 160, 80, 255}   // Orange
        : (Color){80, 160, 255, 255};  // Sky blue

    Color line_color = (ramp->dir == RAMP_RIGHT)
        ? (Color){200, 100, 40, 255}   // Dark orange
        : (Color){40, 100, 200, 255};  // Dark blue

    // Draw filled triangle wedge
    // Three vertices: top of ramp, bottom of ramp, corner
    Vector2 v1 = { ramp->x1, ramp->y1 };  // Top of ramp line
    Vector2 v2 = { ramp->x2, ramp->y2 };  // Bottom of ramp line

    // Third vertex is the corner that completes the wedge
    // For RAMP_RIGHT: bottom-left corner (x1, y2)
    // For RAMP_LEFT: bottom-right corner (x2, y2)
    // Actually, we want the corner below the higher point
    Vector2 v3;
    if (ramp->dir == RAMP_RIGHT) {
        v3 = (Vector2){ ramp->x1, ramp->y2 };  // Below the top point
    } else {
        v3 = (Vector2){ ramp->x1 + ramp->width, ramp->y2 };  // Below the top point
    }

    // DrawTriangle expects vertices in counter-clockwise order
    // Check winding and swap if needed
    float cross = (v2.x - v1.x) * (v3.y - v1.y) - (v2.y - v1.y) * (v3.x - v1.x);
    if (cross > 0) {
        DrawTriangle(v1, v2, v3, fill_color);
    } else {
        DrawTriangle(v1, v3, v2, fill_color);
    }

    // Draw ramp surface line with thickness for emphasis
    DrawLineEx(v1, v2, 4.0f, line_color);

    // Draw subtle highlight on top edge
    Vector2 highlight_offset = { ramp->nx * 2.0f, ramp->ny * 2.0f };
    Vector2 h1 = { v1.x + highlight_offset.x, v1.y + highlight_offset.y };
    Vector2 h2 = { v2.x + highlight_offset.x, v2.y + highlight_offset.y };
    Color highlight = (Color){255, 255, 255, 80};
    DrawLineEx(h1, h2, 2.0f, highlight);
}
// }}}

// {{{ ramp_render_mirrored
void ramp_render_mirrored(Ramp* ramp) {
    // For adversary board, ramps are visually identical but physics work in reverse
    // The rendering is the same - just call regular render
    // The collision response handles the direction appropriately
    ramp_render(ramp);
}
// }}}

// =============================================================================
// Ramp collision detection and response
// =============================================================================

// {{{ ramp_check_collision
int ramp_check_collision(Ball* ball, Ramp* ramp, float* penetration,
                         float* contact_x, float* contact_y) {
    if (!ball || !ramp) return 0;

    // Find closest point on ramp line segment to ball center
    float px, py;
    closest_point_on_segment(ball->x, ball->y,
                             ramp->x1, ramp->y1,
                             ramp->x2, ramp->y2,
                             &px, &py);

    // Calculate distance from ball center to closest point
    float dx = ball->x - px;
    float dy = ball->y - py;
    float dist_sq = dx * dx + dy * dy;
    float radius = ball->radius;

    // Check for collision
    if (dist_sq < radius * radius) {
        float dist = sqrtf(dist_sq);

        // Avoid division by zero
        if (dist < 0.0001f) {
            // Ball center is exactly on the line - push along normal
            *penetration = radius;
            *contact_x = px;
            *contact_y = py;
            return 1;
        }

        *penetration = radius - dist;
        *contact_x = px;
        *contact_y = py;
        return 1;
    }

    return 0;
}
// }}}

// {{{ ramp_resolve_collision
void ramp_resolve_collision(Ball* ball, Ramp* ramp, float penetration) {
    if (!ball || !ramp) return;

    // Push ball out along normal direction
    // Use the ramp's precomputed normal
    ball->x += ramp->nx * penetration;
    ball->y += ramp->ny * penetration;

    // Calculate velocity component along normal
    float dot_normal = ball->vx * ramp->nx + ball->vy * ramp->ny;

    // Only resolve if ball is moving into the ramp
    if (dot_normal < 0) {
        // Remove normal component with low restitution (sliding, not bouncing)
        float bounce_factor = 1.0f + RAMP_RESTITUTION;
        ball->vx -= bounce_factor * dot_normal * ramp->nx;
        ball->vy -= bounce_factor * dot_normal * ramp->ny;

        // Add velocity along ramp direction (gravity assist for sliding)
        // Use the tangent direction to push ball along ramp
        ball->vx += ramp->tx * RAMP_GRAVITY_ASSIST;
        ball->vy += ramp->ty * RAMP_GRAVITY_ASSIST;
    }
}
// }}}
