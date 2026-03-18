# 1221 - Slot-Based World Layout System

## Status: Complete

## Problem

Current world layout uses ad-hoc positioning with many interdependent calculations:
- `table_bottom`, `adversary_table_top`, `adversary_table_bottom` calculated separately
- Gate margins, spawn positions, and board positions all need manual coordination
- Stage expansion requires complex shifting and recalculation
- Bugs arise from mismatched position calculations (e.g., adversary reticle not visible)

## Proposed Solution

Create a **slot-based layout system** where boards, gates, and reticles occupy predefined vertical slots with standard heights.

### Slot Types and Standard Heights

| Slot Type | Height | Contents |
|-----------|--------|----------|
| Reticle | ~100px | Spawn area with visual reticle |
| Board | 1000px | Peg grid (20 rows × 50px) |
| Gates | ~90px | Score zones + margins (50px + 40px gate + 50px margin) |

### Initial Layout (Top to Bottom)

```
┌─────────────────────┐
│   Player Reticle    │  y = 0 to 100
├─────────────────────┤
│                     │
│   Player Board      │  y = 100 to 1100
│                     │
├─────────────────────┤
│   Gates (1x)        │  y = 1100 to 1190
├─────────────────────┤
│                     │
│  Adversary Board    │  y = 1190 to 2190
│                     │
├─────────────────────┤
│ Adversary Reticle   │  y = 2190 to 2290
└─────────────────────┘
```

### After Purchasing Stage 2 (Top to Bottom)

```
┌─────────────────────┐
│   Player Reticle    │
├─────────────────────┤
│   Player Board 1    │  (original)
├─────────────────────┤
│   Gates (1x)        │  (new)
├─────────────────────┤
│   Player Board 2    │  (new)
├─────────────────────┤
│   Gates (2x)        │  (original, now doubled)
├─────────────────────┤
│  Adversary Board 2  │  (new, mirrored)
├─────────────────────┤
│   Gates (1x)        │  (new)
├─────────────────────┤
│  Adversary Board 1  │  (original)
├─────────────────────┤
│ Adversary Reticle   │
└─────────────────────┘
```

### Key Concepts

1. **Slot Registry**: Central data structure tracking all slots and their positions
2. **Standard Heights**: Each slot type has a fixed height, making calculations trivial
3. **Symmetric Expansion**: Player and adversary sides expand symmetrically from the center
4. **Multiplier Inheritance**: Central gates get multiplied point values with each expansion

## Suggested Implementation Steps

1. Create `Slot` struct with type, y_start, y_end, multiplier, content pointer
2. Create `SlotManager` to track and organize slots
3. Implement `slot_manager_calculate_positions()` to set all y-coordinates
4. Refactor world initialization to use slot system
5. Refactor reticle positioning (player and adversary) to use slots
6. Refactor gate positioning to use slots
7. Update stage expansion to insert new slots and recalculate
8. Remove ad-hoc position calculations

## Benefits

- Single source of truth for vertical positioning
- Stage expansion becomes slot insertion + recalculation
- No more position calculation bugs
- Clear mental model for world structure
- Easy to add new slot types (e.g., bonus zones, obstacles)

## Files to Create/Modify

- `src/038-slot-manager.h` - Slot types and manager API (new)
- `src/039-slot-manager.c` - Implementation (new)
- `src/001-main.c` - Use slot manager for world setup
- `src/013-adversary.c` - Get spawn_y from slot manager
- `src/015-stage.c` - Use slot manager for expansion

## Related Issues

- 1220 - Pegs not anchored to guard rails (positioning bugs)
- Current adversary reticle visibility bug (spawn_y calculation)

## Implementation Notes

**Completed:**
- Created `src/038-slot-manager.h` with slot types, SlotManager struct, and API
- Created `src/039-slot-manager.c` with full implementation
- Added to Makefile's GAME_SRCS
- Integrated into main.c for world initialization:
  - Player/adversary board bounds from slot_manager
  - Spawn Y positions from slot_manager_get_player_spawn_y/adversary
  - Gate bounds from slot_manager_get_gates_bounds
- Fixed adversary reticle positioning bug (was using garbage spawn_y values)
- Fixed slot_manager_expand to produce correct symmetric layout

**Standard slot heights:**
- SLOT_RETICLE_HEIGHT: 150px
- SLOT_BOARD_HEIGHT: 1000px
- SLOT_GATE_HEIGHT: 40px + 50px margins = 140px total

**Follow-up work:**
- on_stage_purchased callback should call slot_manager_expand() and use slot positions
- Current expansion still uses ad-hoc calculations; slot_manager_expand logic is ready

## Notes

This is a significant refactor that would replace the current positioning system. Should be implemented as a Phase 13 feature after Phase 12 (Editor Modularization) is complete.
