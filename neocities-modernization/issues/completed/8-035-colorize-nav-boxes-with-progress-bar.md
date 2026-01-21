# Issue 8-035: Colorize Nav Boxes According to Progress Bar Position

## Priority
Low

## Current Behavior

The progress bar at the top and bottom of each poem page shows chronological position using colored `═` characters (progress) and uncolored `─` characters (remaining). The "similar" and "different" navigation boxes sit within this progress bar structure but are always rendered in the default uncolored style, regardless of whether the progress bar has reached their position.

Current visual structure (82 characters wide):
```
┌─────────┐                                                          ┌───────────┐
│ similar │                    chronological                         │ different │
╘═════════╧══════════════════════════════════════════════════════════╧═══════════┘
```

The boxes use these junction characters that connect to the progress bar:
- Left box "similar": positions 0-10, junction at position 10
- Right box "different": positions 69-81, junction at position 69

Currently, only the bottom line's junction characters (`╧` vs `┴`) change based on progress position. The box walls and top edges remain uncolored.

## Intended Behavior

The "similar" and "different" box borders should progressively colorize as the progress bar reaches them, creating a visual "filling" effect that matches the poem's semantic color.

### Similar Box (left, positions 0-10):

**Progress at 0%:** Box completely uncolored
```
┌─────────┐
│ similar │
└─────────┴
```

**Progress at ~3 chars (positions 0-2 filled):** Left wall colored, top 3 chars colored
```
┌──       (first 3 of top colored)
║         (left wall colored)
╘══       (first 3 of bottom colored - current behavior)
```

**Progress past position 10:** Entire box colored including right wall
```
┌─────────┐  (all colored)
║ similar │  (left wall colored, right wall colored when progress >= 10)
╘═════════╧  (all colored with junction)
```

### Different Box (right, positions 69-81):

Same logic applied starting when progress reaches position 69:
- When progress reaches 69: left wall of "different" box starts coloring
- When progress reaches 81: entire "different" box is colored

### Color Application:

Use the same semantic color applied to the progress bar (`COLOR_CONFIG` colors: red, blue, green, purple, orange, yellow, gray).

## Suggested Implementation Steps

1. **Read and understand progress bar generation** in `src/flat-html-generator.lua`:
   - `generate_progress_dashes()` (lines ~666-891)
   - `generate_regular_corner_box_top()` (lines ~1289-1301)
   - `generate_regular_corner_box_nav_line()` (lines ~1368-1413)
   - `generate_regular_corner_box_bottom()` (lines ~1305-1314)

2. **Create helper function** `calculate_box_coloring(progress_chars, box_start, box_end)`:
   - Returns table with: `left_wall_colored`, `top_chars_colored`, `right_wall_colored`, `bottom_chars_colored`
   - Logic: if `progress_chars > box_start`, start coloring from left
   - Count of colored chars = `min(progress_chars - box_start, box_width)`

3. **Modify `generate_regular_corner_box_top()`**:
   - Accept `progress_chars` and `semantic_color` parameters
   - Calculate how many chars of `─────────` should be colored based on progress
   - Apply color wrapping to the appropriate portion
   - Handle corner characters (`┌`, `┐`) colorization

4. **Modify `generate_regular_corner_box_nav_line()`**:
   - Accept progress parameters
   - Colorize `│` wall characters when progress reaches them
   - Left wall at position 0 (similar) and position 69 (different)
   - Right wall at position 10 (similar) and position 81 (different)

5. **Test with various progress percentages**:
   - 0% (no coloring)
   - 5% (~4 chars, partial similar box)
   - 15% (~12 chars, full similar box)
   - 85% (~70 chars, starts coloring different box)
   - 100% (everything colored)

6. **Ensure golden poems are handled**:
   - Golden poems have different junction positions (9 and 69)
   - Apply same logic with adjusted positions

7. **Update aria-labels** if applicable for accessibility

## Technical Notes

### Character Positions Reference:
```
Position:   0         10        20        30        40        50        60        70        81
            |         |         |         |         |         |         |         |         |
Top:        ┌─────────┐                                                          ┌───────────┐
Nav:        │ similar │                   chronological                          │ different │
Bottom:     ╘═════════╧══════════════════════════════════════════════════════════╧═══════════┘
```

### Box Drawing Characters to Colorize:
- Similar box: `┌` (pos 0), `─────────` (pos 1-9), `┐` (pos 10), `│` (walls), `╘`, `═`, `╧`
- Different box: `┌` (pos 69), `───────────` (pos 70-80), `┐` (pos 81), `│` (walls), `╧`, `═`, `┘`

### Color Wrapping Pattern:
```lua
local colored_char = string.format('<font color="%s"><b>%s</b></font>', color_hex, char)
```

## Related Documents

- `src/flat-html-generator.lua` - Primary implementation file
- `issues/completed/8-006-fix-golden-poem-box-drawing-format.md` - Golden poem box drawing work
- `issues/completed/8-007-add-navigation-link-box-borders.md` - Navigation box border implementation

## Implementation Progress

### 2026-01-21: Implemented

**Changes made:**

1. **`src/flat-html-generator.lua`**:
   - Added `colorize_char()` helper function (line 1374-1382) for wrapping characters in color tags
   - Modified `generate_regular_corner_box_top()` (line 1386-1422) to accept `progress_chars` and `hex_color` parameters
     - Left box (positions 0-10) characters colorize progressively as progress reaches them
     - Right box (positions 70-82) characters colorize when progress passes position 70
   - Modified `generate_regular_corner_box_nav_line()` (line 1490-1542) to accept `progress_chars` and `hex_color`
     - Wall characters `│` at positions 0, 10, 70, 82 colorize based on progress position
   - Updated call sites in `format_single_poem_with_progress_and_color()` (lines 1739-1746)
   - Updated call sites in chronological generation (lines 2362-2368)

2. **Effil worker thread** (similar/different page generation):
   - Added local `color_char()` helper function (line 2907-2912)
   - `nav_top` generation (lines 2914-2930) uses progressive colorization
   - `nav_mid` generation (lines 2932-2939) colorizes wall characters at correct positions

**Visual behavior:**
- At 0% progress: No box characters colored
- Progress fills left box first (positions 0-10)
- Middle gap (positions 11-69) is spaces (no visible change)
- Progress fills right box last (positions 70-82)
- Uses poem's semantic color (red, blue, green, purple, orange, yellow, gray)

## Metadata

- **Status**: ✅ Complete
- **Created**: 2026-01-19
- **Completed**: 2026-01-21
- **Phase**: 8 (Website Completion / HTML Enhancement)
- **Estimated Complexity**: Medium (multiple functions to modify, careful character positioning)
- **Dependencies**: None (standalone visual enhancement)
