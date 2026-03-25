# 321 - Fragment Direction Duplication

## Status: completed

## Depends on

None - independent bug fix.

## Problem

When two balls collide and both die, their explosion fragments go in the same directions instead of different directions. This makes the explosion look wrong - both balls' shards overlap instead of spreading apart.

## Root Cause

In `FRAG_TANGENT` mode (src/009-particles.c), the angle calculation was:

```c
float tangent_angle = normal_angle + 1.5708f;  // normal + 90°
outward_angle = tangent_angle + side * 1.5708f + spread;  // tangent ± 90°
```

The math: `tangent_angle ± 90° = normal_angle + 180°` or `normal_angle + 0°`

This rotated fragments back to the **normal axis**, so when two balls with opposite normals (0° and 180°) collide, both sent fragments in the same directions.

## Fix Applied

Changed FRAG_TANGENT to spread fragments around the tangent direction instead of adding ±90°:

```c
case FRAG_TANGENT:
    // "Wall" ball shatters along impact tangent direction
    // Issue 321: Fixed - spread around tangent, not ±90° which rotates to normal
    {
        // Distribute fragments evenly across ±60° spread around tangent
        float spread = ((float)spawned / (float)num_fragments - 0.5f) * 2.0f;  // -1 to 1
        float spread_angle = spread * 1.0472f;  // ±60° spread (π/3)
        outward_angle = tangent_angle + spread_angle;
    }
    break;
```

## Visual Result

- Ball A (normal 0°): fragments spread around 90° (up/down)
- Ball B (normal 180°): fragments spread around 270° (down/up)
- The two explosions now visually separate instead of overlapping

## Files Modified

- `src/009-particles.c` - Fixed FRAG_TANGENT angle calculation (lines 742-751)
