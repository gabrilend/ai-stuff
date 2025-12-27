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

- [ ] Attempting to modify a disabled item triggers a red flash
- [ ] Flash is brief (100-200ms per pulse, 2 pulses default)
- [ ] Item returns to disabled (gray) state after flash
- [ ] Flash function is generic and reusable: `menu_flash_rejection(item_id)`
- [ ] Optional: dependency reason displayed briefly after rejection

---

## Notes

*This is a standard UX pattern - rejected actions should have visible feedback. Silent rejection leaves users uncertain whether their input was received.*

*The flash duration should be fast enough to feel responsive but slow enough to be perceptible. 2 pulses at 100ms each (total 400ms including gaps) is a reasonable starting point.*

*Consider accessibility: users with photosensitivity may need an option to disable flashing. Alternative feedback could be a brief color change without animation, or an audio cue.*
