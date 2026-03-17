# Issue 902: Spawn Buffering System

## Current Behavior

Moving the mouse rapidly while holding SPACE can spawn many balls at once by
changing the spawn X position to bypass spawn blocking. Each new position may
not have a blocking ball, allowing rapid spawning.

The current cooldown system resets on each spawn, but doesn't account for:
1. Blocked spawns (spawn opportunity is "lost")
2. Rapid position changes bypassing blocking

## Intended Behavior

Implement a spawn credit/buffer system that standardizes ball output rate:
1. Credits accumulate over time at a fixed rate
2. Each spawn attempt consumes one credit
3. Blocked spawns don't consume credits (saved for later)
4. Credits cap at a maximum (e.g., 3-5) to prevent burst spawning
5. Rate is consistent regardless of mouse movement patterns

This system will also support future upgrade mechanics where spawn rate
can be modified.

## Suggested Implementation Steps

1. Add `spawn_credits` float that accumulates over time
2. Add `spawn_rate` constant (credits per second, e.g., 2.0)
3. Add `max_spawn_credits` cap (e.g., 3.0)
4. Each frame: `spawn_credits += spawn_rate * dt` (capped)
5. On spawn: consume 1.0 credit
6. Only spawn if `spawn_credits >= 1.0` AND not blocked
7. Remove old cooldown system (replaced by credits)

## Design Notes

Current system:
- SPAWN_COOLDOWN = time between spawns
- Cooldown resets on each spawn
- Blocked spawns still trigger cooldown (wastes opportunity)

New system:
- Credits accumulate passively
- Spawning costs 1 credit
- Blocked spawns don't cost credits
- Cap prevents infinite credit accumulation

Example with 2.0 rate:
- After 0.5 seconds: 1.0 credit
- Spawn: 0.0 credits
- After 0.5 seconds: 1.0 credit
- Blocked: still 1.0 credit (saved)
- After 0.25 seconds: 1.5 credits (can spawn again)

## Success Criteria

- Consistent spawn rate regardless of mouse movement
- Blocked spawns don't penalize the player
- Credit cap prevents burst spawning
- System supports future rate upgrades
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Added spawn credit system to BallManager (src/006-ball.h, src/007-ball.c).

New fields and constants:
- `spawn_credits` field in BallManager (starts at 1.0)
- `SPAWN_RATE = 10.0f` credits per second
- `MAX_SPAWN_CREDITS = 3.0f` cap

Updated functions:
- `ball_manager_create()`: Initialize spawn_credits to 1.0
- `ball_manager_update_cooldown()`: Accumulate credits (capped)
- `ball_manager_can_spawn()`: Check credits >= 1.0 instead of cooldown
- `ball_manager_reset_cooldown()`: Consume 1 credit on spawn

Behavior changes:
- Credits accumulate continuously (10/sec = one every 0.1s)
- Blocked spawns don't consume credits (saved for later)
- Cap prevents storing more than 3 spawns
- Visual cooldown indicator still works for feedback

**Fix (Session 2):** Made spawn blocking position-independent.
Original issue: Moving mouse horizontally bypassed spawn blocking because
the check was against the current spawn_x position.

Changed `ball_manager_spawn_blocked()` to check vertical distance only.
If ANY ball is within spawn_margin of SPAWN_Y, spawning is blocked regardless
of horizontal position. This ensures consistent spawn rate whether mouse
is moving or stationary.

**Fix (Session 3):** Restored circular distance checking.
The Y-only approach was too conservative - balls had to fall far enough
vertically before clearing, even if they had horizontal velocity taking
them away from the spawn point.

Changed `ball_manager_spawn_blocked()` to use Euclidean distance:
- `dist_sq = dx*dx + dy*dy` (circular check centered on spawn point)
- Balls moving left/right exit blocking zone quickly via horizontal motion
- Balls still spawn at exact reticle center (spawn_x, spawn_y)
- Spawn margin remains 1.5x ball radius

This allows more natural spawning when balls have initial horizontal velocity,
while still preventing overlap at the spawn point.
