# 1118 - Player Reticle Display Bug

## Current Behavior

The player's spawn reticle flashes between blue and green states:
- Blue state: shows spawn progress, but goes by too quickly
- Green state: persists for a moment

This creates a jarring, flickering visual experience.

## Intended Behavior

The player's reticle should feel smooth and fluid like the adversary's reticle:
- Adversary reticle: single red color with gradient, smooth progress indication
- Player reticle should: use single color with gradient, smooth progress fill

## Analysis

The adversary reticle works well because it uses a continuous visual (red with gradient) rather than discrete color states. The player reticle appears to switch between "charging" (blue) and "ready" (green) states in a way that feels abrupt.

## Suggested Implementation Steps

1. Find player reticle rendering code
2. Compare with adversary reticle rendering
3. Change player reticle to use similar single-color gradient approach
4. Use blue/cyan gradient for player (matching player ball color scheme)
5. Show progress as fill amount rather than color change

## Files to Modify

- `src/001-main.c` - Likely contains reticle rendering in the render section

## Related Issues

- None

## Notes

The adversary reticle implementation can serve as a reference for the fix.
