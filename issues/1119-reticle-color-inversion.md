# 1119 - Reticle Color Inversion on Spawn

## Current Behavior

When a ball spawns, the reticle progress arc resets from full to empty. This
creates a visual "flash" or discontinuity - the arc jumps from 100% to 0%.

## Intended Behavior

Instead of resetting, the colors invert after each spawn:

**Cycle 1 (odd spawns):**
- Background: dim cyan
- Progress arc: bright cyan (fills up)

**Cycle 2 (even spawns):**
- Background: bright cyan (now full from previous cycle)
- Progress arc: dim cyan (fills up, covering the bright)

**Cycle 3:** Back to cycle 1, and so on...

This creates seamless visual continuity - the progress bar never "resets",
it just inverts and continues filling. The spawn moment is marked by the
color swap rather than a jarring empty-to-full transition.

## Visual Example

```
Cycle 1:  [====----]  bright fills dim
Spawn!
Cycle 2:  [####====]  dim fills bright (appears as bright shrinking)
Spawn!
Cycle 3:  [====----]  bright fills dim
```

## Suggested Implementation Steps

1. Track spawn count or use integer part of spawn_credits to determine phase
2. On odd phases: dim background, bright progress
3. On even phases: bright background, dim progress
4. The fractional part of credits still drives the arc angle

## Implementation Sketch

```c
int spawn_phase = (int)ball_manager->spawn_credits;
int inverted = spawn_phase % 2;

Color bg_color = inverted ? bright_cyan : dim_cyan;
Color arc_color = inverted ? dim_cyan : bright_cyan;

DrawRing(..., bg_color);
DrawRing(..., arc_color);
```

## Files to Modify

- `src/001-main.c` - Player reticle rendering section (~line 790)

## Related Issues

- 1118 - Player reticle display bug (this builds on that fix)

## Notes

Could also apply this to the adversary reticle for consistency, though the
red color scheme may need slightly different dim/bright values to look good.
