# 901e - Collision Mode (Solid vs Pass-Through)

## Status: Complete

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

### Engine Architecture Note

In this engine, objects (pegs, lines, bumpers) don't collide with each other - only balls collide with objects. This means the "pass-through" behavior is automatic: rotating objects simply update their positions each frame, and there's no object-to-object collision system that would cause them to push or get stuck on static geometry.

The `is_dynamic` and `rotor_index` flags serve different purposes:
1. Identifying which objects move with rotors (for position updates)
2. Future use in ball crushing detection (901f) - to detect when a ball is between a dynamic object and a wall/static object
3. Potential future use for applying rotor velocity to ball collisions

## Implementation Steps

1. ✓ Add is_dynamic and rotor_index fields to BoardObject (`020-board-data.h:146-149`)
2. ✓ Initialize fields to 0/-1 when objects created (`021-board-data.c:349-352, 389-392`)
3. ✓ Set flags when rotor connections computed (`021-board-data.c:755-762, 787-789, 821-823`)
4. N/A - Collision filtering not needed - engine has no object-to-object collision
5. ✓ Balls collide with everything (existing behavior preserved)

## Files Modified

- `src/020-board-data.h` - Added is_dynamic and rotor_index fields to BoardObject
- `src/021-board-data.c` - Initialize fields in add_peg_ex and add_line_ex, set flags in rotor_detect_connections

## Notes

- Objects naturally pass through each other in this engine (no object-object collision)
- Dynamic flags primarily useful for 901f (ball crushing detection)
- The rotor_index allows checking if two objects belong to the same rotor

## Completion Date

Completed as part of Track B work.
