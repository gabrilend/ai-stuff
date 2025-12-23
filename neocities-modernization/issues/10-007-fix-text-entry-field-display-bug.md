# 10-007: Fix Text-Entry Field Display Bug

## Status
- **Phase**: 10
- **Priority**: High
- **Type**: Bug Fix
- **Status**: Open
- **Created**: 2025-12-23

## Current Behavior

Text-entry fields in the TUI display the internal `value:width` format instead of just the value:

```
Options
├─ Test poem ID: [       1:5]     <- Shows ":5" (the field width)
├─ Thread count: [       8:3]     <- Shows ":3" (the field width)
└─ Output delay: [       5:2]     <- Shows ":2" (the field width)
```

The `:width` suffix is internal metadata used to specify the display width of the field but should not be visible to users.

## Intended Behavior

Text-entry fields should display only the value:

```
Options
├─ Test poem ID: [       1]       <- Just the value
├─ Thread count: [       8]       <- Just the value
└─ Output delay: [       5]       <- Just the value
```

The width metadata should be used internally for:
- Field sizing (how wide the `[...]` box is)
- Input validation (max digits)
- Display padding (right-align within field)

## Root Cause Analysis

The "flag" type in the TUI library uses format `"value:width"` (e.g., `"3:2"` means value=3, width=2 digits):

From `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (lines 703-706):
```bash
menu_add_item "streaming" "parallel" "Parallel Jobs" "flag" "3:2" \
    "Max concurrent Claude calls (type 1-10)" "" "--parallel"
```

The bug is likely in one of these locations:

### Possible Location 1: Implementation (run.sh or TUI setup)
The implementation may be passing the value incorrectly or using the wrong type.

### Possible Location 2: Library Rendering (menu.tui)
The library's rendering function may not be properly parsing the `value:width` format and stripping the width before display.

Expected library behavior:
```lua
-- Parse "3:2" into value=3, width=2
local value, width = string.match(flag_value, "^(%d+):(%d+)$")
if not width then
    -- Fallback: no width specified, use default
    value = flag_value
    width = 3
end
-- Display with padding: "[  3]" (right-aligned in 3-char field)
```

## Implementation Steps

### Phase 1: Locate the Bug

1. [ ] Search for flag/text-entry rendering in menu.tui library
2. [ ] Check if `value:width` parsing exists
3. [ ] If parsing exists, check if display function uses raw value or parsed value
4. [ ] Identify exact line(s) where bug occurs

### Phase 2: Fix Library (if bug is in menu.tui)

5. [ ] Add or fix `value:width` parsing function:
   ```lua
   -- {{{ function parse_flag_value
   local function parse_flag_value(flag_str)
       local value, width = string.match(flag_str, "^(.+):(%d+)$")
       if value and width then
           return value, tonumber(width)
       end
       return flag_str, 3  -- default width
   end
   -- }}}
   ```

6. [ ] Update rendering function to use parsed value only
7. [ ] Update field width to use parsed width for padding

### Phase 3: Fix Implementation (if bug is in run.sh/main.lua)

8. [ ] Ensure flag items use correct format `"value:width"`
9. [ ] Or, if library expects separate parameters, use those instead

### Phase 4: Test

10. [ ] Test that fields display value only (no `:width`)
11. [ ] Test that field width still affects display sizing
12. [ ] Test that typing updates value correctly
13. [ ] Test that command preview shows correct numeric values
14. [ ] Regression test: ensure fix doesn't break other TUI features

## Files to Investigate

- `/home/ritz/programming/ai-stuff/libs/menu.tui` - TUI library source
- `/home/ritz/programming/ai-stuff/neocities-modernization/run.sh` - Implementation
- `/home/ritz/programming/ai-stuff/neocities-modernization/src/main.lua` - Interactive mode
- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` - Working reference

## Notes

This bug has reportedly been fixed in other systems, suggesting:
1. The fix is known and documented somewhere
2. The fix may need to be ported to this project's implementation
3. Or, the menu.tui library has been updated but not all consumers updated

Check git history of menu.tui and issue-splitter.sh for recent fixes related to flag display.

## Related Documents

- Issue 10-004: Command preview (consumes flag values)
- Issue 10-005: CLI flag support (flags should match displayed values)
- Issue 10-006: Checkbox conversions (related UI element types)

---
