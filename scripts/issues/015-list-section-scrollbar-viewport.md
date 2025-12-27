# Issue 015: List Section Scrollbar Viewport

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** High

---

## Current Behavior

The TUI menu in `menu.lua` renders all items in a section sequentially. When a "list" type section (like "Issues to Process" in issue-splitter.sh) has many items, it consumes the entire screen space, pushing the content preview panel and command preview below the visible area.

---

## Intended Behavior

- List sections should have a configurable `max_visible` height (default: 10 lines)
- When the list has more items than `max_visible`, display a scrollbar in the rightmost column
- The viewport should scroll automatically to keep the selected item visible
- Navigation (j/k) within the section should update the scroll offset
- The scrollbar should indicate current position within the list
- Space below the list is preserved for description, content preview, and command preview panels

---

## Suggested Implementation Steps

1. Add section-level configuration in `menu.lua` state:
   - `section_scroll_offset` table: section_id -> scroll offset
   - `section_max_visible` table: section_id -> max visible items
   - Default `max_visible` to nil (unlimited) for backward compatibility

2. Add API function `menu.set_section_max_visible(section_id, max_visible)`:
   - Stores max_visible in `state.section_max_visible[section_id]`
   - Initializes `state.section_scroll_offset[section_id] = 0`

3. Modify `render_section()` to support viewport:
   - Check if section has `max_visible` configured
   - If so, only render items from `scroll_offset` to `scroll_offset + max_visible - 1`
   - Call `render_scrollbar()` for the section's row range
   - Return correct row count (max_visible, not total items)

4. Modify navigation functions (`nav_up`, `nav_down`) to update scroll offset:
   - When cursor moves above visible range, decrease scroll offset
   - When cursor moves below visible range, increase scroll offset
   - Keep cursor within visible range

5. Update `issue-splitter.sh` to call `menu_set_section_max_visible "files" 10`

---

## Related Documents

- `libs/menu.lua` - TUI menu component
- `issue-splitter.sh` - Primary consumer of this feature
- `libs/lua-menu.sh` - Bash wrapper for menu.lua

---

## Acceptance Criteria

- [x] List sections with many items show scrollbar
- [x] Selected item always visible in viewport
- [x] Scrollbar thumb moves proportionally with scroll position
- [x] Navigation works smoothly within and between sections
- [x] Content preview panel has ~10-15 lines of space below list
- [x] Backward compatible: sections without max_visible work as before

---

## Implementation Notes

**Changes made:**

1. `libs/menu.lua`:
   - Added `section_scroll_offset` and `section_max_visible` state tables
   - Added `ensure_item_visible()` function to auto-scroll viewport
   - Modified `render_section()` to render only visible items with scrollbar
   - Added `menu.set_section_max_visible()` API function
   - Updated navigation functions to call `ensure_item_visible()`
   - Section title shows `[X-Y of Z]` indicator when viewport active

2. `libs/lua-menu.sh`:
   - Added `MENU_SECTION_MAX_VISIBLE` associative array
   - Added `menu_set_section_max_visible()` bash function
   - Updated JSON builder to include `max_visible` in section config

3. `issue-splitter.sh`:
   - Added `menu_set_section_max_visible "files" 10` after files section creation
