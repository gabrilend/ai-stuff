# 412 - Reticle Color Inversion on Spawn

## Status: COMPLETE

## Current Behavior

Reticle colors now invert on each spawn, creating seamless visual continuity.
The progress ring never "resets" - it just swaps colors and continues filling.

## Implementation Details

### Changes to `src/001-main.c` (Player Reticle)

```c
int spawn_phase = (int)ball_manager->spawn_credits;
int inverted = spawn_phase % 2;
float credits_frac = ball_manager->spawn_credits - spawn_phase;

Color dim_cyan = (Color){60, 80, 100, 150};
Color bright_cyan = (Color){100, 200, 255, 220};

Color bg_color = inverted ? bright_cyan : dim_cyan;
Color arc_color = inverted ? dim_cyan : bright_cyan;
```

### Changes to `src/013-adversary.c` (Adversary Reticle)

Same logic applied with red color scheme:
```c
Color dim_red = (Color){80, 60, 60, 150};
Color bright_red = (Color){255, 150, 150, 220};
```

## Visual Effect

**Cycle 1 (odd phases):**
- Background: dim color
- Progress arc: bright color (fills up)

**Cycle 2 (even phases):**
- Background: bright color (full from previous cycle)
- Progress arc: dim color (fills up, covering the bright)

The spawn moment is marked by the color swap rather than a jarring reset.

## Files Modified

- `src/001-main.c` - Player reticle rendering
- `src/013-adversary.c` - Adversary reticle rendering

## Related Issues

- 1118 - Player reticle display bug (this builds on that fix)
