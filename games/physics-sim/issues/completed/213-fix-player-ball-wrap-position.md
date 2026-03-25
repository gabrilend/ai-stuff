# 213 - Fix Player Ball Wrap Position

## Current Behavior

Player balls wrap to `world->table_top` when exiting the bottom of the screen:

```c
// src/007-ball.c - ball_check_bounds()
if (ball->owner == OWNER_PLAYER) {
    float bottom_bound = world->adversary_table_bottom + despawn_buffer;
    if (ball->y - ball->radius > bottom_bound) {
        // BUG: Spawns at top of stage 1, not top of map
        ball->y = world->table_top - ball->radius;
    }
}
```

This causes player balls to reappear at the top of Stage 1 instead of the top of the entire map.

## Intended Behavior

Player balls should reappear at the same Y position where adversary balls disappear:

```c
// Adversary despawns when above this line:
float top_bound = world->table_top - despawn_buffer;

// Player should spawn at same position:
ball->y = world->table_top - despawn_buffer + ball->radius;
```

This creates symmetric wrapping:
- Player balls exit bottom → reappear at very top
- Adversary balls exit top → reappear at very bottom

## Fix

Change line 590 in `007-ball.c`:

```c
// Before:
ball->y = world->table_top - ball->radius;

// After:
ball->y = world->table_top - despawn_buffer + ball->radius;
```

## Testing

1. Let player ball fall through entire board and off bottom
2. Ball should reappear at the very top of the map
3. Ball should appear at same Y level where adversary balls disappear

## Implementation Notes (Complete)

**Status:** Complete

**Fix Applied:**
Changed line 590 in `src/007-ball.c`:
```c
// Before:
ball->y = world->table_top - ball->radius;

// After:
ball->y = world->table_top - despawn_buffer + ball->radius;
```

The `despawn_buffer` is `world->height`, so player balls now spawn at the very top of the scrollable map, exactly where adversary balls disappear from.
