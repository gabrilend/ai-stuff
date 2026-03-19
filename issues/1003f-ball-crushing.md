# 1305f - Ball Stress and Crushing

## Status: Open

## Parent Issue: 1305 - Rotor System

## Problem

When a ball is trapped between a rotating structure and static geometry (or two moving structures), it should be crushed and destroyed rather than causing physics glitches.

## Crushing Conditions

A ball should be crushed when:
1. It's in contact with both a dynamic (rotating) object and a static object
2. The dynamic object is applying force that compresses the ball
3. The ball cannot escape (velocity constrained in all directions)

## Stress Metric

```c
typedef struct Ball {
    // ... existing fields ...
    float stress;              // Accumulated stress
    float stress_threshold;    // Crushing threshold
} Ball;
```

### Stress Calculation

Each frame while ball is in "compressed" state:
```c
stress += compression_force * delta_time;

if (stress > stress_threshold) {
    crush_ball(ball);
}
```

### Compression Detection

Ball is compressed when:
- Contact with 2+ objects
- Contact normals point towards each other (ball is between them)
- At least one contact is with a dynamic object applying force

```c
int is_compressed(Ball* ball) {
    if (ball->contact_count < 2) return 0;

    // Check if contact normals oppose each other
    float dot = dot_product(contact[0].normal, contact[1].normal);
    return dot < -0.5f;  // Normals roughly opposite
}
```

## Crushing Effect

When ball is crushed:
1. Spawn particle burst (squish effect)
2. Play sound effect (optional)
3. Remove ball from simulation
4. No score awarded (crushing is neutral/penalty)

## Implementation Steps

1. Add stress tracking to Ball struct
2. Implement compression detection in collision response
3. Accumulate stress while compressed
4. Trigger crushing when threshold exceeded
5. Add crushing particle effect
6. Test with rotor crushing ball against wall

## Files to Modify

- `src/006-ball.h` - Add stress field
- `src/007-ball.c` - Stress calculation, crushing logic
- `src/009-particles.c` - Crushing particle effect

## Notes

- Same crushing system used for track movers (issue 1306)
- Stress should decay when ball is free (not compressed)
- Consider brief invulnerability after near-crush to prevent frustrating deaths
