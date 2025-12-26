# Issue 10-001: Integrate TUI into phase-demo.sh

**Phase:** 10 - Developer Experience & Tooling
**Type:** Enhancement
**Priority:** High
**Affects:** phase-demo.sh

---

## Current Behavior

The `phase-demo.sh` script provides an interactive menu for demonstrating project
phases and running utilities. Currently it uses:

- Simple `read -r choice` for single-character input
- Case statements for menu selection
- Nested sub-menus with additional read prompts
- Basic text output for menu display

Current menu structure:
```
Main Menu:
  1-8: Phase demonstrations
  S: Statistics
  P: Pipeline runner
  H: HTML generator (has sub-menu)
  D: Diversity pre-computation (has sub-menu)
  V: Browser viewer
  0: Exit
```

### Limitations

1. No vim-style navigation (j/k movement)
2. No visual cursor indicator
3. No checkbox-style multi-selection
4. Sub-menus require re-displaying entire menu
5. No quick-jump to items by index beyond single digits
6. Thread count input is plain text prompt

---

## Intended Behavior

Replace the text-based menu system with the Lua TUI library to provide:

1. **Vim-style navigation** - j/k to move up/down, g/G for top/bottom
2. **Visual feedback** - Highlighted cursor position, checkbox indicators
3. **Grouped sections** - Separate "Demonstrations", "Utilities", "Actions"
4. **Index shortcuts** - Press 1-9 to jump directly to items
5. **Numeric input fields** - Thread count with LEFT/RIGHT for 0/default
6. **Action button** - Explicit "Run" action instead of immediate execution

### Proposed Menu Structure

```
╔══════════════════════════════════════════════════════════════╗
║                    Phase Demo Menu                            ║
║              Neocities Poetry Modernization                   ║
╠══════════════════════════════════════════════════════════════╣
   Phase Demonstrations
   ────────────────────
1  [ ] Phase 1: Data Extraction
2  [ ] Phase 2: Similarity Engine
3  [ ] Phase 3: HTML Generation
4  [ ] Phase 4: Data Quality
5  [ ] Phase 5: Flat HTML & Design
6  [ ] Phase 6: Image Integration
7  [ ] Phase 7: Pipeline Hardening
8  [ ] Phase 8: Performance

   Utilities
   ─────────
9  [ ] Statistics Dashboard
0  [ ] Pipeline Runner
11 [ ] Browser Viewer

   HTML Generation
   ───────────────
22    Output Mode <[BOTH]>
33    Thread Count: [  4]

   Diversity Pre-computation
   ─────────────────────────
44    Thread Count: [  8]
55    Sleep Time (ms): [100]

   Actions
   ───────
      Run Selected -->

───────────────────────────────────────────────────────────────
j/k:nav  space:toggle  `:action  q:quit
╚══════════════════════════════════════════════════════════════╝
```

---

## Suggested Implementation Steps

### Step 1: Add TUI Library Sourcing

At the top of `phase-demo.sh`, add:

```bash
# TUI Library
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
source "${LIBS_DIR}/lua-menu.sh"
```

### Step 2: Create Menu Configuration Function

Replace the main menu display and read loop with:

```bash
setup_menu() {
    menu_init
    menu_set_title "Phase Demo Menu" "Neocities Poetry Modernization"

    # Section 1: Phase Demonstrations (checkboxes for selection)
    menu_add_section "phases" "multi" "Phase Demonstrations"
    menu_add_item "phases" "phase1" "Phase 1: Data Extraction" "checkbox" "0" \
        "Extract poems from compiled.txt into structured JSON"
    menu_add_item "phases" "phase2" "Phase 2: Similarity Engine" "checkbox" "0" \
        "Generate embeddings and compute similarity matrix"
    menu_add_item "phases" "phase3" "Phase 3: HTML Generation" "checkbox" "0" \
        "Generate browsable HTML pages"
    menu_add_item "phases" "phase4" "Phase 4: Data Quality" "checkbox" "0" \
        "Validate poem data and embeddings"
    menu_add_item "phases" "phase5" "Phase 5: Flat HTML & Design" "checkbox" "0" \
        "CSS-free HTML output demonstration"
    menu_add_item "phases" "phase6" "Phase 6: Image Integration" "checkbox" "0" \
        "Show image-enhanced poem pages"
    menu_add_item "phases" "phase7" "Phase 7: Pipeline Hardening" "checkbox" "0" \
        "Error handling and recovery demos"
    menu_add_item "phases" "phase8" "Phase 8: Performance" "checkbox" "0" \
        "Multi-threaded generation benchmarks"

    # Section 2: Utilities
    menu_add_section "utils" "multi" "Utilities"
    menu_add_item "utils" "stats" "Statistics Dashboard" "checkbox" "0" \
        "Display project statistics and metrics"
    menu_add_item "utils" "pipeline" "Pipeline Runner" "checkbox" "0" \
        "Run full extraction-to-generation pipeline"
    menu_add_item "utils" "browser" "Browser Viewer" "checkbox" "0" \
        "Open generated site in browser"

    # Section 3: HTML Generation Options
    menu_add_section "html_opts" "multi" "HTML Generation Options"
    menu_add_item "html_opts" "html_mode" "Output Mode" "multistate" "both" \
        "similar,different,both,test"
    menu_add_item "html_opts" "html_threads" "Thread Count" "flag" "4" \
        "Number of parallel threads (LEFT=0, RIGHT=default)"

    # Section 4: Diversity Pre-computation Options
    menu_add_section "div_opts" "multi" "Diversity Pre-computation"
    menu_add_item "div_opts" "div_threads" "Thread Count" "flag" "8" \
        "Number of parallel threads"
    menu_add_item "div_opts" "div_sleep" "Sleep Time (ms)" "flag" "100" \
        "Thermal throttling delay between batches"

    # Section 5: Actions
    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run Selected" "action" "" \
        "Execute selected phases and utilities"
}
```

### Step 3: Implement Run Handler

```bash
run_selected() {
    # Phase demonstrations
    [[ "$(menu_get_value "phase1")" == "1" ]] && run_phase1_demo
    [[ "$(menu_get_value "phase2")" == "1" ]] && run_phase2_demo
    [[ "$(menu_get_value "phase3")" == "1" ]] && run_phase3_demo
    [[ "$(menu_get_value "phase4")" == "1" ]] && run_phase4_demo
    [[ "$(menu_get_value "phase5")" == "1" ]] && run_phase5_demo
    [[ "$(menu_get_value "phase6")" == "1" ]] && run_phase6_demo
    [[ "$(menu_get_value "phase7")" == "1" ]] && run_phase7_demo
    [[ "$(menu_get_value "phase8")" == "1" ]] && run_phase8_demo

    # Utilities
    [[ "$(menu_get_value "stats")" == "1" ]] && show_statistics
    [[ "$(menu_get_value "pipeline")" == "1" ]] && run_pipeline
    [[ "$(menu_get_value "browser")" == "1" ]] && open_browser

    # Get configuration values for operations that need them
    local html_mode=$(menu_get_value "html_mode")
    local html_threads=$(menu_get_value "html_threads")
    local div_threads=$(menu_get_value "div_threads")
    local div_sleep=$(menu_get_value "div_sleep")

    # These values are available for the demo functions to use
}
```

### Step 4: Replace Main Loop

```bash
main() {
    setup_menu

    while true; do
        if menu_run; then
            run_selected
            # Re-setup menu for next iteration (or exit)
            read -p "Press Enter to continue..." _
            setup_menu
        else
            echo "Exiting phase demo."
            exit 0
        fi
    done
}

main "$@"
```

### Step 5: Preserve Headless Mode

Keep existing flag parsing for non-interactive use:

```bash
if [[ "$1" == "-I" ]] || [[ "$1" == "--interactive" ]]; then
    main
else
    # Existing flag-based execution
    case "$1" in
        1) run_phase1_demo ;;
        2) run_phase2_demo ;;
        # ... etc
    esac
fi
```

---

## Acceptance Criteria

- [x] TUI menu displays with all phases and utilities
- [x] Vim navigation (j/k/g/G) works correctly
- [x] Checkbox selection toggles with SPACE/i/ENTER
- [x] Index shortcuts (1-8, s, p, v, h, d, c, t) jump to correct items
- [x] Flag fields accept numeric input (thread count, sleep time)
- [x] "Run Selected" action executes chosen items
- [x] q/ESC quits without running
- [x] Existing simple menu available as fallback
- [x] No regressions in demo functionality

## Implementation (2025-12-25)

### Changes Made

1. **Added TUI library sourcing** (lines 23-31)
   - Sources `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh`
   - Sets `TUI_AVAILABLE=true` if library and luajit available

2. **Created `setup_tui_menu()` function** (lines 33-111)
   - 5 sections: Phase Demonstrations, Utilities, HTML Generation, Diversity, Actions
   - 16 items with shortcuts, descriptions, and flag types
   - Thread count and sleep time as editable flags

3. **Created `run_tui_selections()` function** (lines 114-173)
   - Reads checkbox values from menu
   - Executes phase demos, utilities, HTML generation, diversity pre-computation
   - Supports combined similar+different HTML generation

4. **Created `run_tui_mode()` function** (lines 176-201)
   - Main TUI loop with setup, run, cleanup cycle
   - Returns to menu after execution
   - Clean exit on q/ESC

5. **Refactored main loop** (lines 595-643)
   - Moved original loop into `simple_menu_loop()` function
   - Main entry point tries TUI first, falls back to simple menu
   - Preserves all original functionality

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/README-lua-menu-dev.md` - Integration guide
- `/home/ritz/programming/ai-stuff/scripts/libs/README-lua-menu-user.md` - Keyboard controls
- `phase-demo.sh` - Target script
- Issue 10-002 - generate-embeddings.sh integration (similar approach)

---

## Notes

The current `phase-demo.sh` is approximately 400 lines. The TUI integration will
likely reduce the menu-handling code while adding the configuration setup. The
demo functions themselves (run_phase1_demo, etc.) should remain unchanged.

Consider extracting the demo functions into a separate file if the script grows
too large after integration.
