# 319 - Random Ball Colors with Complementary Opponent

## Status: awaiting-work

## Depends on

None - visual feature, can be implemented independently.

## Problem

Currently both player and adversary balls use fixed colors. This makes the game feel static and doesn't provide clear visual distinction between different game sessions.

## Current Behavior

- ✓ Ball colors are randomly generated with complementary hues
- ✓ Player and adversary balls use HSV color generation
- ✗ Particle effects (death fragments, collision splashes, score ripples) still use hardcoded colors
- ✗ Particles don't match ball colors, breaking visual cohesion

## Intended Behavior

1. ✓ On game start, randomly select a color for the player's balls
2. ✓ Calculate a complementary color for the opponent's balls
3. ✓ Colors should be distinct and visually pleasing
4. ✓ Both ball types should be clearly distinguishable from each other and from the board
5. **NEW**: Particle effects should use the same colors as the balls that spawn them

## Completed Implementation

- Ball colors stored in BallManager as RGBA byte arrays (issue 319 original implementation)
- HSV generation with 180° complementary offset for adversary
- Colors applied in ball_manager_render()

## Remaining Work

### Particle Color Integration

Particles are spawned in three places in main.c:
- `particle_spawn_ripple()` - Score zone hit (should use ball color)
- `particle_spawn_fragments()` - Ball death (should use dying ball's color)
- `particle_spawn_splash()` - Ball collision (should use colliding ball's color)

### Implementation Steps

1. Update particle spawn functions to accept a color parameter
2. Pass ball colors from BallManager when spawning particles
3. Update particle rendering to use the provided color
4. Test that player/adversary particles match their respective ball colors

## Files to Modify

- `src/008-particles.h` - Add color parameter to spawn functions
- `src/009-particles.c` - Store and use color in particle rendering
- `src/001-main.c` - Pass ball colors when spawning particles

## Notes

- HSV color space is easier for generating complementary colors
- Raylib has ColorFromHSV() function
- Ball colors are stored as unsigned char[4] arrays to avoid strict aliasing
- Particle system uses double-buffering like balls
