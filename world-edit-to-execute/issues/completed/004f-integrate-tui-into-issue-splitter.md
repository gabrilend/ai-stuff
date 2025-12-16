# Issue 004f: Integrate TUI into Issue-Splitter

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 004
**Priority:** High
**Affects:** src/cli/issue-splitter.sh
**Dependencies:** 004a, 004b, 004c, 004d, 004e (all components)

---

## Current Behavior

The issue-splitter's `-I` flag triggers a series of sequential y/n prompts:

```
Project directory: /path/to/project
Use this directory? [Y/n]: _

Skip issues that already have analysis? [Y/n]: _

Dry run (show what would be processed)? [y/N]: _

Proceed? [Y/n]: _
```

---

## Intended Behavior

Replace the prompt-based interactive mode with the full TUI system:

1. Source the TUI library
2. Initialize the menu system with issue-splitter's options
3. Populate the issue list dynamically
4. Map menu selections to execution flags
5. Add graceful fallback when TUI isn't available

---

## Suggested Implementation Steps

### 1. Add TUI Library Integration

```bash
# {{{ TUI Library
# Location of shared TUI library
TUI_LIB="${DIR}/../libs/tui.sh"

# Check if TUI is available
tui_available() {
    # Check library exists
    [[ ! -f "$TUI_LIB" ]] && return 1

    # Check we're in a terminal
    [[ ! -t 0 ]] && return 1
    [[ ! -t 1 ]] && return 1

    # Check terminal capabilities
    [[ "${TERM:-}" == "dumb" ]] && return 1

    return 0
}

# Source TUI library if available
if tui_available; then
    source "$TUI_LIB"
    TUI_ENABLED=1
else
    TUI_ENABLED=0
fi
# }}}
```

### 2. Map Menu to Configuration

```bash
# {{{ interactive_tui_to_config
# Convert TUI menu state to issue-splitter config
interactive_tui_to_config() {
    # Mode mapping
    case "${MENU_VALUES[mode]}" in
        "analyze")
            SKIP_PHASE1=false
            REVIEW_ONLY=false
            EXECUTE_MODE=false
            ;;
        "review")
            SKIP_PHASE1=true
            REVIEW_ONLY=true
            EXECUTE_MODE=false
            ;;
        "execute")
            EXECUTE_MODE=true
            ;;
    esac

    # Options mapping
    SKIP_EXISTING=$([[ "${MENU_VALUES[skip_existing]}" == "1" ]] && echo true || echo false)
    DRY_RUN=$([[ "${MENU_VALUES[dry_run]}" == "1" ]] && echo true || echo false)

    if [[ "${MENU_VALUES[parallel]}" == "1" ]]; then
        PARALLEL_COUNT="${MENU_VALUES[parallel:value]}"
    else
        PARALLEL_COUNT=1
    fi

    # Get selected issues
    SELECTED_ISSUES=()
    for issue in "${MENU_ISSUES[@]}"; do
        if [[ "${MENU_ISSUE_STATES[$issue]}" == "1" ]]; then
            SELECTED_ISSUES+=("$issue")
        fi
    done
}
# }}}
```

### 3. Populate Issues from Directory

```bash
# {{{ interactive_populate_issues
interactive_populate_issues() {
    MENU_ISSUES=()
    MENU_ISSUE_STATES=()
    MENU_ISSUE_DISABLED=()

    local pattern="${ISSUE_PATTERN:-[0-9]*.md}"

    while IFS= read -r -d '' file; do
        local basename=$(basename "$file")

        # Skip sub-issues if we're analyzing
        if is_subissue "$basename" && [[ "${MENU_VALUES[mode]}" == "analyze" ]]; then
            continue
        fi

        MENU_ISSUES+=("$file")

        # Pre-select by default
        MENU_ISSUE_STATES[$file]="1"

        # Disable issues that already have analysis (if skip_existing)
        if [[ "${MENU_VALUES[skip_existing]}" == "1" ]] && has_subissue_analysis "$file"; then
            if [[ "${MENU_VALUES[mode]}" == "analyze" ]]; then
                MENU_ISSUE_STATES[$file]="0"
                MENU_ISSUE_DISABLED[$file]="has analysis"
            fi
        fi

        # Disable root issues with sub-issues (for analyze mode)
        if [[ "${MENU_VALUES[mode]}" == "analyze" ]]; then
            local root_id=$(get_root_id "$basename")
            if has_subissues_on_disk "$root_id"; then
                MENU_ISSUE_DISABLED[$file]="has sub-issues"
            fi
        fi

    done < <(find "$ISSUES_DIR" -maxdepth 1 -name "$pattern" -type f -print0 | sort -z)
}
# }}}
```

### 4. Replace Interactive Mode Function

```bash
# {{{ run_interactive_mode
run_interactive_mode() {
    if [[ "$TUI_ENABLED" == "1" ]]; then
        run_interactive_tui
    else
        run_interactive_fallback
    fi
}
# }}}

# {{{ run_interactive_tui
run_interactive_tui() {
    # Initialize TUI
    tui_init
    menu_init

    # Set defaults from current config
    MENU_VALUES["skip_existing"]=$([[ "$SKIP_EXISTING" == "true" ]] && echo "1" || echo "0")
    MENU_VALUES["dry_run"]=$([[ "$DRY_RUN" == "true" ]] && echo "1" || echo "0")

    # Populate issues
    interactive_populate_issues

    # Run menu
    if menu_run; then
        # Convert selections to config
        interactive_tui_to_config

        tui_cleanup

        # Continue with execution
        return 0
    else
        tui_cleanup
        log "Cancelled by user"
        exit 0
    fi
}
# }}}

# {{{ run_interactive_fallback
run_interactive_fallback() {
    # Original y/n prompt flow for non-TUI terminals
    log "TUI not available, using simple prompts"

    echo "Project directory: $ISSUES_DIR"
    read -p "Use this directory? [Y/n]: " confirm
    [[ "$confirm" =~ ^[Nn] ]] && exit 0

    read -p "Skip issues that already have analysis? [Y/n]: " skip
    [[ ! "$skip" =~ ^[Nn] ]] && SKIP_EXISTING=true

    read -p "Dry run? [y/N]: " dry
    [[ "$dry" =~ ^[Yy] ]] && DRY_RUN=true

    read -p "Proceed? [Y/n]: " proceed
    [[ "$proceed" =~ ^[Nn] ]] && exit 0
}
# }}}
```

### 5. Update Directory Selection in Menu

```bash
# {{{ menu_edit_directory
menu_edit_directory() {
    local new_dir
    new_dir=$(path_input "Project Directory" "$ISSUES_DIR" 1)

    if [[ -n "$new_dir" ]] && [[ -d "$new_dir" ]]; then
        ISSUES_DIR="$new_dir"
        # Re-populate issues with new directory
        interactive_populate_issues
    fi
}
# }}}
```

### 6. Handle Resize Events

```bash
# {{{ Handle terminal resize
handle_resize() {
    if [[ "$TUI_ENABLED" == "1" ]] && [[ -n "${TUI_INITIALIZED:-}" ]]; then
        tui_update_dimensions

        # Recalculate visible issue count
        MENU_ISSUE_VISIBLE=$((TUI_ROWS - 20))
        [[ $MENU_ISSUE_VISIBLE -lt 3 ]] && MENU_ISSUE_VISIBLE=3

        # Force re-render
        menu_render
    fi
}
# }}}
```

### 7. Add Claude Code Background Detection

```bash
# {{{ claude_code_detection
# Detect if running inside Claude Code terminal
is_claude_code_terminal() {
    [[ -n "${CLAUDE_CODE:-}" ]] || [[ "${TERM_PROGRAM:-}" == "claude-code" ]]
}

# If in Claude Code, consider running in background
if is_claude_code_terminal && [[ "$INTERACTIVE_MODE" == "true" ]]; then
    log "Note: Interactive TUI may not work well in Claude Code terminal"
    log "Consider using headless mode with flags instead"
fi
# }}}
```

### 8. Update Help Text

```bash
# Add to usage output:
Interactive Mode:
  -I, --interactive     Full-screen interactive mode with TUI
                        Falls back to simple prompts if TUI unavailable

TUI Navigation:
  j/k, ↑/↓             Move cursor up/down
  h/l, ←/→             Cycle multi-state options
  Space                 Toggle checkbox
  Enter, i              Select/confirm
  a                     Select all in section
  n                     Select none in section
  1-9                   Jump to item by index
  g/G                   Jump to top/bottom
  r                     Run with current config
  q                     Quit without running
```

---

## Testing Plan

### Terminal Compatibility

Test in:
- [ ] xterm
- [ ] gnome-terminal
- [ ] konsole
- [ ] tmux
- [ ] screen
- [ ] VS Code terminal
- [ ] Claude Code terminal (verify fallback)

### Functionality

- [ ] All keybindings work as documented
- [ ] Mode selection affects available options
- [ ] Issue list populates correctly
- [ ] Disabled issues show reason
- [ ] Scroll works with many issues
- [ ] Directory change updates issue list
- [ ] Run triggers correct execution
- [ ] Quit exits cleanly
- [ ] Resize doesn't break display
- [ ] Fallback works when TUI unavailable

---

## Related Documents

- issues/004-redesign-interactive-mode-interface.md (parent)
- issues/004a-create-tui-core-library.md
- issues/004b-implement-checkbox-component.md
- issues/004c-implement-multistate-toggle.md
- issues/004d-implement-input-components.md
- issues/004e-build-menu-navigation-system.md
- src/cli/issue-splitter.sh

---

## Acceptance Criteria

- [ ] `-I` flag launches TUI when available
- [ ] TUI shows all current config options
- [ ] Mode selection (Analyze/Review/Execute) works
- [ ] Option checkboxes toggle correctly
- [ ] Issue list populates from directory
- [ ] Disabled issues shown with reason
- [ ] Configuration maps correctly to execution flags
- [ ] Run triggers main execution with selected config
- [ ] Fallback to simple prompts when TUI unavailable
- [ ] Terminal state restored on exit
- [ ] No visual glitches during normal operation
- [ ] Works in standard terminal emulators

---

## Notes

This is the final integration step. Ensure all previous sub-issues are
complete and tested before attempting integration.

Consider adding a `--tui-test` flag that just shows the TUI without
executing anything, for testing purposes.

---

## Implementation Log

**Date:** 2024-12-16

### Changes Made

1. **Added TUI library loading** (lines 30-44 in issue-splitter.sh)
   - Sources all TUI libraries from `${SCRIPT_DIR}/libs/`
   - Sets `TUI_AVAILABLE=true` when libraries found

2. **Created `interactive_mode_simple()`** (lines 239-333)
   - Renamed original interactive_mode to serve as fallback
   - Unchanged functionality for non-TUI terminals

3. **Created `interactive_mode_tui()`** (lines 336-435)
   - Builds menu with three sections:
     - **Mode**: Analyze/Review/Execute (radio/single-select)
     - **Options**: Skip existing, Dry run, Archive, Execute all (multi-select)
     - **Files**: Dynamic issue list with status descriptions
   - Maps menu values back to script configuration variables
   - Falls back to simple mode if TUI init fails

4. **Created wrapper `interactive_mode()`** (lines 438-445)
   - Routes to TUI or simple mode based on availability

### Implementation Notes

- Implementation is simpler than suggested steps - leverages menu.sh's built-in handling
- Mode section uses "single" type for radio-button behavior
- Options section uses "multi" type for independent checkboxes
- Files section uses "list" type with dynamic population from get_issues()
- Each issue shows status: sub-issue parent, has sub-issues, has analysis
- Graceful fallback chain: TUI unavailable → simple prompts

### Deviations from Suggested Steps

- Did not implement directory editing in TUI (can be added later)
- Did not add Claude Code terminal detection (can be added later)
- Did not add resize handling (menu.sh should handle this)
- Did not add --tui-test flag (can be added later)

These are tracked as potential future enhancements rather than blockers.
