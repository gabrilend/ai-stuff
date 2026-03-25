# Issue 811: Escape Key Behavior and Q to Quit

## Current Behavior

- ESC always closes the game (WindowShouldClose)
- ESC also closes upgrade menu (but game closes anyway)
- No dedicated quit key

## Intended Behavior

- ESC closes upgrade panel if open, does NOT close game
- ESC closes game only if upgrade panel is already closed
- Q key closes the game at any time

## Suggested Implementation Steps

1. Track whether ESC was consumed by upgrade menu this frame
2. Modify main loop to check if upgrade menu consumed ESC before calling WindowShouldClose
3. Add Q key check to close window
4. Use raylib's CloseWindow or set a quit flag

## Status

Complete

## Implementation Notes

- SetExitKey(0) disables raylib's default ESC-to-quit behavior
- upgrade_manager_handle_input() returns 1 if ESC was consumed closing the menu
- Main loop checks: Q always quits, ESC quits only if not consumed, window close button quits
- Changed main loop from `while (!WindowShouldClose())` to `while (!should_quit)`
