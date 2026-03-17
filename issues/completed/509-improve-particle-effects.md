# Issue 509: Improve Particle Effects

## Current Behavior

Particle effects are:
- Gray/muted colors (zone colors not showing well)
- Uniform appearance
- Moderate velocity
- Fixed size (3.0f radius)
- Simple physics

## Intended Behavior

Enhanced particle effects:
1. **Colorful**: Random varied colors, more vibrant
2. **Faster**: Higher initial velocity for more dramatic burst
3. **Smaller**: Smaller particle size for finer effect
4. **Iridescent**: Color shifts over lifetime for sparkle effect
5. **Better physics**: More dynamic movement

## Suggested Implementation Steps

1. Reduce particle radius:
   - Change PARTICLE_RADIUS from 3.0f to 1.5f or 2.0f

2. Increase burst speed:
   - Change PARTICLE_BURST_SPEED from 120.0f to 200.0f or higher

3. Randomize colors in particle_spawn_burst():
   - Add random hue variation to base color
   - Or generate completely random bright colors
   - Ensure colors are vibrant (high saturation)

4. Implement iridescence (color shift over lifetime):
   - In particle_system_render(), modify color based on life ratio
   - Shift hue as particle ages
   - Could use HSV to RGB conversion

5. Add velocity variation:
   - Randomize initial speed per particle (not just direction)
   - Add slight random offset to spawn position

6. Consider adding:
   - Size variation per particle
   - Alpha randomization
   - Sparkle effect (occasional bright flash)

7. Test visual appearance

8. Test compilation with no warnings

## Design Notes

For iridescence, can shift hue over lifetime:
- Start: base color
- Middle: shifted hue
- End: different shifted hue

HSV to RGB conversion:
- H: 0-360 (hue)
- S: 0-1 (saturation, keep high for vibrant)
- V: 0-1 (value/brightness)

Random color generation:
- Random hue (0-360)
- High saturation (0.8-1.0)
- High value (0.8-1.0)

## Success Criteria

- Particles are visually vibrant and colorful
- Each burst has varied colors
- Particles are smaller but still visible
- Particles move faster for dramatic effect
- Color shifts over lifetime (iridescence)
- Overall effect is "juicy" and satisfying
- Compiles with no warnings

## Related Documents

- [008-particles.h](../src/008-particles.h)
- [009-particles.c](../src/009-particles.c)

## Dependencies

- None (visual enhancement)

## Status

- [x] Complete

## Implementation Log

### Constants Changed
- PARTICLE_RADIUS: 3.0f → 2.0f (smaller particles)
- PARTICLE_BURST_SPEED: 120.0f → 220.0f (faster burst)
- PARTICLE_GRAVITY: 300.0f → 200.0f (slower fall, more hang time)
- PARTICLE_LIFETIME: 0.8f → 1.0f (longer visible)
- Added PARTICLE_SPEED_VARIANCE: 80.0f (random speed variation)
- Added PARTICLE_HUE_SHIFT: 60.0f (iridescence shift degrees)

### New Helper Functions
- `hsv_to_rgb()`: Converts HSV color to RGB for color manipulation
- `rgb_to_hsv()`: Converts RGB to HSV for extracting hue/saturation/value

### Iridescence (particle_system_render)
- Converts particle color to HSV on each render
- Shifts hue progressively as particle ages (creates rainbow shimmer)
- Boosts saturation and brightness for more vibrant appearance
- Amount of shift controlled by PARTICLE_HUE_SHIFT constant

### Randomization (particle_spawn_burst)
- Position: Random offset ±2 pixels from spawn center
- Angle: Random jitter ±0.25 radians from base angle
- Speed: Random ±PARTICLE_SPEED_VARIANCE from base speed
- Color: Random hue variation ±30 degrees from base color
- Lifetime: Random +0-0.3 seconds variation

Each particle in a burst now has unique color, speed, and trajectory.
