# Issue 004: Scrollbar for Lists and Content Preview Panels

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement (TUI Library)
**Priority:** Medium
**Dependencies:** None

---

## Current Behavior

### Problem 1: Issue List

The "Issues to Process" list section displays items in a single column. When there are many items, the list either:
- Overflows the visible area without indication
- Truncates without showing how many items remain
- No scrollbar or position indicator

Users cannot easily see where they are in a long list or how many items exist beyond the visible area.

### Problem 2: Content Preview Panel

The text output field below the selection (content preview) only shows the first part of the selected file. When viewing an issue file, users see the beginning but cannot scroll to read:
- The full problem description
- Implementation steps
- Acceptance criteria
- Previous analysis sections

This makes it harder to think about each issue during selection - users must mentally work with incomplete information.

---

## Intended Behavior

Implement adaptive list display with multi-column support and scrollbar fallback:

### Layout Decision Flow

```
Screen width ≥ (longest item × 2)?
    YES → Use multi-column layout (as many columns as fit)
    NO  → Screen width ≥ longest item?
            YES → Single column, scrollbar if items exceed height
            NO  → Truncate items with "...", scrollbar if needed
```

### Priority 1: Multi-Column Layout

If screen width fits at least 2 columns (2 × longest item width), display in multiple columns:

```
┌─ Issues to Process ────────────────────────────────────────────┐
│ [x] 101-parse-header.md       [x] 105-validate-input.md       │
│ [x] 102-parse-body.md         [ ] 106-error-handling.md       │
│ [x] 103-extract-data.md       [x] 107-output-format.md        │
│ [ ] 104-transform.md          [x] 108-logging.md              │
└────────────────────────────────────────────────────────────────┘
```

Column count determined by:
- Screen width
- Longest item in list (must fit without truncation)
- Minimum column width threshold

### Priority 2: Scrollbar Fallback

If screen is too small for even a single column showing all items, display a scrollbar:

```
┌─ Issues to Process (12 items) ─────────────────────────┐
│ [x] 101-parse-header.md                               ▲│
│ [x] 102-parse-body.md                                 █│
│ [x] 103-extract-data.md                               █│
│ [ ] 104-transform.md                                  ░│
│ [x] 105-validate-input.md                             ░│
│ [ ] 106-error-handling.md                             ▼│
└─────────────────────────────────── [6/12 visible] ─────┘
```

Scrollbar elements:
- `▲` / `▼` arrows at top/bottom
- `█` filled blocks for visible region
- `░` empty blocks for non-visible region
- Position indicator: `[6/12 visible]` or `[1-6 of 12]`

### Priority 3: Content Preview Panel Scrollbar

The content preview panel (text output field below selection) should have its own scrollbar when content exceeds visible height:

```
┌─ Content Preview ──────────────────────────────────────────────┐
│ # Issue 103: Parse Header Structure                           ▲│
│                                                                █│
│ **Phase:** 1 - Foundation                                      █│
│ **Type:** Feature                                              █│
│                                                                ░│
│ ---                                                            ░│
│                                                                ░│
│ ## Current Behavior                                            ░│
│                                                                ░│
│ The parser does not yet handle header structures...            ▼│
└──────────────────────────────────── [lines 1-10 of 87] ────────┘
```

**Scrollbar behavior:**
- Appears automatically when content exceeds panel height
- Hidden when content fits (no wasted gutter space)
- Shows line range indicator: `[lines 1-10 of 87]`

**Navigation (when preview panel is focused or via modifier key):**
- `j`/`k` or arrows: scroll by line
- `Page Up`/`Page Down`: scroll by panel height
- `g`/`G`: jump to top/bottom of content
- `Space`: page down (vim-style)

**Focus model options:**
- Option A: Tab switches focus between list and preview panel
- Option B: Shift+j/k scrolls preview while list retains focus
- Option C: Preview auto-scrolls to keep "current section" visible based on cursor position in list

This enables users to read the full issue content during selection, helping them think through each issue before deciding whether to include it.

---

## Suggested Implementation Steps

### TUI Library Enhancement

1. **Calculate optimal column count**:
   ```lua
   function calc_list_columns(items, available_width, min_col_width)
       local max_item_width = get_max_item_width(items)
       local col_width = math.max(max_item_width, min_col_width)
       local cols = math.floor(available_width / col_width)
       return math.max(1, cols), col_width
   end
   ```

2. **Multi-column rendering**:
   ```lua
   function render_list_multicolumn(items, cols, col_width, visible_rows)
       -- Fill columns top-to-bottom, then left-to-right
       -- Or: left-to-right, then top-to-bottom (user preference?)
   end
   ```

3. **Scrollbar widget**:
   ```lua
   function render_scrollbar(total_items, visible_start, visible_count, height)
       -- Returns array of characters: ▲, █, ░, ▼
   end
   ```

4. **Scroll position tracking**:
   ```lua
   list_state = {
       scroll_offset = 0,
       selected_index = 0,
       visible_count = 10
   }
   ```

5. **Keyboard navigation**:
   - `j`/`k` or arrows: move selection (scroll if at edge)
   - `Page Up`/`Page Down`: scroll by visible_count
   - `Home`/`End`: jump to first/last item
   - In multi-column: `h`/`l` or left/right arrows to move between columns

6. **Responsive reflow** - On terminal resize:
   - Recalculate column count
   - Preserve selection position
   - Adjust scroll offset if needed

---

## Column Fill Order

Two options for how items flow into columns:

**Option A: Top-to-bottom, then left-to-right** (newspaper style)
```
1  4  7
2  5  8
3  6  9
```

**Option B: Left-to-right, then top-to-bottom** (reading order)
```
1  2  3
4  5  6
7  8  9
```

Recommend Option A for lists where items are sorted (keeps related items visually grouped in columns).

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua`
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh`
- Issue 002: Elaborate Skeletal Issues (uses issue list)
- Issue 003: Flash Disabled Items (visual feedback patterns)

---

## Acceptance Criteria

### Issue List
- [ ] List displays in multiple columns when screen width permits
- [ ] Column count adapts to terminal width
- [ ] No item is truncated (column width ≥ longest item)
- [ ] Scrollbar appears when items exceed visible area
- [ ] Scrollbar accurately represents position and proportion
- [ ] Position indicator shows current range (e.g., "[1-6 of 12]")
- [ ] Keyboard navigation works across columns and scroll positions
- [ ] Terminal resize triggers reflow without losing selection

### Content Preview Panel
- [ ] Scrollbar appears automatically when content exceeds panel height
- [ ] Scrollbar hidden when content fits (no wasted space)
- [ ] Line range indicator shows position (e.g., "[lines 1-10 of 87]")
- [ ] User can scroll through full file content during selection
- [ ] Scroll position resets when different item is selected
- [ ] Focus model allows navigating both list and preview

---

## Notes

*Layout priority: try multi-column first, fall back to single-column with scrollbar if screen too narrow, truncate with "..." only as last resort.*

*Open questions:*
- *Preferred column fill order (newspaper vs reading)*
- *Whether scrollbar should also appear in multi-column mode when total items exceed (visible rows × columns)*
