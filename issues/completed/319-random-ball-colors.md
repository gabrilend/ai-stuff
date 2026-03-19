# 319 - Random Ball Colors with Complementary Opponent

## Status: completed

## Depends on

None - visual feature, can be implemented independently.

## Problem

Currently both player and adversary balls use fixed colors. This makes the game feel static and doesn't provide clear visual distinction between different game sessions.

## Implementation Summary

Ball colors are now fully integrated with particle effects:

1. Ball colors randomly generated on game start using HSV color space
2. Player and adversary use 180° complementary hues
3. Particle effects (ripples, fragments, splash) now use ball colors

### Changes Made

**src/001-main.c:**
- Modified zone dispatch callback to retrieve ball color from BallManager
- Ripple particles use ball color brightened by blending with white (for visibility)
- Fragment particles use ball color directly when ball dies
- Splash particles use ball color on collision

### Code Pattern

```c
// Get ball color from manager
Ball* ball = &ball_manager->balls_current[i];
unsigned char* ball_rgba = (ball->owner == OWNER_PLAYER)
    ? ball_manager->player_color
    : ball_manager->adversary_color;
Color ball_color = (Color){ball_rgba[0], ball_rgba[1], ball_rgba[2], ball_rgba[3]};

// Use for particles
particle_spawn_ripple(mgr, x, y, ball_color);
particle_spawn_fragments(mgr, x, y, fragments, ball_color);
particle_spawn_splash(mgr, x, y, count, ball_color);
```

### Visual Results

- Player balls spawn player-colored particles
- Adversary balls spawn complementary-colored particles
- Ripples are brightened for visibility against backgrounds
- Death fragments clearly show which ball type died

## Files Modified

- `src/001-main.c` - Pass ball colors to particle spawn functions

## Notes

- Particle spawn functions already accepted Color parameters
- Main change was passing dynamic ball colors instead of hardcoded values
- Ripple brightness done via `ColorLerp(ball_color, WHITE, 0.3f)` to ensure visibility
