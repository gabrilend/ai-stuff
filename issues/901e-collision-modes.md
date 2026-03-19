# 901e - Collision Mode (Solid vs Pass-Through)

## Status: Open

## Parent Issue: 901 - Rotor System

## Problem

When a rotating structure passes through the space occupied by a static (non-connected) object, it should pass through like a ghost rather than colliding. This prevents rotors from "pushing" or getting stuck on static geometry.

## Behavior Rules

| Interaction | Collision? |
|-------------|------------|
| Ball vs Rotating Object | YES - ball bounces/gets pushed |
| Rotating Object vs Connected Object | NO - they move together |
| Rotating Object vs Static Object | NO - pass through (ghost) |
| Ball vs Static Object | YES - normal collision |

## Implementation

### Collision Flags

Add flags to track object state:
```c
typedef struct BoardObject {
    // ... existing fields ...
    int is_dynamic;        // Part of a rotor/mover
    int rotor_index;       // Which rotor this belongs to (-1 if none)
} BoardObject;
```

### Collision Check Modification

```c
int should_collide(Object* a, Object* b) {
    // Ball collides with everything
    if (is_ball(a) || is_ball(b)) return 1;

    // Two objects on same rotor don't collide
    if (a->rotor_index == b->rotor_index && a->rotor_index >= 0) return 0;

    // Dynamic object vs static object: no collision
    if (a->is_dynamic != b->is_dynamic) return 0;

    return 1;
}
```

### Visual Feedback

When rotating arm passes through static object:
- Optional: Brief transparency/glow effect
- Or: No visual change (cleaner)

## Implementation Steps

1. Add is_dynamic and rotor_index fields to BoardObject
2. Set flags when rotor connections computed
3. Modify collision detection to check flags
4. Test with rotor arm passing through static pegs
5. Verify balls still collide with everything

## Files to Modify

- `src/020-board-data.h` - Add object flags
- `src/007-ball.c` - Collision filtering
- `src/001-main.c` - Object-object collision filtering if applicable

## Notes

- This is critical for playable rotor mechanics
- Without pass-through, rotors would get stuck constantly
- Consider if user wants "solid mode" rotors as option
