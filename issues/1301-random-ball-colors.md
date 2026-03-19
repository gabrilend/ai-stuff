# 1301 - Random Ball Colors with Complementary Opponent

## Status: Open

## Problem

Currently both player and adversary balls use fixed colors. This makes the game feel static and doesn't provide clear visual distinction between different game sessions.

## Current Behavior

- Player balls have a fixed color
- Adversary balls have a fixed color
- Colors don't change between games

## Intended Behavior

1. On game start, randomly select a color for the player's balls
2. Calculate a complementary color for the opponent's balls
3. Colors should be distinct and visually pleasing
4. Both ball types should be clearly distinguishable from each other and from the board

## Implementation Steps

1. Add color generation function that picks random hue with good saturation/value
2. Implement complementary color calculation (180 degrees on color wheel)
3. Store player/adversary ball colors in game state
4. Apply colors during ball rendering
5. Consider adding slight variation per ball for visual interest

## Files to Modify

- `src/001-main.c` or game state - Store ball colors
- `src/007-ball.c` - Apply colors during rendering

## Notes

- HSV color space is easier for generating complementary colors
- Raylib has ColorFromHSV() function
- May want to avoid colors too close to peg/board colors
