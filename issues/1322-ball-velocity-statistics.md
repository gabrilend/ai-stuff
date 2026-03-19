# 1322 - Ball Velocity Statistics

## Status: Open

## Parent Phase: Phase 13

## Problem

Balls moving too fast can tunnel through thin geometry (lines, zone boundaries) without triggering collision or scoring. Need to track velocity statistics to:
1. Identify if tunneling is causing missed gate detection
2. Inform future physics decisions (substeps, swept collision)
3. Debug edge cases in ball behavior

## Current Behavior

- No tracking of ball velocities over time
- No maximum velocity recorded
- No way to diagnose tunneling issues

## Intended Behavior

- Track maximum velocity observed per session
- Track velocity at moment of gate passage (or near-miss)
- Debug overlay showing velocity statistics
- Log warnings when velocity exceeds safe threshold

## Velocity Statistics

```c
typedef struct VelocityStats {
    // All-time maximums this session
    float max_speed;           // Highest speed observed (magnitude)
    float max_vx;              // Highest horizontal velocity
    float max_vy;              // Highest vertical velocity

    // Context for max speed
    float max_speed_x;         // Position when max speed observed
    float max_speed_y;
    int max_speed_frame;       // Frame number

    // Gate-related
    float avg_gate_entry_speed;  // Average speed when entering gates
    float max_gate_entry_speed;  // Fastest gate entry
    int gate_entries;            // Count for averaging

    // Near-miss tracking (ball passed through zone bounds without detection)
    int potential_tunnels;       // Count of suspicious fast passes
} VelocityStats;

static VelocityStats velocity_stats = {0};
```

## Tunneling Detection

A ball might tunnel through a zone if it moves more than the zone height in a single frame:

```c
#define ZONE_HEIGHT 43.0f  // Approximate zone height in pixels

void check_potential_tunnel(Ball* ball, float dt) {
    float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);
    float distance_per_frame = speed * dt;

    if (distance_per_frame > ZONE_HEIGHT * 0.5f) {
        // Ball could skip over half the zone in one frame
        velocity_stats.potential_tunnels++;

        // Log warning
        TraceLog(LOG_WARNING, "Potential tunnel: speed=%.1f, dist/frame=%.1f at (%.0f, %.0f)",
                 speed, distance_per_frame, ball->x, ball->y);
    }
}
```

## Safe Velocity Threshold

Based on zone dimensions and frame rate:

```c
// At 60 FPS, dt ≈ 0.0167s
// Zone height ≈ 43px
// To ensure ball center passes through zone, max safe distance/frame = zone_height / 2

// max_safe_distance = 43 / 2 = 21.5px per frame
// max_safe_speed = 21.5 / 0.0167 ≈ 1290 px/s

#define MAX_SAFE_SPEED 1200.0f  // Conservative estimate

void clamp_ball_velocity(Ball* ball) {
    float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);

    if (speed > MAX_SAFE_SPEED) {
        float scale = MAX_SAFE_SPEED / speed;
        ball->vx *= scale;
        ball->vy *= scale;
    }
}
```

## Debug Overlay

Toggle with a keybind (F10?) to show velocity stats:

```c
void render_velocity_debug(void) {
    int y = 100;
    DrawText(TextFormat("Max Speed: %.0f px/s", velocity_stats.max_speed), 10, y, 16, WHITE);
    y += 20;
    DrawText(TextFormat("Max Vy: %.0f px/s", velocity_stats.max_vy), 10, y, 16, WHITE);
    y += 20;
    DrawText(TextFormat("Gate Entry Avg: %.0f px/s", velocity_stats.avg_gate_entry_speed), 10, y, 16, WHITE);
    y += 20;
    DrawText(TextFormat("Potential Tunnels: %d", velocity_stats.potential_tunnels), 10, y, 16,
             velocity_stats.potential_tunnels > 0 ? RED : GREEN);
}
```

## Recording Statistics

```c
// In ball_update_task, after physics integration
void record_velocity_stats(Ball* ball) {
    float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);

    if (speed > velocity_stats.max_speed) {
        velocity_stats.max_speed = speed;
        velocity_stats.max_vx = ball->vx;
        velocity_stats.max_vy = ball->vy;
        velocity_stats.max_speed_x = ball->x;
        velocity_stats.max_speed_y = ball->y;
    }
}

// When ball enters gate zone
void record_gate_entry_speed(Ball* ball) {
    float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);

    if (speed > velocity_stats.max_gate_entry_speed) {
        velocity_stats.max_gate_entry_speed = speed;
    }

    // Running average
    velocity_stats.gate_entries++;
    float n = (float)velocity_stats.gate_entries;
    velocity_stats.avg_gate_entry_speed =
        velocity_stats.avg_gate_entry_speed * ((n - 1) / n) + speed / n;
}
```

## Future Physics Considerations

If tunneling is confirmed as an issue, solutions include:

1. **Velocity Clamping** - Cap maximum speed (simple, may feel unnatural)
2. **Substeps** - Multiple physics steps per frame for fast balls
3. **Swept Collision** - Check entire path, not just endpoints
4. **Thicker Zones** - Expand zone bounds to catch fast balls

```c
// Substep example
void ball_update_with_substeps(Ball* ball, float dt) {
    float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);
    float distance = speed * dt;

    // Calculate substeps needed
    int substeps = 1;
    if (distance > MAX_SAFE_DISTANCE) {
        substeps = (int)ceilf(distance / MAX_SAFE_DISTANCE);
    }

    float sub_dt = dt / substeps;
    for (int i = 0; i < substeps; i++) {
        ball_physics_step(ball, sub_dt);
        ball_check_collisions(ball);
        ball_check_zones(ball);
    }
}
```

## Implementation Steps

1. Add VelocityStats struct
2. Add recording in ball_update_task
3. Add gate entry speed recording
4. Add potential tunnel detection with warnings
5. Add debug overlay (F10 toggle)
6. Test with high-bounce scenarios
7. Analyze data to determine if tunneling is significant
8. Implement fix if needed (clamp, substeps, or swept collision)

## Files to Modify

- `src/006-ball.h` - Could add per-ball velocity tracking
- `src/007-ball.c` - Add stats recording in update
- `src/001-main.c` - Add debug overlay rendering

## Notes

- Start with just tracking, don't change physics yet
- Collect data first, then decide on solution
- Per-ball tracking could help identify specific problematic scenarios
- Frame rate drops could temporarily increase tunneling risk
