# Issue 003: Flash Disabled Items on Interaction Attempt

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement (TUI Library)
**Priority:** Medium
**Dependencies:** None

---

## Current Behavior

When a menu item is disabled (grayed out due to a dependency), attempting to interact with it does nothing. There is no visual feedback indicating that the action was rejected.

Example:
```
  Output Delay (sec): [ 5]     ← disabled because Streaming is off
```

User presses a key to change the value. Nothing happens. User may be confused about why their input was ignored.

---

## Intended Behavior

When a user attempts to modify a disabled item, the item flashes red briefly to indicate the action was rejected.

Example sequence:
```
Initial state (disabled):
  Output Delay (sec): [ 5]

User tries to set value to 3:
  Output Delay (sec): RED[ 5]RED   ← flashes red 1-2 times

Returns to disabled state:
  Output Delay (sec): [ 5]
```

This provides immediate, clear feedback: "I heard you, but no."

---

## Suggested Implementation Steps

### TUI Library Enhancement (libs/tui.lua or libs/lua-menu.sh)

1. **Add rejection flash function**:
   ```lua
   menu_flash_rejection(item_id, flash_count, interval_ms)
   -- Defaults: flash_count=2, interval_ms=100
   -- Flashes item in red, then returns to disabled (gray) state
   ```

2. **Hook into input handler** - When processing user input:
   ```lua
   function handle_input(key, current_item)
       if item_is_disabled(current_item) then
           menu_flash_rejection(current_item.id)
           return  -- reject input
       end
       -- normal input processing...
   end
   ```

3. **Consider showing dependency reason** - Optionally, after the flash, briefly show why the item is disabled:
   ```
   Output Delay (sec): [ 5]  ← "Requires Streaming mode"
   ```
   This could appear for 1-2 seconds then fade, or show on a status line.

4. **Distinguish flash types** - The library should support different flash semantics:
   - Red flash = rejection (you can't do that)
   - Yellow flash = warning (are you sure?)
   - Green flash = success (action completed)
   - Custom color flash = application-defined

---

## Visual Behavior

| User Action | Item State | Result |
|-------------|------------|--------|
| Try to toggle disabled checkbox | Disabled | 2x red flash, no state change |
| Try to edit disabled flag value | Disabled | 2x red flash, no state change |
| Try to select disabled radio option | Disabled | 2x red flash, no state change |

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua` (core TUI rendering)
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` (menu system)
- Issue 002: Elaborate Skeletal Issues Option (uses flash for auto-enable feedback)

---

## Acceptance Criteria

- [x] Attempting to modify a disabled item triggers a red flash
- [x] Flash is brief (100-200ms per pulse, 2 pulses default)
- [x] Item returns to disabled (gray) state after flash
- [x] Flash function is generic and reusable: `menu.flash_item(item_id, count, color, interval_ms)`
- [ ] Optional: dependency reason displayed briefly after rejection (deferred - already shown in description area)

---

## Notes

*This is a standard UX pattern - rejected actions should have visible feedback. Silent rejection leaves users uncertain whether their input was received.*

*The flash duration should be fast enough to feel responsive but slow enough to be perceptible. 2 pulses at 100ms each (total 400ms including gaps) is a reasonable starting point.*

*Consider accessibility: users with photosensitivity may need an option to disable flashing. Alternative feedback could be a brief color change without animation, or an audio cue.*

---

## Implementation Notes

*Completed 2025-12-26*

### Changes Made

Modified `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` to flash red when attempting to interact with disabled items:

1. **`menu.toggle()`** (line ~2077): Flash red 2x before returning nil
2. **`menu.set_checkbox()`** (line ~2138): Flash red 2x before returning false
3. **`menu.unset_checkbox()`** (line ~2175): Flash red 2x before returning false
4. **`menu.handle_flag_left()`** (line ~2285): Flash red 2x before returning false
5. **`menu.handle_flag_right()`** (line ~2307): Flash red 2x before returning false
6. **`menu.handle_flag_digit()`** (line ~2330): Flash red 2x before returning false
7. **`menu.handle_flag_backspace()`** (line ~2378): Flash red 2x before returning false

### Design Decision

Reused `menu.flash_item()` from Issue 002a rather than creating a separate `menu_flash_rejection()` function. The existing function is sufficiently generic and reduces code duplication. Called with parameters: `item_id, 2, "red", 100` (2 pulses, red color, 100ms interval).

### Dependency Reason Display

The optional "display dependency reason after rejection" is already covered by existing functionality - when an item is disabled, its dependency reason is shown in the description area below the menu. No additional implementation needed.
