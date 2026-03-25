# Issue 701: Auto-Spawn Toggle

## Current Behavior

Balls are spawned by holding the SPACE key. The user must continuously hold
the key to spawn multiple balls, which can be tedious for extended play.

## Intended Behavior

Add an auto-spawn toggle (keyboard shortcut A) that automatically spawns
new balls as if the spacebar was held down:
1. Press A to toggle auto-spawn on/off
2. When enabled, balls spawn at the normal cooldown rate
3. Visual indicator shows auto-spawn state
4. Can still manually spawn with SPACE when auto-spawn is off

## Suggested Implementation Steps

1. Add `auto_spawn` boolean to track toggle state
2. In main loop, check for KEY_A press to toggle
3. When `auto_spawn` is true, treat it like SPACE is held
4. Add visual indicator (text or icon) showing auto-spawn state
5. Update controls panel to mention A key

## Success Criteria

- A key toggles auto-spawn on/off
- Auto-spawn respects cooldown timer
- Auto-spawn respects spawn blocking (balls in spawn area)
- Visual feedback indicates current state
- Compiles with no warnings

## Status

- [x] Complete

## Implementation Notes

Added `auto_spawn` toggle variable before main loop (src/001-main.c:149-150).

Toggle logic (lines 165-169):
- Press A to toggle auto_spawn boolean
- Logs state change to console

Spawn condition updated (line 175):
- `(IsKeyDown(KEY_SPACE) || auto_spawn)` treats auto-spawn like held SPACE

Visual feedback:
- Controls panel updated with "A - Toggle auto-spawn" entry
- "[AUTO-SPAWN ON]" indicator in green when enabled
- Startup message updated to mention A key
