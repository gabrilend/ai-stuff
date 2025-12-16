# Issue 8-007: Add Box-Drawing Borders Around Navigation Links

## Current Behavior

Navigation links (similar/different) appear as the last line inside the golden poem box, but they visually blend with the poem content:

```
║ poem content here                                                              │
║ more poem content                                                              │
║ similar                                                                different │
╚═══────────────────────────────────────────────────────────────────────────────────┘
```

The navigation links don't stand out from the surrounding poem text, making them harder to identify as interactive elements.

## Intended Behavior

Add a horizontal separator line above the navigation links using box-drawing junction characters to visually distinguish them from the poem content:

```
║ poem content here                                                              │
║ more poem content                                                              │
╟────────────────────────────────────────────────────────────────────────────────┤
║ similar                                                                different │
╚═══────────────────────────────────────────────────────────────────────────────────┘
```

### Suggested Box-Drawing Characters

- `╟` (U+255F) - double vertical and single right (left junction, connects ║ to ─)
- `┤` (U+2524) - light vertical and left (right junction, connects ─ to │)
- `─` (U+2500) - light horizontal (separator line between junctions)

### Width Considerations

The separator line width should be:
- Interior width: 80 characters (matching content area)
- With padding: `╟` + space + 80×`─` + space + `┤` = 84 total

Or without padding spaces in the separator:
- `╟` + 82×`─` + `┤` = 84 total

### Option B: Corner Boxes (Recommended)

Create two separate "corner boxes" for the navigation links with empty space between:

```
║ poem content here                                                                │
╟───────────┐                                                            ┌─────────┤
║ similar   │                                                            │different │
╚═══════════╧════════════════════════════════════════════════════════════╧═════════┘
```

This design:
- Creates distinct visual containers for each link
- Leaves the center completely empty/open
- Single space of padding after "similar" and before "different", then walls
- Uses proper junction characters for double-line connections in bottom border

Characters for corner boxes:
- `╟` (U+255F) - left junction (connects ║ to ─)
- `┐` (U+2510) - top-right corner of "similar" box
- `┌` (U+250C) - top-left corner of "different" box
- `┤` (U+2524) - right junction (connects ─ to │)
- `│` (U+2502) - vertical walls of corner boxes
- `╧` (U+2567) - bottom junction for double lines (═ section) - **IMPORTANT**
- `┴` (U+2534) - bottom junction for single lines (─ section)

### Progress Bar Interaction

The bottom border uses a progress visualization (═ transitioning to ─). The vertical walls of the corner boxes connect to the bottom border and must use the correct junction:

**Critical**: Use `╧` (not `┴`) when connecting to double lines:
- ✅ Correct: `════╧════` (╧ connects single vertical to double horizontal)
- ❌ Wrong: `════┴════` (┴ is for single horizontal only)

Junction selection based on position:
- "similar" box junction (left side, early in progress): likely in ═ section → use `╧`
- "different" box junction (right side, late in progress): check if in ═ or ─ section → use `╧` or `┴` accordingly

## Suggested Implementation Steps

### Option A: Simple Horizontal Separator

1. [ ] Add separator line generation before navigation links in `apply_golden_poem_formatting()`
2. [ ] Format: `╟` + 82×`─` + `┤` (84 chars total)
3. [ ] Insert separator as second-to-last line (before nav links)
4. [ ] Test visual alignment with various poem lengths

### Option B: Corner Boxes (Recommended)

1. [ ] Calculate box widths:
   - "similar" box: `║` + space + "similar" + space + `│` = 11 chars
   - "different" box: `│` + space + "different" + space + `│` = 13 chars
   - Total nav line: 84 chars (matching golden poem width)

2. [ ] Generate separator line with corner boxes:
   - Left portion: `╟` + (similar_width - 2)×`─` + `┐`
   - Center gap: spaces to fill remaining width
   - Right portion: `┌` + (different_width - 2)×`─` + `┤`

3. [ ] Generate navigation link line:
   - `║` + ` similar ` + `│` + center_gap_spaces + `│` + ` different ` + `│`

4. [ ] Modify `generate_progress_dashes()` to insert junctions:
   - Calculate junction positions (where vertical walls meet bottom border)
   - Insert `╧` at "similar" box position (in ═ section)
   - Insert `╧` or `┴` at "different" box position (depends on progress)

5. [ ] Test with various progress percentages to verify junction character selection

## Dependencies

- Requires Issue 8-006 (golden poem box-drawing) to be complete (DONE)
- Works within existing `apply_golden_poem_formatting()` function

## Quality Assurance Criteria

- [x] Separator line is exactly 84 characters wide
- [x] Junction characters connect properly to side borders
- [x] Navigation links remain clearly readable
- [x] Visual distinction from poem content is clear
- [x] Regular (non-golden) poems are not affected

## Related Issues

- **Issue 8-006**: Fix golden poem box-drawing format (COMPLETED - provides foundation)

## Technical Notes

**Unicode junction characters**:
- `╟` (U+255F) - double vertical and single right
- `┤` (U+2524) - light vertical and left
- `─` (U+2500) - light horizontal
- `┬` (U+252C) - light down and horizontal (optional, for vertical divider)
- `┴` (U+2534) - light up and horizontal (optional, for bottom junction)
- `╧` (U+2567) - up double and horizontal single (optional, for ═ section junction)

**Implementation location**: `src/flat-html-generator.lua` in `apply_golden_poem_formatting()` function

## Implementation Notes

### Functions Added/Modified in `src/flat-html-generator.lua`:

1. **`generate_corner_box_separator()`** - New function (lines 585-598)
   - Generates separator line: `╟─────────┐` + 60 spaces + `┌───────────┤`
   - Total: 84 characters (11 + 60 + 13)

2. **`generate_corner_box_nav_line(similar_link, different_link)`** - New function (lines 600-630)
   - Generates navigation line with vertical walls
   - Format: `║ similar │` + 60 spaces + `│ different │`
   - Handles HTML links while measuring visible text for padding

3. **`generate_progress_dashes()`** - Modified to accept `has_corner_boxes` parameter
   - Inserts junction characters at positions 9 (similar box) and 70 (different box)
   - Uses `╧` when junction is in progress (═) section
   - Uses `┴` when junction is in remaining (─) section

4. **`apply_golden_poem_formatting()`** - Modified signature
   - Now accepts `similar_link` and `different_link` separately
   - Adds separator line before navigation
   - Uses corner box format for golden poems

5. **`format_content_with_warnings()`** - Updated signature to match

### Tested Scenarios:
- Low progress (poem 78, ~4%): Both junctions use `┴`
- High progress (poem 6366, ~97%): Both junctions use `╧`
- Regular (non-golden) poems: Unchanged, no corner boxes

---

**ISSUE STATUS: COMPLETED**

**Created**: 2025-12-15

**Completed**: 2025-12-15

**Phase**: 8 (Website Completion)

**Priority**: Low - Visual enhancement
