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
- [ ] List displays in multiple columns when screen width permits (deferred)
- [ ] Column count adapts to terminal width (deferred)
- [ ] No item is truncated (column width ≥ longest item) (deferred)
- [ ] Scrollbar appears when items exceed visible area (deferred)
- [ ] Scrollbar accurately represents position and proportion (deferred)
- [ ] Position indicator shows current range (e.g., "[1-6 of 12]") (deferred)
- [ ] Keyboard navigation works across columns and scroll positions (deferred)
- [ ] Terminal resize triggers reflow without losing selection (deferred)

### Content Preview Panel
- [x] Scrollbar appears automatically when content exceeds panel height
- [x] Scrollbar hidden when content fits (no wasted space)
- [x] Line range indicator shows position (e.g., "[lines 1-10 of 87]")
- [x] User can scroll through full file content during selection
- [x] Scroll position resets when different item is selected
- [x] Focus model allows navigating both list and preview (Shift+J/K scrolls content)

---

## Notes

*Layout priority: try multi-column first, fall back to single-column with scrollbar if screen too narrow, truncate with "..." only as last resort.*

*Open questions:*
- *Preferred column fill order (newspaper vs reading)*
- *Whether scrollbar should also appear in multi-column mode when total items exceed (visible rows × columns)*

---

## Implementation Notes

*Partially completed 2025-12-26*

### Content Panel Scrolling (Implemented)

Modified `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua`:

1. **New state fields**:
   - `content_scroll_offset` - Current scroll position
   - `content_total_lines` - Total lines in cached file
   - `content_cached_lines` - Cached file content array
   - `content_cached_filepath` - Path of cached file
   - `content_visible_lines` - Number of visible content lines

2. **New functions**:
   - `get_cached_file_content(filepath)` - Read and cache file, return lines
   - `render_scrollbar(start_row, height, total_items, visible_start, visible_count)` - Draw scrollbar
   - `menu.content_scroll_down(lines)` - Scroll down by N lines
   - `menu.content_scroll_up(lines)` - Scroll up by N lines
   - `menu.content_scroll_page_down()` - Scroll down by page
   - `menu.content_scroll_page_up()` - Scroll up by page
   - `menu.content_scroll_top()` - Jump to top
   - `menu.content_scroll_bottom()` - Jump to bottom

3. **Modified `render_content_source()`**:
   - Uses caching for `item_file` type content
   - Applies scroll offset when rendering
   - Shows line range indicator: `[1-10 of 87]`
   - Renders scrollbar when content exceeds visible area

4. **Key bindings** (in `menu.run()`):
   - `J` (Shift+J): Scroll content down
   - `K` (Shift+K): Scroll content up
   - `PAGE_DOWN` / `CTRL_D`: Page down
   - `PAGE_UP` / `CTRL_U`: Page up

### Multi-Column List Display (Deferred)

The multi-column layout for list sections requires more substantial changes:
- Column calculation based on item widths
- Modified rendering to fill columns
- Cross-column keyboard navigation
- Terminal resize handling

This is deferred to a future issue to allow focus on core functionality.
