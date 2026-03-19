# 1320 - Remove Adversary Board Tinting

## Status: Open

## Parent Phase: Phase 13

## Dependencies

- Issue 1319 (Material type selector) - materials provide visual distinction

## Problem

The adversary board is currently tinted red to distinguish it from the player's board. With the material system (issue 1319), objects already have distinct colors based on their material type. The red tint is redundant and muddies the material colors.

## Current Behavior

- Adversary board objects rendered with red tint overlay
- Material colors are distorted by the tint
- Ice looks pink, stone looks red, etc.

## Intended Behavior

- No color tinting on adversary board
- Objects render with their true material colors
- Both boards look visually identical (distinguished by position only)

## Implementation

```c
// Remove or disable the tinting code
void render_stage(Stage* stage, int owner) {
    // OLD: Apply tint for adversary
    // Color tint = (owner == OWNER_ADVERSARY) ? RED_TINT : WHITE;

    // NEW: No tinting, use material colors directly
    for (int i = 0; i < stage->object_count; i++) {
        render_object(&stage->objects[i]);  // Uses material display_color
    }
}
```

## Alternative Distinction Methods

If visual distinction is still needed between boards:

1. **Position is enough** - Player board on top, adversary on bottom
2. **Subtle border** - Thin colored border around board area
3. **Background shade** - Slightly different background (not object tint)
4. **Label** - Small "PLAYER" / "ADVERSARY" text near board

```c
// Option: Subtle background difference instead of object tinting
void render_board_background(int owner) {
    Color bg = (owner == OWNER_PLAYER)
        ? (Color){ 20, 22, 25, 255 }    // Slightly blue-ish
        : (Color){ 25, 20, 20, 255 };   // Slightly red-ish (very subtle)

    DrawRectangle(board_x, board_y, BOARD_WIDTH, BOARD_HEIGHT, bg);
}
```

## Files to Modify

- `src/015-stage.c` (or wherever board rendering happens)
- Remove tint color application to adversary objects

## Notes

- Material colors are designed to be recognizable (ice=blue, rubber=red)
- Red tint makes all materials look similar
- Players learn board positions quickly, tinting unnecessary
- Cleaner visual appearance overall
