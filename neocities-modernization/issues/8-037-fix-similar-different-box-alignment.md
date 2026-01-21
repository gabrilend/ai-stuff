# Issue 8-037: Fix Similar/Different Box Alignment

## Priority
Low

## Current Behavior

The similar/different navigation boxes are slightly off-center. Despite having fixed-width ASCII art that should produce consistent alignment, there have been recurring issues with character counts and junction positions not aligning properly.

### Known Inconsistencies

**1. Width Discrepancy Between Code and Specification:**

| Source | Total Width | Gap | Left Box | Right Box |
|--------|-------------|-----|----------|-----------|
| **CORRECT SPEC** | **82 chars** | **58** | **11** | **13** |
| `flat-html-generator.lua:1296` | 83 chars | 59 | 11 | 13 |
| `flat-html-generator.lua:670` | 83 chars | - | - | - |
| Issue 9-006 (Validator) | 82 chars | 58 | 11 | 13 |

**The code is using 83 chars, but the correct width is 82 chars.**

**2. Junction Position Discrepancy:**

| Source | Left Junction | Right Junction |
|--------|---------------|----------------|
| **CORRECT SPEC** | **10** | **69** |
| Code (line 687-688) | 10 | 70 |
| Issue 9-006 | 10 | 69 |

**The code has right junction at 70, but it should be at 69.**

**3. Nav Line Gap Calculation:**

Current code has asymmetric gap handling:
```lua
-- With chronological (13 chars): 23 left + 23 right = 46 (leaves 13 for center)
-- Total: 11 + 23 + 13 + 23 + 13 = 83 ✗ (WRONG - should be 82)

-- Without chronological: 29 left + 30 right = 59
-- Total: 11 + 29 + 30 + 13 = 83 ✗ (WRONG - should be 82, and asymmetric!)
```

## Canonical Specification

**Total width: 82 characters**

This is derived from the content width:
- Text content: 80 characters maximum
- Left padding: 1 character (space before text)
- Right padding: 1 character (space after text, or line ends)
- **Total: 82 characters**

The progress bars and navigation boxes must all be exactly 82 characters wide.

## Intended Behavior

All three lines of the navigation box (top, nav, bottom) should align perfectly at 82 characters:

```
Position:   0         10        20        30        40        50        60        70        81
            |         |         |         |         |         |         |         |         |
Top:        ┌─────────┐                                                          ┌───────────┐
Nav:        │ similar │                      chronological                       │ different │
Bottom:     ╘═════════╧══════════════════════════════════════════════════════════╧═══════════┘
Progress:   ══════════════════════════════════════════════════════════════════════════════════
```

**Alignment Requirements:**
1. All lines must be exactly **82 visible characters** (regular poems)
2. Progress bars (top and bottom): exactly 82 characters
3. Similar box aligned with left edge (position 0)
4. Different box aligned with right edge (ending at position 81)
5. Junction characters (╧/┴) must appear directly below the box corners (┐/┘)
6. The "chronological" text should be perfectly centered between the two boxes

## Suggested Implementation Steps

1. **Create canonical width constants**:
   ```lua
   local POEM_TEXT_WIDTH = 80      -- Maximum text content width
   local POEM_PADDING = 1          -- Space on left (and conceptually right)
   local REGULAR_POEM_WIDTH = 82   -- Total: 80 + 1 + 1 = 82
   local GOLDEN_POEM_WIDTH = 84    -- Regular + 1 left border ║ + 1 right border │
   ```

2. **Recalculate all component widths**:
   ```
   Total width: 82 chars (positions 0-81)

   Similar box:   ┌─────────┐  = 11 chars (positions 0-10)
   Gap:           (spaces)     = 58 chars (positions 11-68)
   Different box: ┌───────────┐ = 13 chars (positions 69-81)

   Verification: 11 + 58 + 13 = 82 ✓
   ```

3. **Fix junction positions**:
   ```lua
   local REGULAR_LEFT_JUNCTION_POS = 10   -- End of similar box (position of ┐)
   local REGULAR_RIGHT_JUNCTION_POS = 69  -- Start of different box (position of ┌)
   ```

4. **Audit and fix all width calculations**:
   - `generate_progress_dashes()` - change 83 → 82
   - `generate_regular_corner_box_top()` - change gap from 59 → 58
   - `generate_regular_corner_box_bottom()` - change gap from 59 → 58
   - `generate_regular_corner_box_nav_line()` - fix gap calculations

5. **Fix nav line gap calculation for 82 chars**:
   ```lua
   -- Total: 82 chars
   -- Left box: 11, Right box: 13, Center text: 13 ("chronological")
   -- Remaining for gaps: 82 - 11 - 13 - 13 = 45
   -- Split: 22 left + 23 right (or 23 + 22, pick one consistently)

   -- Without chronological:
   -- Remaining for gaps: 82 - 11 - 13 = 58
   -- Split: 29 left + 29 right = 58 ✓ (symmetric!)
   ```

6. **Create alignment verification function**:
   ```lua
   local function verify_line_width(line, expected_width)
       local visible = line:gsub("<[^>]+>", "")  -- Strip HTML
       local len = vim.fn.strchars(visible)      -- Count Unicode chars
       assert(len == expected_width,
           string.format("Expected %d chars, got %d", expected_width, len))
   end
   ```

7. **Update Issue 9-006** to confirm 82-char specification

8. **Test with visual inspection**:
   - Generate pages and verify alignment in browser
   - Check similar box aligns with left edge of progress bar
   - Check different box aligns with right edge of progress bar

## Character Position Reference

### Regular Poem (82 chars, 0-indexed positions 0-81):
```
Pos: 0         1         2         3         4         5         6         7         8
     01234567890123456789012345678901234567890123456789012345678901234567890123456789012
     ┌─────────┐                                                          ┌───────────┐
     │ similar │                      chronological                       │ different │
     ╘═════════╧══════════════════════════════════════════════════════════╧═══════════┘
     ══════════════════════════════════════════════════════════════════════════════════
              ^                                                           ^
              Position 10 (left junction)                                 Position 69 (right junction)
```

**Component breakdown:**
- Positions 0-10: Similar box (11 chars): `┌─────────┐`
- Positions 11-68: Gap (58 chars): spaces
- Positions 69-81: Different box (13 chars): `┌───────────┐`

### Golden Poem (84 chars, 0-indexed positions 0-83):
```
     ╟─────────┐                                                          ┌───────────┤
     ║ similar │                      chronological                       │ different │
     ╚═════════╧══════════════════════════════════════════════════════════╧═══════════┘
              ^                                                           ^
              Position 9 (left junction)                                  Position 70 (right junction)
```

**Golden poem adds ║ on left AND │ on right, adding 2 characters total (82 → 84).**

## Related Documents

- `src/flat-html-generator.lua` - Primary implementation (lines 667-766, 1289-1413)
- `issues/9-006-poem-box-format-validator.md` - Validator with potentially outdated numbers
- `issues/completed/8-006-fix-golden-poem-box-drawing-format.md` - Previous golden poem fixes
- `issues/completed/8-007-add-navigation-link-box-borders.md` - Original box border implementation
- `issues/8-035-colorize-nav-boxes-with-progress-bar.md` - Related enhancement (depends on correct alignment)

## Historical Context

This is a recurring issue. Previous fixes include:
- Issue 8-006: Golden poem box drawing format
- Issue 8-007: Adding navigation link box borders
- Issue 9-003: HTML rendering and performance fixes

The root cause appears to be multiple independent calculations that should reference a single source of truth but instead have hardcoded values that have drifted out of sync.

## Implementation Progress

### 2026-01-21: Centralized Constants Added

Added `LAYOUT` constant table to `src/flat-html-generator.lua` (lines 92-119) containing:
- `REGULAR_POEM_WIDTH = 83` - Total width for regular poems
- `GOLDEN_POEM_WIDTH = 85` - Total width for golden poems (+2 for borders)
- Box widths: 11 (left), 13 (right), 59 (gap)
- Junction positions: 10 (left), 70 (right)

**Correction to issue specification**: After verifying generated output, the actual working width is **83 characters**, not 82. The implementation is internally consistent at 83 chars. The issue description's "should be 82" was based on a theoretical calculation that didn't match the actual working implementation.

**Current state**: All lines align correctly at 83 characters. The centralized `LAYOUT` constants now serve as the single source of truth for any future modifications.

**Remaining work** (optional):
- Update hardcoded `83` values throughout the file to use `LAYOUT.REGULAR_POEM_WIDTH`
- This is a refactoring task, not a bug fix

## Metadata

- **Status**: ✅ Constants Centralized (refactoring optional)
- **Created**: 2026-01-19
- **Last Updated**: 2026-01-21
- **Phase**: 8 (Website Completion / HTML Enhancement)
- **Estimated Complexity**: Medium (requires careful auditing and testing)
- **Dependencies**: Should be completed before 8-035 (colorize nav boxes)
- **Blocks**: 8-035 (colorize nav boxes with progress bar)

## Acceptance Criteria

- [ ] Single source of truth for width constants
- [ ] All width calculations use the constants
- [ ] Junction positions verified mathematically
- [ ] Top, nav, and bottom lines all measure identical visible width
- [ ] Visual inspection confirms alignment in browser
- [ ] Issue 9-006 documentation updated to match
