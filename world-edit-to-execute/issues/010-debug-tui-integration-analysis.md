# Issue 010: Debug TUI Integration Analysis

**Phase:** 0 - Tooling/Infrastructure
**Type:** Bug Investigation / Reference Document
**Priority:** High
**Affects:** issue-splitter.sh TUI integration
**Related:** 004-redesign-interactive-mode-interface.md

---

## Purpose

This document analyzes the data flow and output pathways of the TUI system,
comparing working test scripts against the buggy issue-splitter.sh integration.

---

## Working Test Scripts Analysis

### 1. test-menu-render.sh (Standalone, Minimal)

**Architecture:** Self-contained, no library dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA STRUCTURES                          │
├─────────────────────────────────────────────────────────────────┤
│  ITEMS=("Analyze" "Review" "Execute" "Implement" "Stream")      │
│  CURRENT=0          # Current cursor index                      │
│  PREVIOUS=-1        # Previous cursor index                     │
│  FIRST_ITEM_ROW=2   # Items start at row 2 (0-indexed)          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ROW CALCULATION                            │
├─────────────────────────────────────────────────────────────────┤
│  row = FIRST_ITEM_ROW + item_index                              │
│                                                                 │
│  Example: item 0 → row 2, item 1 → row 3, item 2 → row 4        │
│  Simple arithmetic, no sections, no complexity                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      OUTPUT PATHWAY                             │
├─────────────────────────────────────────────────────────────────┤
│  render_item():                                                 │
│    goto "$row" 0              # printf '\033[row+1;1H'          │
│    clear_line                 # printf '\033[K'                 │
│    printf item_number         # Direct printf                   │
│    printf cursor_indicator    # Direct printf                   │
│    printf checkbox            # Direct printf                   │
│    printf label               # Direct printf                   │
│                                                                 │
│  ALL OUTPUT: Direct printf to stdout, no subshells              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   INCREMENTAL UPDATE                            │
├─────────────────────────────────────────────────────────────────┤
│  incremental_update():                                          │
│    old_row = FIRST_ITEM_ROW + PREVIOUS                          │
│    new_row = FIRST_ITEM_ROW + CURRENT                           │
│                                                                 │
│    render_item PREVIOUS old_row 0   # unhighlight               │
│    render_item CURRENT  new_row 1   # highlight                 │
│                                                                 │
│  Simple: same function for both full and incremental renders    │
└─────────────────────────────────────────────────────────────────┘
```

**Key Properties:**
- Zero subshells for rendering
- Single ITEMS array (flat structure)
- Direct row calculation (addition only)
- Same render function for full and incremental updates

---

### 2. test-menu-render-v2.sh (Standalone, With Sections)

**Architecture:** Self-contained, mimics menu.sh structure

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA STRUCTURES                          │
├─────────────────────────────────────────────────────────────────┤
│  SECTION_NAMES=("Mode" "Options")                               │
│  SECTION1_ITEMS=("Analyze" "Review" "Execute" "Implement")      │
│  SECTION2_ITEMS=("Streaming" "Skip Existing" "Archive" ...)     │
│  CURRENT_SECTION=0                                              │
│  CURRENT_ITEM=0                                                 │
│  PREV_SECTION=-1                                                │
│  PREV_ITEM=-1                                                   │
│  HEADER_HEIGHT=4                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ROW CALCULATION                            │
├─────────────────────────────────────────────────────────────────┤
│  compute_item_row(section, item):                               │
│    row = HEADER_HEIGHT                                          │
│    for s in 0..section:                                         │
│      row += 2  # section title + underline                      │
│      if s == target_section:                                    │
│        row += item  # add item offset                           │
│        break                                                    │
│      else:                                                      │
│        row += section_item_count[s]                             │
│        row += 1  # spacing between sections                     │
│    return row                                                   │
│                                                                 │
│  Uses global RENDER_ROW for return (avoids subshell cost)       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      OUTPUT PATHWAY                             │
├─────────────────────────────────────────────────────────────────┤
│  render_item() - IDENTICAL to v1:                               │
│    goto "$row" 0              # printf '\033[row+1;1H'          │
│    clear_line                 # printf '\033[K'                 │
│    printf item_number                                           │
│    printf cursor_indicator                                      │
│    printf checkbox                                              │
│    printf label                                                 │
│                                                                 │
│  ALL OUTPUT: Direct printf, no library indirection              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   INCREMENTAL UPDATE                            │
├─────────────────────────────────────────────────────────────────┤
│  incremental_update():                                          │
│    # Only same-section, adjacent moves                          │
│    if PREV_SECTION != CURRENT_SECTION: return 1 (full redraw)   │
│    if |CURRENT_ITEM - PREV_ITEM| > 1: return 1 (full redraw)    │
│                                                                 │
│    old_row = compute_item_row(PREV_SECTION, PREV_ITEM)          │
│    new_row = compute_item_row(CURRENT_SECTION, CURRENT_ITEM)    │
│                                                                 │
│    render_item old_label old_row 0 old_idx                      │
│    render_item new_label new_row 1 new_idx                      │
│                                                                 │
│  Same render_item() used for both full and incremental          │
└─────────────────────────────────────────────────────────────────┘
```

**Key Properties:**
- Zero subshells for rendering (subshells only for data lookup)
- compute_item_row() called fresh each time (no caching)
- Same render function for full and incremental updates
- Cross-section moves trigger full redraw (no incremental)

---

### 3. libs/test-menu.sh (Uses menu.sh Library)

**Architecture:** Uses full library stack

```
┌─────────────────────────────────────────────────────────────────┐
│                        LIBRARY SOURCING                         │
├─────────────────────────────────────────────────────────────────┤
│  source tui.sh                                                  │
│  source checkbox.sh                                             │
│  source multistate.sh                                           │
│  source input.sh                                                │
│  source menu.sh                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        MENU SETUP                               │
├─────────────────────────────────────────────────────────────────┤
│  tui_init                                                       │
│  menu_init                                                      │
│  menu_set_title "Issue Splitter" "Interactive Mode"             │
│                                                                 │
│  # Section 1: Mode (radio)                                      │
│  menu_add_section "mode" "single" "Mode"                        │
│  menu_add_item "mode" "analyze" "Analyze" "checkbox" "1" "..."  │
│  menu_add_item "mode" "review" "Review" "checkbox" "0" "..."    │
│  menu_add_item "mode" "execute" "Execute" "checkbox" "0" "..."  │
│                                                                 │
│  # Section 2: Options (multi)                                   │
│  menu_add_section "options" "multi" "Options"                   │
│  menu_add_item ... (4 items, all "checkbox" type)               │
│                                                                 │
│  # Section 3: Files (list)                                      │
│  menu_add_section "files" "list" "Issues to Process"            │
│  menu_add_item ... (4 items, all "checkbox" type)               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        EXECUTION                                │
├─────────────────────────────────────────────────────────────────┤
│  menu_run                                                       │
│    └── menu_render (full) on first call                         │
│    └── tui_read_key loop                                        │
│        └── navigation: try menu_incremental_update              │
│            └── fallback: menu_render (full) if incremental fails│
│  tui_cleanup                                                    │
│  menu_get_value "..."                                           │
└─────────────────────────────────────────────────────────────────┘
```

**Key Properties:**
- ALL items are "checkbox" type
- NO "flag" or "multistate" items in sections
- 3 sections, 11 items total
- Simple, predictable structure

---

## issue-splitter.sh Analysis (BUGGY)

**Architecture:** Uses full library stack, complex menu structure

```
┌─────────────────────────────────────────────────────────────────┐
│                        LIBRARY SOURCING                         │
├─────────────────────────────────────────────────────────────────┤
│  # Lines 34-54                                                  │
│  source "${LIBS_DIR}/tui.sh"                                    │
│  source "${LIBS_DIR}/checkbox.sh"                               │
│  source "${LIBS_DIR}/multistate.sh"                             │
│  source "${LIBS_DIR}/input.sh"                                  │
│  source "${LIBS_DIR}/menu.sh"                                   │
│  TUI_AVAILABLE=true                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ISSUE DATA COLLECTION                          │
├─────────────────────────────────────────────────────────────────┤
│  # Line 519-520 (BEFORE tui_init)                               │
│  local issues                                                   │
│  mapfile -t issues < <(get_issues "$PATTERN")                   │
│                        │                                        │
│                        └── Uses find + printf, outputs to stdout│
│                            Captured via process substitution    │
│                            This is SAFE - before TUI mode       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        MENU SETUP                               │
├─────────────────────────────────────────────────────────────────┤
│  tui_init  # Line 528                                           │
│  menu_init                                                      │
│  menu_set_title "Issue Splitter" "..."                          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Section 1: "mode" (single) - 4 items                        ││
│  │   analyze  - checkbox, default=1                            ││
│  │   review   - checkbox, default=0                            ││
│  │   execute  - checkbox, default=0                            ││
│  │   implement- checkbox, default=0                            ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Section 2: "processing" (multi) - 5 items                   ││
│  │   streaming    - checkbox                                   ││
│  │   skip_existing- checkbox                                   ││
│  │   archive      - checkbox                                   ││
│  │   execute_all  - checkbox                                   ││
│  │   dry_run      - checkbox                                   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Section 3: "streaming" (multi) - 2 items ⚠️ FLAG TYPE       ││
│  │   parallel - FLAG "3:2"   ← NOT CHECKBOX!                   ││
│  │   delay    - FLAG "5:2"   ← NOT CHECKBOX!                   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Section 4: "files" (list) - N items (variable)              ││
│  │   file_0, file_1, ... file_N - all checkbox                 ││
│  │                                                             ││
│  │   Loop calls helper functions DURING TUI MODE:              ││
│  │     basename=$(basename "$issue")       # safe              ││
│  │     root_id=$(get_root_id "$basename")  # uses echo         ││
│  │     has_subissues "$root_id"            # uses find/echo    ││
│  │     ...                                                     ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## IDENTIFIED DIFFERENCES AND POTENTIAL BUGS

### Difference 1: Item Type Mismatch in Incremental Update

**Location:** menu.sh lines 1177-1196

```bash
# menu_incremental_update() hardcodes checkbox format:
local old_content="$old_global_idx [ ] ${MENU_ITEM_LABELS[$old_item_id]}"
local new_content="$new_global_idx▸[●] ${MENU_ITEM_LABELS[$new_item_id]}"

# But menu_render_item() handles multiple types:
# - checkbox: [●], [ ], [○]
# - multistate: ◀ [VALUE] ▶
# - number: [value] (min-max)
# - flag: : [    value]  (right-justified in box)
# - action: →
```

**Impact:**
- When cursor moves to/from a FLAG item, incremental update renders it as `[ ] label`
- Should render as `label: [    3]` for flags
- **Test scripts use ONLY checkbox items, so they never hit this bug**

### Difference 2: Row Cache vs Fresh Calculation

**Location:** menu.sh lines 1113-1119

```bash
# menu_incremental_update uses CACHED values from full render:
local old_row="${MENU_ITEM_ROWS[$old_cache_key]}"
local new_row="${MENU_ITEM_ROWS[$new_cache_key]}"

# But test-menu-render-v2.sh computes FRESH each time:
old_row=$(compute_item_row "$PREV_SECTION" "$PREV_ITEM")
new_row=$(compute_item_row "$CURRENT_SECTION" "$CURRENT_ITEM")
```

**Impact:**
- If cache is stale or incorrectly populated, rows will be wrong
- Cache populated during full render (menu_render_section, line 808)
- Risk: if any item/section count changes between renders, cache invalid

### Difference 3: Debug Logging During Render

**Location:** menu.sh lines 720-745, 1138-1216

```bash
# During EVERY render, writes to debug files:
if [[ -d "$MENU_DEBUG_DIR" ]]; then
    local frame_file="${MENU_DEBUG_DIR}/frame_$(printf '%04d' $MENU_DEBUG_FRAME_COUNT).txt"
    { ... } > "$frame_file"
fi

# Also during full_render:
echo "FULL_RENDER: section=$section_id item=$i row=$row..." >> "${MENU_DEBUG_DIR}/full_render.log"
```

**Impact:**
- File I/O during screen rendering could cause timing issues
- Creates files in `scripts/debug/menu_frames/` directory
- **Test scripts have NO debug logging**

### Difference 4: Menu Item Count

| Script | Sections | Items | Item Types |
|--------|----------|-------|------------|
| test-menu-render.sh | 0 | 5 | all same |
| test-menu-render-v2.sh | 2 | 8 | all same |
| libs/test-menu.sh | 3 | 11 | all checkbox |
| **issue-splitter.sh** | **4** | **11+N** | **checkbox + FLAG** |

### Difference 5: Dynamic Item Population

**test scripts:** Static items added with literal strings
**issue-splitter.sh:** Dynamic items added in loop with helper function calls

```bash
# issue-splitter.sh lines 580-610
for issue in "${issues[@]}"; do
    local basename
    basename=$(basename "$issue")      # subshell
    local root_id
    root_id=$(get_root_id "$basename") # subshell + echo
    local issue_id
    issue_id=$(get_issue_id "$basename") # subshell + echo

    # These functions use echo for return:
    if is_subissue "$basename"; then   # uses [[ =~ ]]
        ...
    elif has_subissues "$root_id"; then # uses find + wc
        local sub_count
        sub_count=$(get_subissues_for_root "$root_id" | wc -l) # subshells
```

**Impact:**
- Many subshell invocations during menu setup
- Any stray output would corrupt TUI screen
- Functions look clean, but worth verifying

---

## DATA FLOW COMPARISON

### Working Pattern (test scripts)

```
┌────────────────┐     ┌─────────────────┐     ┌───────────────┐
│   Input Key    │────▶│  Update State   │────▶│  Render Item  │
│   (tui_read)   │     │  PREV = CURR    │     │  (printf)     │
│                │     │  CURR = new     │     │               │
└────────────────┘     └─────────────────┘     └───────────────┘
                              │
                              │ row = compute(section, item)
                              ▼
                       ┌─────────────────┐
                       │  Direct printf  │
                       │  to terminal    │
                       └─────────────────┘
```

### Problematic Pattern (menu.sh)

```
┌────────────────┐     ┌─────────────────┐     ┌───────────────┐
│   Input Key    │────▶│  Update State   │────▶│  Incremental  │
│   (tui_read)   │     │  PREV = CURR    │     │  Update       │
│                │     │  CURR = new     │     │               │
└────────────────┘     └─────────────────┘     └───────┬───────┘
                                                       │
              ┌────────────────────────────────────────┴──────┐
              ▼                                               ▼
    ┌─────────────────┐                           ┌─────────────────┐
    │ Use CACHED rows │                           │  Debug file I/O │
    │ from full render│                           │  (during render)│
    └────────┬────────┘                           └─────────────────┘
             │
             ▼
    ┌─────────────────┐
    │ HARDCODED       │  ⚠️ BUG: Always renders as [ ] checkbox
    │ checkbox format │     even for FLAG items
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │ Single printf   │
    │ (good - batched)│
    └─────────────────┘
```

---

## RECOMMENDED FIXES

### Fix 1: Make incremental_update use menu_render_item

Instead of hardcoding checkbox format, call the same render function:

```bash
# BEFORE (buggy):
local old_content="$old_global_idx [ ] ${MENU_ITEM_LABELS[$old_item_id]}"
printf '\033[%d;1H\033[K%s...' "$((old_row + 1))" "$old_content"

# AFTER (correct):
menu_render_item "$old_item_id" "$old_row" 0 "$old_global_idx"
menu_render_item "$new_item_id" "$new_row" 1 "$new_global_idx"
```

### Fix 2: Remove or disable debug logging in production

```bash
# In menu_init(), make debug conditional:
if [[ "${MENU_DEBUG:-}" == "1" ]]; then
    MENU_DEBUG_DIR="${script_dir}/../debug/menu_frames"
    mkdir -p "$MENU_DEBUG_DIR"
fi
```

### Fix 3: Validate cache before use

```bash
# Before using cached rows, verify they're populated:
if [[ -z "${MENU_ITEM_ROWS[$old_cache_key]:-}" ]] || \
   [[ -z "${MENU_ITEM_ROWS[$new_cache_key]:-}" ]]; then
    return 1  # Force full redraw
fi
```

---

## TEST PLAN

1. **Create minimal reproduction:**
   - New test script with 4 sections
   - Include 2 FLAG type items (like issue-splitter.sh)
   - Verify bug reproduces

2. **Apply Fix 1 (item type rendering):**
   - Modify menu_incremental_update to use menu_render_item
   - Test navigation through all item types

3. **Apply Fix 2 (disable debug logging):**
   - Remove or gate debug file writes
   - Measure any performance difference

4. **Integration test:**
   - Run issue-splitter.sh -I
   - Navigate through all sections
   - Verify no rendering artifacts

---

## Related Documents

- issues/004-redesign-interactive-mode-interface.md
- scripts/libs/menu.sh (lines 1074-1224 - incremental update)
- scripts/test-menu-render.sh
- scripts/test-menu-render-v2.sh
- scripts/libs/test-menu.sh

---

## Acceptance Criteria

- [x] Identified root cause of rendering bug
- [ ] Created minimal reproduction test
- [x] Applied fix to menu.sh
- [ ] Verified fix in test scripts
- [ ] Verified fix in issue-splitter.sh
- [ ] No regression in existing functionality

---

## Implementation Notes

*Implemented 2025-12-17*

### Changes Made to `/home/ritz/programming/ai-stuff/scripts/libs/menu.sh`

**1. Fixed `menu_incremental_update()` (lines 1074-1162)**

The original implementation hardcoded checkbox format:
```bash
# OLD (buggy):
local old_content="$old_global_idx [ ] ${MENU_ITEM_LABELS[$old_item_id]}"
printf '\033[%d;1H\033[K%s...' "$((old_row + 1))" "$old_content"
```

Replaced with calls to `menu_render_item()` which handles all item types:
```bash
# NEW (fixed):
menu_render_item "$old_item_id" "$old_row" 0 "$old_global_idx"
menu_render_item "$new_item_id" "$new_row" 1 "$new_global_idx"
```

This ensures checkbox, flag, multistate, number, text, and action items all
render correctly during incremental updates.

**2. Made debug logging conditional (MENU_DEBUG=1)**

Changed from unconditional file writes to conditional:
- `menu_init()`: Only creates debug directory if `MENU_DEBUG=1`
- `menu_render()`: Debug logging already checked `[[ -d "$MENU_DEBUG_DIR" ]]`
- `menu_render_section()`: Added conditional around debug echo
- `menu_render_item()`: Added conditional around debug echo
- `menu_incremental_update()`: Debug logging now checks `MENU_DEBUG=1`

To enable debug logging: `export MENU_DEBUG=1` before running.

**3. Added cache validation**

Added check for empty cached row values:
```bash
if [[ -z "$old_row" ]] || [[ -z "$new_row" ]]; then
    return 1  # Force full redraw
fi
```

### Files Modified

- `/home/ritz/programming/ai-stuff/scripts/libs/menu.sh`
  - `menu_init()` - conditional debug dir creation
  - `menu_render_section()` - conditional debug logging
  - `menu_render_item()` - conditional debug logging
  - `menu_incremental_update()` - use menu_render_item, conditional debug

### Verification Required

Run `issue-splitter.sh -I` and navigate through all sections, especially
into the "Streaming Settings" section which contains FLAG type items.
Verify that incremental rendering works correctly without visual artifacts.
