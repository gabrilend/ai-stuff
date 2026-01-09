# Issue 8-014: Unify Interactive Menus with TUI Library

## Current Behavior

The project has **two separate interactive menus** that diverge depending on how the program is invoked:

### Menu 1: Main Pipeline Menu (from `src/main.lua`)
```
=== Neocities Poetry Modernization ===
1. Extract poems (auto-detect JSON/compiled.txt)
2. Validate extracted poems
3. Test Ollama embedding service
4. Generate complete dataset
5. Catalog and manage images
6. Generate website HTML
7. View project status
8. Clean and rebuild assets
9. Exit
```
- Invoked via: `run.sh -I` or `lua src/main.lua -I`
- Uses: `utils.show_menu()` (simple text-based menu)
- Location: `src/main.lua` lines 38-53

### Menu 2: Flat HTML Generator Menu (from `src/flat-html-generator.lua`)
```
Flat HTML Generator - Interactive Mode
1. Generate complete flat HTML collection
2. Generate chronological index only
3. Generate instructions page only
4. Test single similarity page
5. Test single difference page
```
- Invoked via: `lua src/flat-html-generator.lua -I` (direct execution)
- Uses: Simple `print()` statements
- Location: `src/flat-html-generator.lua` lines 1689-1798

### Problem

1. Users may accidentally invoke the wrong menu
2. Duplicate functionality (HTML generation) exists in both
3. Neither uses the modern TUI library available at `/home/ritz/programming/ai-stuff/scripts/libs/`
4. No vim keybindings, no checkbox states, no dependency management

---

## Intended Behavior

A **single unified TUI menu** using the existing menu.lua library that:

1. Combines all functionality from both menus into organized sections
2. Uses vim-style navigation (j/k for movement, space for toggle, Enter for run)
3. Supports checkboxes, flags, and multi-state options
4. Shows dependencies (e.g., "Generate HTML" disabled until "Extract poems" complete)
5. Displays status indicators for completed steps
6. Removes the need for separate script invocations

### Proposed Unified Menu Structure

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                      Neocities Poetry Modernization                          ║
║              Static HTML poetry recommendation system builder                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
  Data Pipeline
  ─────────────
1>(*) Extract poems from sources
2 ( ) Validate extracted poems
3 ( ) Catalog and manage images
4 ( ) Generate complete dataset (runs 1-3)

  Embedding & Similarity
  ──────────────────────
5 ( ) Test Ollama embedding service
6 ( ) Generate embeddings (calls generate-embeddings.sh)
7 ( ) Calculate similarity matrix (parallel)

  HTML Generation
  ───────────────
8 ( ) Generate chronological index
9 ( ) Generate explore.html (instructions)
10( ) Generate similarity pages (parallel)
11( ) Generate difference pages (parallel)
12( ) Generate complete website (runs 8-11)

  Testing & Debug
  ───────────────
13[ ] Test single similarity page    Poem ID: [   1]
14[ ] Test single difference page    Poem ID: [   1]

  Utilities
  ─────────
15( ) View project status
16( ) Clean and rebuild assets

──────────────────────────────────────────────────────────────────────────────
╠══════════════════════════════════════════════════════════════════════════════╣
║              j/k:nav  space:toggle  ~:copy  `:action  q:quit                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## Suggested Implementation Steps

### Phase 1: Library Setup
1. [ ] Copy TUI libraries to project:
   - `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua` → `libs/tui.lua`
   - `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` → `libs/menu.lua`
2. [ ] Verify libraries work with project's package.path configuration
3. [ ] Test basic menu rendering

### Phase 2: Menu Configuration
4. [ ] Create `src/interactive-menu.lua` with unified menu configuration
5. [ ] Define sections: Data Pipeline, Embedding, HTML Generation, Testing, Utilities
6. [ ] Define items with proper types (radio, checkbox, flag)
7. [ ] Set up dependencies (e.g., HTML gen requires poems.json)

### Phase 3: Action Handlers
8. [ ] Move action logic from `main.lua` into handler functions
9. [ ] Move action logic from `flat-html-generator.lua` into handlers
10. [ ] Add handlers for new combined options (embedding generation, parallel HTML)

### Phase 4: Integration
11. [ ] Update `main.lua` to use new menu when `-I` flag is passed
12. [ ] Remove standalone interactive mode from `flat-html-generator.lua`
13. [ ] Update `run.sh` to use new unified menu

### Phase 5: Testing
14. [ ] Test all menu options work correctly
15. [ ] Test vim keybindings (j/k/space/enter/q)
16. [ ] Test dependency enabling/disabling
17. [ ] Test on different terminal sizes

---

## Related Documents

- TUI Library: `/home/ritz/programming/ai-stuff/scripts/libs/README-lua-menu-user.md`
- Example usage: `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh`
- Current main.lua: `src/main.lua`
- Current flat-html-generator: `src/flat-html-generator.lua`

---

## Technical Notes

The menu.lua library provides:
- `menu.init(config)` - Initialize from config table
- `menu.run()` - Run interactive menu loop
- `menu.get_value(item_id)` - Get current value
- Section types: "single" (radio), "multi" (checkboxes)
- Item types: "checkbox", "flag" (editable text), "multistate"
- Dependencies: Enable/disable items based on other item values
- Content sources: Preview panel with file contents or text

The TUI library (tui.lua) provides:
- Framebuffer-based rendering for flicker-free updates
- Terminal input handling with escape sequence parsing
- Box-drawing character support
- Color support via ANSI codes

---

## Implementation Progress (2025-12-23)

### Completed Steps

1. ✅ **Added TUI library path to package.path** (`src/main.lua` line 17)
   - References library at `/home/ritz/programming/ai-stuff/scripts/libs/`
   - Updates propagate automatically without copying files

2. ✅ **Created `build_menu_config()` function** (lines 48-246)
   - Six sections: Data Pipeline, Embedding & Similarity, HTML Generation, Testing, Options, Utilities
   - 16 action items with shortcuts, descriptions, and types
   - Editable flag fields for test_poem_id and thread_count

3. ✅ **Created `M.show_tui_menu()` function** (lines 249-264)
   - Initializes menu from config
   - Falls back to simple menu if TUI unavailable
   - Returns (action, values) tuple

4. ✅ **Created `M.handle_tui_action()` function** (lines 649-741)
   - Dispatches actions based on selected menu values
   - Handles all 16 action types from the unified menu
   - Integrates parallel similarity and HTML generation scripts

5. ✅ **Added test page functions** (lines 744-814)
   - `M.test_single_similarity_page(poem_id)`
   - `M.test_single_difference_page(poem_id)`
   - Moved from flat-html-generator.lua's interactive mode

6. ✅ **Updated `M.main()` function** (lines 817-850)
   - Uses new TUI menu in interactive mode
   - Handles action/values-based return format
   - Preserves non-interactive mode behavior

7. ✅ **Added LuaJIT requirement handling** (2025-12-23)
   - Added descriptive error message when TUI fails to load
   - Shows fallback warning when running with standard Lua
   - Guides users to run with `luajit` or use the shebang

8. ✅ **Tested TUI menu rendering** (2025-12-23)
   - TUI renders correctly with luajit: vim keybindings work (j/k/space/q)
   - Simple menu fallback works with standard lua (with warning)
   - Shebang (`#!/usr/bin/env luajit`) ensures correct interpreter when run directly

9. ✅ **Updated run.sh to use luajit** (2025-12-23)
   - Changed `lua src/main.lua` to `luajit src/main.lua` at lines 78-80
   - Shebang is ignored when shell script explicitly specifies interpreter

### Remaining Steps

- [ ] Remove standalone interactive mode from `flat-html-generator.lua`
- [ ] Test all action handlers work correctly
- [ ] Update run.sh documentation if needed

---

## Technical Notes: LuaJIT Requirement

The TUI library requires LuaJIT due to its use of the `bit` module for bitwise operations
in terminal escape sequence parsing. Standard Lua 5.2 has `bit32` (different API) and
Lua 5.3+ has native operators (`&`, `|`), but the library was designed for LuaJIT.

**Execution methods:**
- `./src/main.lua -I` - Uses shebang, runs with luajit ✅
- `luajit src/main.lua -I` - Explicit luajit ✅
- `lua src/main.lua -I` - Fallback to simple menu with warning ⚠️

---

## Document History

- **Created**: 2025-12-23
- **Updated**: 2025-12-23 - Added implementation progress
- **Updated**: 2025-12-23 - Added LuaJIT requirement handling and testing confirmation
- **Status**: In Progress (remaining: action handler testing)
- **Phase**: 8
- **Priority**: Medium (improves UX but not blocking)
