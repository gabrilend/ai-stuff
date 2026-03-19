# 221e - Stress Source Distinction (Static vs Dynamic)

## Status: blocked

## Depends on

- 221d (Soft collision response) - provides collision framework for stress tracking

## Dependents

- 901f (Ball crushing) - needs stress distinction to know what can crush
- 902g (Track ball interaction) - needs stress distinction for crushing

## Parent Issue: 221 - Ball Sleep System

## Problem

When implementing ball crushing (901f, 902g), we need to distinguish between:
- **Static stress**: Weight of other balls, pile pressure → Should NOT crush
- **Dynamic stress**: Rotor, mover, moving objects → SHOULD crush

## Key Insight

Balls piling up in a bucket should rest peacefully, not get crushed by their own weight. Only active mechanical forces (rotors, movers) should cause crushing.

## Implementation

### Stress Tracking

```c
typedef struct Ball {
    // ... existing fields ...

    // Stress tracking (issue 221e)
    float static_stress;      // From ball weight, static geometry
    float dynamic_stress;     // From rotors, movers
    float stress_decay_rate;  // How fast stress decreases when free
} Ball;
```

### Stress Accumulation

```c
void accumulate_static_stress(Ball* ball, float pressure) {
    ball->static_stress += pressure;
    // Cap to prevent overflow, but no crushing check
    if (ball->static_stress > MAX_STATIC_STRESS) {
        ball->static_stress = MAX_STATIC_STRESS;
    }
}

void accumulate_dynamic_stress(Ball* ball, float pressure) {
    ball->dynamic_stress += pressure;

    // Dynamic stress CAN cause crushing
    if (ball->dynamic_stress > CRUSH_THRESHOLD) {
        crush_ball(ball);
    }
}
```

### Source Detection

```c
void handle_collision(Ball* ball, Object* other) {
    float pressure = calculate_collision_pressure(ball, other);

    if (other->is_dynamic) {  // Rotor or mover
        accumulate_dynamic_stress(ball, pressure);
    } else if (is_ball(other)) {
        // Ball-ball collision is static stress
        accumulate_static_stress(ball, pressure);
    } else {
        // Static geometry (walls, pegs)
        accumulate_static_stress(ball, pressure);
    }
}
```

### Stress Decay

```c
void update_ball_stress(Ball* ball, float delta_time) {
    // Static stress decays when not under pressure
    if (ball->contact_count == 0) {
        ball->static_stress *= 0.9f;  // Decay
    }

    // Dynamic stress decays faster (momentary force)
    ball->dynamic_stress *= 0.8f;

    // Minimum threshold
    if (ball->static_stress < 0.01f) ball->static_stress = 0.0f;
    if (ball->dynamic_stress < 0.01f) ball->dynamic_stress = 0.0f;
}
```

## Crushing Only From Dynamic Sources

```c
void check_ball_crushing(Ball* ball) {
    // ONLY check dynamic stress
    if (ball->dynamic_stress > CRUSH_THRESHOLD) {
        // Ball trapped between rotor and wall, or similar
        crush_ball(ball);
        return;
    }

    // Static stress is ignored for crushing
    // Ball can have infinite static stress without crushing
}
```

## Visual Feedback (Optional)

```c
void render_ball(Ball* ball) {
    // Normal render
    draw_ball(ball);

    // Static stress visual: slight squish or color shift
    if (ball->static_stress > STRESS_VISUAL_THRESHOLD) {
        float squish = ball->static_stress / MAX_STATIC_STRESS;
        // Slightly compress ball sprite vertically
    }

    // Dynamic stress visual: red glow or warning
    if (ball->dynamic_stress > CRUSH_THRESHOLD * 0.5f) {
        // Ball is in danger of crushing
        draw_danger_indicator(ball);
    }
}
```

## Implementation Steps

1. Add stress fields to Ball struct
2. Implement stress accumulation with source detection
3. Implement stress decay
4. Modify crushing check to only use dynamic stress
5. Test: pile of balls should NOT crush
6. Test: rotor pressing ball against wall SHOULD crush

## Files to Modify

- `src/006-ball.h` - Add stress fields
- `src/007-ball.c` - Stress accumulation, crushing check

## Troubleshooting

### "Balls crush from weight"
- Static stress being treated as dynamic
- Check collision source detection
- Verify ball-ball collisions use static stress

### "Balls don't crush from rotor"
- Rotor not marked as dynamic object
- Dynamic stress not accumulating
- Crush threshold too high

### "Stress never decays"
- Decay function not being called
- Decay rate too low
- Ball constantly in contact

### "Crushing too sensitive"
- CRUSH_THRESHOLD too low
- Dynamic stress accumulates too fast
- Reduce collision pressure calculation

### "Crushing not sensitive enough"
- CRUSH_THRESHOLD too high
- Dynamic stress decays too fast
- Ball escapes before threshold reached

## Integration with Sleep System

- Sleeping balls have zero stress accumulation (no movement = no pressure)
- When ball wakes, stress starts from zero
- Sleeping ball hit by rotor: wakes AND accumulates dynamic stress

## Notes

- This is foundational for 901f and 902g
- Static stress visual feedback is optional polish
- Consider: static stress could cause temporary "flatten" visual without crushing
