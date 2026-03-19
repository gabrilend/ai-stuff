# 407 - Hide Game UI Keybind

## Status: Open

## Parent Phase: See phase progress file

## Problem

During gameplay, the UI elements (score display, keybind reference) can obstruct the view or distract from watching ball physics. Need a way to temporarily hide these elements.

## Current Behavior

- Top-left: Score, credits, and stats always visible
- Top-right: Keybind reference always visible
- No way to hide UI during gameplay

## Intended Behavior

- Press `H` to toggle UI visibility
- Hidden state persists until toggled again
- UI elements affected:
  - Top-left score/stats panel
  - Top-right keybind reference
- NOT affected (always visible):
  - Board and game objects
  - Balls and particles
  - Spawn reticle

## Implementation

```c
// In game state
int ui_visible = 1;  // Default: visible

// In input handling
if (IsKeyPressed(KEY_H)) {
    ui_visible = !ui_visible;
}

// In render function
if (ui_visible) {
    render_score_panel();
    render_keybind_reference();
}
```

## Files to Modify

- `src/001-main.c` - Add ui_visible state and H key handling
- Render functions for score panel and keybind reference

## Notes

- Useful for screenshots and video recording
- Could add fade animation for polish
- Consider saving preference to config (or always reset to visible on launch)
