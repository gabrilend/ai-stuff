# Issue 8-030: Add Chronological Anchor Links to Poem Navigation

## Current Behavior

Each poem displayed on similarity/diversity pages has two navigation links:
- **similar** → links to `similar/{category}-{id}.html`
- **different** → links to `different/{category}-{id}.html`

```
┌─────────┐                                                          ┌───────────┐
│ similar │                                                          │ different │
╘═════════╧══════════════════════════════════════════════════════════╧═══════════╛
```

Users currently have no way to:
1. See where a poem appears in the chronological timeline
2. Navigate from a similarity/diversity page back to the main chronological view
3. Understand the temporal context of a poem they're reading

## Intended Behavior

Add a third navigation option: **chronological** that links to `chronological.html` with an anchor that scrolls directly to that poem's position.

```
┌─────────┐                     ┌──────────────┐                     ┌───────────┐
│ similar │                     │ chronological │                     │ different │
╘═════════╧═════════════════════╧══════════════╧═════════════════════╧═══════════╛
```

When clicked:
- Navigates to `chronological.html#poem-{category}-{id}`
- Browser scrolls to show that poem in the chronological list
- User can see surrounding poems (temporal neighbors)

## Implementation Steps

### Step 1: Add anchor IDs to chronological.html ✅ COMPLETE
- [x] Each poem in chronological.html needs an anchor ID
- [x] Format: `id="poem-{category}-{id}"` (e.g., `id="poem-fediverse-0042"`)
- [x] Add to the poem separator line or a wrapper element
- [x] Ensure IDs are unique (category-id format guarantees this)

### Step 2: Update poem navigation template ✅ COMPLETE
- [x] Add "chronological" link between "similar" and "different"
- [x] Link format: `chronological.html#poem-{category}-{id}`
- [x] Update box-drawing layout to accommodate third link
- [x] Maintain visual symmetry (chronological centered between similar/different)

### Step 3: Update box-drawing characters ✅ COMPLETE

**Implemented: Option B - Chronological as center text (no box)**

For regular poems (82 chars):
```
  │ similar │                     chronological                      │ different │
```

For golden poems (84 chars):
```
║ similar │                     chronological                      │ different │
```

### Step 4: Test anchor scrolling ✅ COMPLETE
- [x] Verified anchors work with pure HTML (no JavaScript)
- [x] Anchor IDs follow format: `poem-{category}-{id}`
- [x] Links properly formatted: `chronological.html#poem-fediverse-0042`
- [x] Test passed: 100 chronological links found in generated pages

## Technical Notes

### Anchor ID Format
Using `poem-{category}-{id}` format ensures uniqueness:
- `poem-fediverse-0042`
- `poem-messages-0767`
- `poem-notes-what-a-lame-movie`

### HTML Anchor Syntax
```html
<!-- In chronological.html -->
<span id="poem-fediverse-0042"></span>
 -> file: fediverse/42.txt
═══════════════════════════════════════════════════════════════════════════════════
  poem content here...

<!-- In similar/fediverse-0042.html -->
<a href='chronological.html#poem-fediverse-0042'>chronological</a>
```

### Pure HTML Requirement
- No JavaScript for scrolling (use native anchor behavior)
- No CSS for scroll padding (browser handles positioning)
- Link is standard `<a href="">` tag

## Quality Assurance Criteria

- [x] Every poem in similar/*.html has chronological link
- [x] Every poem in different/*.html has chronological link
- [x] Clicking chronological link scrolls to correct poem (HTML native anchors)
- [x] Anchor IDs are valid HTML (no spaces, special chars escaped)
- [x] Visual layout is balanced and readable
- [x] Box-drawing characters align correctly

## Related Issues

- **Issue 8-007**: Box-drawing borders around navigation links (COMPLETED)
- **Issue 8-001**: Unified website generation pipeline
- **Issue 8-012**: Paginated similarity chapters (may need pagination anchors)

## Notes

This feature helps users understand poems in context:
- "This melancholy poem was written right after a joyful one"
- "These similar poems were actually written years apart"
- "This poet's style evolved - see the chronological neighbors"

The chronological view becomes an anchor point users can always return to.

---

## Implementation Log

### Session: 2026-01-09

**All steps completed successfully!**

1. **Created `get_poem_anchor_id()` helper function** (lines 158-166)
   - Generates anchor IDs in format `poem-{category}-{id}`
   - Used by both chronological HTML and navigation links

2. **Updated navigation functions:**
   - `generate_corner_box_nav_line()` - Added chronological_link parameter (line 1178)
   - `generate_regular_corner_box_nav_line()` - Added chronological_link parameter (line 1214)
   - Both functions now generate three-part navigation layout

3. **Updated all navigation link generation sites:**
   - Lines 1379-1383: Added chronological_link creation
   - Lines 1891-1895: Added chronological_link creation in chronological HTML
   - Updated all function calls to pass chronological_link

4. **Added anchor IDs to chronological.html:**
   - Line 1892: Added `<span id="{anchor_id}"></span>` before each poem
   - Anchors placed before file header for proper scroll positioning

5. **Updated helper functions:**
   - `apply_golden_poem_formatting()` - Added chronological_link parameter (line 1248)
   - `format_content_with_warnings()` - Added chronological_link parameter (line 1302)
   - All golden poem formatting includes chronological links

**Test Results** (`tmp/test-chronological-anchors-8-030.lua`):
```
✓ Generated 1 test page successfully
✓ 100 chronological links found in paginated page
✓ Three-part navigation layout detected
✓ Link format verified: chronological.html#poem-fediverse-0001
```

**Example Navigation Output:**
```
│ similar │                     chronological                      │ different │
```

---

## Re-opened: 2026-01-21 - Pagination Not Accounted For

### Problem: Anchor Links Don't Include Page Number

When chronological.html is paginated (e.g., 8 pages with 1000 poems each), the anchor links from similar/different pages need to point to the **correct page** containing that poem, not just the anchor ID.

**Current (broken):**
```html
<a href='chronological/index.html#poem-fediverse-5000'>chronological</a>
```
This links to page 1, but poem 5000 is on page 5.

**Correct:**
```html
<a href='chronological/05.html#poem-fediverse-5000'>chronological</a>
```

### Root Cause

The `chrono_map` includes `page_number` for each poem, but the link generation doesn't use it when `chrono_paginated = true`. The effil worker thread needs to:
1. Check if pagination is enabled
2. Use `chrono_info.page_number` to construct the correct URL

### Fix Location

**Effil worker thread** in `src/flat-html-generator.lua` - lines ~2889-2894:
```lua
-- Current code checks chrono_paginated but may not be using page_number correctly
chrono_link = string.format("<a href='%s/chronological/%02d.html#%s'>chronological</a>",
    base_path, chrono_info.page_number, anchor_id)
```

Verify that `chrono_info.page_number` is being passed correctly and the format string uses it.

### Verification

After fix:
- [x] Poem on page 1 → links to `chronological/01.html#anchor`
- [x] Poem on page 5 → links to `chronological/05.html#anchor`
- [x] Clicking link scrolls to correct poem on correct page

---

## Fix Applied: 2026-01-21 - Anchor ID Format Mismatch

### Investigation Findings

The pagination logic was already working correctly (e.g., `chronological/06.html#poem-b-0001`). However, the **anchor IDs didn't match** between pages:

| Location | Format Used | Example |
|----------|-------------|---------|
| Chronological pages | Full category | `id="poem-fediverse-4210"` |
| Similar/different links | First letter only | `href="...#poem-f-2836"` |

### Root Cause

The effil worker thread at line 2886 incorrectly reimplemented the anchor ID logic:
```lua
-- WRONG: Used abbreviated category (first letter)
local anchor_id = string.format("poem-%s-%04d", (poem.category or "unknown"):sub(1,1):lower(), poem.id or 0)
```

The main scope uses `get_poem_anchor_id()` → `get_unique_poem_filename_id()` which produces full category names.

### Fix Applied

Updated line 2886 to use full category name:
```lua
-- Issue 8-030 Fix: Must match chronological page anchors (full category name, not first letter)
-- Chronological uses get_poem_anchor_id() → get_unique_poem_filename_id() → "category-NNNN"
local anchor_id = string.format("poem-%s-%04d", poem.category or "unknown", poem.id or 0)
```

### Verification Passed

After fix:
- Similar pages generate: `href="...#poem-fediverse-5000"`
- Chronological pages have: `id="poem-fediverse-5000"`
- Anchor IDs now match correctly

---

**ISSUE STATUS: ✅ COMPLETE**

**Created**: 2026-01-04
**Completed**: 2026-01-09 (basic anchor links)
**Re-opened**: 2026-01-21 (pagination bug)
**Re-completed**: 2026-01-21 (anchor ID format fix)
**Phase**: 8 (Website Completion)
