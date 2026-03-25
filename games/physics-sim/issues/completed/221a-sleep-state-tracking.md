# 221a - Ball Sleep State Tracking

## Status: completed

## Depends on

None - this is the foundational sub-issue.

## Parent Issue: 221 - Ball Sleep System

## Problem

Need to track whether each ball is sleeping (at rest) or awake (active physics).

## Implementation

### Data Structure

```c
typedef struct Ball {
    // ... existing fields ...

    // Sleep system (issue 221)
    int is_sleeping;              // 1 = sleeping, 0 = awake
    int frames_at_rest;           // Consecutive frames below velocity threshold
    float pre_sleep_velocity;     // Velocity when sleep started (for debugging)
} Ball;
```

### Constants

```c
#define SLEEP_VELOCITY_THRESHOLD 0.5f   // Below this = "at rest"
#define SLEEP_FRAME_DELAY 30            // Frames at rest before sleeping (~0.5 sec at 60fps)
#define WAKE_VELOCITY_THRESHOLD 1.0f    // Above this = instant wake
```

### Initialization

```c
void ball_init(Ball* ball) {
    // ... existing init ...
    ball->is_sleeping = 0;
    ball->frames_at_rest = 0;
    ball->pre_sleep_velocity = 0.0f;
}
```

## Behavior Rules

### Sleeping Ball Properties

| Property | Sleeping | Awake |
|----------|----------|-------|
| Gravity applied | NO | YES |
| Applies forces to others | NO | YES |
| Receives forces from others | YES | YES |
| Position updated | NO (frozen) | YES |
| Rendered | YES | YES |

### Key Insight

Sleeping balls are "frozen in place" - they don't move or push. But they CAN be pushed by awake balls, which wakes them up.

## Implementation Steps

1. Add sleep fields to Ball struct
2. Initialize sleep state on ball creation
3. Add sleep state update function (called each frame)
4. Modify physics to check sleep state
5. Add debug visualization (optional)

## Files to Modify

- `src/006-ball.h` - Add sleep fields
- `src/007-ball.c` - Initialization

## Troubleshooting

### "Ball never enters sleep state"
- Verify velocity calculation: `speed = sqrt(vx*vx + vy*vy)`
- Check threshold isn't too low (0.5 is reasonable)
- Ensure frames_at_rest increments each frame

### "Ball sleeps while visibly moving"
- Threshold may be too high
- May be measuring wrong velocity (before or after physics?)
- Check for floating point issues

### "Sleep state resets unexpectedly"
- Something is modifying is_sleeping directly
- frames_at_rest being reset incorrectly
- Collision may be waking ball briefly

## Notes

- Sleep state is binary for simplicity
- Could extend to "drowsy" intermediate state later
- frames_at_rest provides hysteresis (prevents flicker)

## Implementation Notes (2026-03-19)

### Changes Made

1. **src/006-ball.h**:
   - Added sleep system constants: `SLEEP_VELOCITY_THRESHOLD`, `SLEEP_FRAME_DELAY`, `WAKE_VELOCITY_THRESHOLD`
   - Extended Ball struct with: `is_sleeping`, `frames_at_rest`, `pre_sleep_velocity`

2. **src/007-ball.c**:
   - Updated `ball_manager_create()` to initialize sleep fields in both buffers
   - Updated `ball_manager_spawn()` to initialize sleep fields for newly spawned balls
   - Updated `ball_update_physics()` to copy sleep state and skip physics for sleeping balls
   - Added `ball_update_sleep_tracking()` helper to track frames_at_rest based on velocity
   - Called sleep tracking in both `ball_manager_update()` and `ball_update_task()`

### Design Decisions

- Sleeping balls maintain position with zero velocity (frozen in place)
- Sleep tracking runs after all collision resolution so velocity is final for the frame
- The actual transition to sleep (setting is_sleeping=1) is deferred to issue 221b
- This allows 221d (soft collision) to proceed independently since it only needs the state to exist
