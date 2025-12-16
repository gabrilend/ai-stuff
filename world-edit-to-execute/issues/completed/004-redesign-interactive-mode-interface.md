# Issue 004: Redesign Interactive Mode Interface

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** High
**Affects:** src/cli/issue-splitter.sh
**Dependencies:** None (can be implemented independently)

---

## Current Behavior

The interactive mode (`-I`) uses a series of sequential y/n prompts:

```
Project directory: /path/to/project
Use this directory? [Y/n]: _

Skip issues that already have analysis? [Y/n]: _

Dry run (show what would be processed)? [y/N]: _

Proceed? [Y/n]: _
```

This violates the CLAUDE.md specification which requires:
- Checkbox-style selection system
- Arrow key and vim keybinding navigation
- Index-based selection
- Few flag categories, many options within each

---

## Intended Behavior

A full-screen terminal UI with checkbox-style option selection:

```
╔══════════════════════════════════════════════════════════════════╗
║              Issue Splitter - Interactive Mode                    ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  Project Directory                                                ║
║  ─────────────────                                                ║
║  /mnt/mtwo/programming/ai-stuff/world-edit-to-execute             ║
║  [Enter to change]                                                ║
║                                                                   ║
║  Mode                                                             ║
║  ────                                                             ║
║  ▸ [●] Analyze      Analyze issues for sub-issue splitting        ║
║    [ ] Review       Review existing sub-issue structures          ║
║    [ ] Execute      Execute recommendations from analyses         ║
║                                                                   ║
║  Options                                                          ║
║  ───────                                                          ║
║    [●] Skip existing     Don't re-analyze issues with analysis    ║
║    [ ] Dry run           Show what would happen without doing it  ║
║    [ ] Parallel (3)      Process multiple issues simultaneously   ║
║                                                                   ║
║  Issues to Process                                                ║
║  ─────────────────                                                ║
║    [●] 101-research-wc3-file-formats.md                          ║
║    [○] 102-implement-mpq-archive-parser.md  [has sub-issues]     ║
║    [●] 103-parse-war3map-w3i.md                                  ║
║    [●] 104-parse-war3map-wts.md                                  ║
║    ... (j/k to scroll, Space to toggle, a to select all)         ║
║                                                                   ║
╠══════════════════════════════════════════════════════════════════╣
║  [Enter/i/A] Select   [Space] Toggle   [j/k/↑/↓] Navigate        ║
║  [a] All   [n] None   [1-9] Jump to index   [q] Quit   [r] Run   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Navigation Specification

### Movement Keys

| Key | Action |
|-----|--------|
| `↑` / `k` | Move cursor up |
| `↓` / `j` | Move cursor down |
| `←` / `h` | Collapse nested options / go to parent / cycle multi-state left |
| `→` / `l` | Expand nested options / enter sub-menu / cycle multi-state right |
| `g` | Jump to first item |
| `G` | Jump to last item |
| `1-9` | Jump to item by index |

### Multi-State Toggle Options

For options with 3+ defined states, `←`/`h` and `→`/`l` cycle through values:

```
  Output Format      ◀ [JSON] ▶        (h/l to cycle)
                       ────
                     Options: text | json | yaml
```

**Example multi-state options:**
- Output format: `text` ↔ `json` ↔ `yaml`
- Verbosity: `quiet` ↔ `normal` ↔ `verbose` ↔ `debug`
- Compression: `none` ↔ `fast` ↔ `balanced` ↔ `max`

**Behavior:**
- `→` / `l` cycles forward through states
- `←` / `h` cycles backward through states
- Wraps around (last → first, first → last)
- Only applies to explicitly defined multi-state options
- Regular checkboxes ignore h/l (or use them for collapse/expand)

**Definition format:**
```bash
declare -A MULTISTATE_OPTIONS=(
    ["output_format"]="text,json,yaml"
    ["verbosity"]="quiet,normal,verbose,debug"
)
```

### Selection Keys

| Key | Action |
|-----|--------|
| `Space` | Toggle checkbox on/off |
| `Enter` / `i` / `Shift+A` | Select/confirm current option |
| `a` | Select all (in current group) |
| `n` | Select none (in current group) |

### Action Keys

| Key | Action |
|-----|--------|
| `r` | Run with current configuration |
| `q` / `Esc` | Quit without running |
| `?` | Show help overlay |

---

## Nested Options Behavior

When an option has configurable values, selecting it reveals nested choices:

### Example: Parallel Processing Option

**Before selection:**
```
  [ ] Parallel (3)      Process multiple issues simultaneously
```

**After pressing Enter/i/A on "Parallel":**
```
  [●] Parallel          Process multiple issues simultaneously
      ├─ Count: [3]     ← cursor here, type number or use +/-
      │    (1-10, Enter to confirm)
      └─ [Back]
```

### Example: Directory Selection

**After pressing Enter on directory:**
```
  Project Directory
  ─────────────────
  ▸ /mnt/mtwo/programming/ai-stuff/world-edit-to-execute
    ──────────────────────────────────────────────────────
    Type new path or press Enter to browse:
    > _
```

---

## Suggested Implementation Steps

### 1. Create TUI Library/Module

```bash
# src/cli/lib/tui.sh - Terminal UI utilities

# {{{ tui_init
tui_init() {
    # Save terminal state
    tput smcup        # Alternative screen buffer
    tput civis        # Hide cursor
    stty -echo        # Disable echo
    trap tui_cleanup EXIT
}
# }}}

# {{{ tui_cleanup
tui_cleanup() {
    tput cnorm        # Show cursor
    tput rmcup        # Restore screen
    stty echo         # Re-enable echo
}
# }}}

# {{{ tui_read_key
tui_read_key() {
    local key
    IFS= read -rsn1 key

    # Handle escape sequences (arrows)
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 key
        case "$key" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
        esac
    else
        case "$key" in
            'k') echo "UP" ;;
            'j') echo "DOWN" ;;
            'h') echo "LEFT" ;;
            'l') echo "RIGHT" ;;
            'i'|'') echo "SELECT" ;;  # Enter
            'A') echo "SELECT" ;;      # Shift+A
            ' ') echo "TOGGLE" ;;
            'a') echo "ALL" ;;
            'n') echo "NONE" ;;
            'r') echo "RUN" ;;
            'q') echo "QUIT" ;;
            [0-9]) echo "INDEX:$key" ;;
            *) echo "OTHER:$key" ;;
        esac
    fi
}
# }}}
```

### 2. Create Checkbox Component

```bash
# {{{ Checkbox state
declare -A CHECKBOX_STATE
declare -a CHECKBOX_ITEMS
CHECKBOX_CURSOR=0

# {{{ checkbox_render
checkbox_render() {
    local items=("$@")
    local i=0

    for item in "${items[@]}"; do
        local checked="${CHECKBOX_STATE[$item]:-0}"
        local prefix="  "
        local box="[ ]"

        if [[ $i -eq $CHECKBOX_CURSOR ]]; then
            prefix="▸ "
        fi

        if [[ "$checked" == "1" ]]; then
            box="[●]"
        fi

        echo "${prefix}${box} ${item}"
        ((i++))
    done
}
# }}}

# {{{ checkbox_toggle
checkbox_toggle() {
    local item="${CHECKBOX_ITEMS[$CHECKBOX_CURSOR]}"
    if [[ "${CHECKBOX_STATE[$item]}" == "1" ]]; then
        CHECKBOX_STATE[$item]=0
    else
        CHECKBOX_STATE[$item]=1
    fi
}
# }}}
```

### 3. Create Multi-State Toggle Component

```bash
# {{{ Multi-state toggle
declare -A MULTISTATE_OPTIONS=(
    ["output_format"]="text,json,yaml"
    ["verbosity"]="quiet,normal,verbose,debug"
)
declare -A MULTISTATE_STATE

# {{{ multistate_render
multistate_render() {
    local name="$1"
    local options="${MULTISTATE_OPTIONS[$name]}"
    local current="${MULTISTATE_STATE[$name]}"
    local prefix="$2"

    IFS=',' read -ra opts <<< "$options"

    # Show: ◀ [current] ▶
    echo -n "${prefix}◀ [${current^^}] ▶"
}
# }}}

# {{{ multistate_cycle
multistate_cycle() {
    local name="$1"
    local direction="$2"  # "left" or "right"
    local options="${MULTISTATE_OPTIONS[$name]}"
    local current="${MULTISTATE_STATE[$name]}"

    IFS=',' read -ra opts <<< "$options"
    local count=${#opts[@]}
    local idx=0

    # Find current index
    for i in "${!opts[@]}"; do
        if [[ "${opts[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    # Cycle
    if [[ "$direction" == "right" ]]; then
        idx=$(( (idx + 1) % count ))
    else
        idx=$(( (idx - 1 + count) % count ))
    fi

    MULTISTATE_STATE[$name]="${opts[$idx]}"
}
# }}}
```

### 4. Create Menu Structure

```bash
# {{{ Menu definition
declare -A MENU_STRUCTURE=(
    ["mode"]="analyze,review,execute"
    ["options"]="skip_existing,dry_run,parallel,output_format"
    ["parallel:type"]="number"
    ["parallel:min"]="1"
    ["parallel:max"]="10"
    ["parallel:default"]="3"
    ["output_format:type"]="multistate"
)

declare -A MENU_STATE=(
    ["mode"]="analyze"
    ["skip_existing"]="1"
    ["dry_run"]="0"
    ["parallel"]="0"
    ["parallel:value"]="3"
)

# Initialize multi-state defaults
MULTISTATE_STATE["output_format"]="text"
# }}}
```

### 5. Main Render Loop

```bash
# {{{ interactive_main
interactive_main() {
    tui_init

    local current_section="mode"
    local running=true

    while $running; do
        clear
        render_header
        render_section_mode
        render_section_options
        render_section_issues
        render_footer

        local key=$(tui_read_key)

        case "$key" in
            UP)    cursor_up ;;
            DOWN)  cursor_down ;;
            LEFT)  section_collapse ;;
            RIGHT) section_expand ;;
            SELECT|TOGGLE) toggle_current ;;
            ALL)   select_all ;;
            NONE)  select_none ;;
            RUN)   running=false; execute_with_config ;;
            QUIT)  running=false ;;
            INDEX:*) jump_to_index "${key#INDEX:}" ;;
        esac
    done

    tui_cleanup
}
# }}}
```

### 6. Number Input Component

```bash
# {{{ number_input
number_input() {
    local label="$1"
    local min="$2"
    local max="$3"
    local current="$4"
    local result="$current"

    while true; do
        # Render input field
        echo -n "  $label: [$result] "
        echo "(${min}-${max}, Enter to confirm, +/- to adjust)"

        local key=$(tui_read_key)

        case "$key" in
            SELECT) break ;;
            UP|"+")
                ((result++))
                [[ $result -gt $max ]] && result=$max
                ;;
            DOWN|"-")
                ((result--))
                [[ $result -lt $min ]] && result=$min
                ;;
            INDEX:*)
                local digit="${key#INDEX:}"
                result="${result}${digit}"
                [[ $result -gt $max ]] && result=$max
                ;;
            LEFT|"BACKSPACE")
                result="${result%?}"
                [[ -z "$result" ]] && result=$min
                ;;
        esac
    done

    echo "$result"
}
# }}}
```

---

## Visual Design

### Symbols

| Symbol | Meaning |
|--------|---------|
| `[●]` | Checked/enabled |
| `[ ]` | Unchecked/disabled |
| `[○]` | Unavailable (greyed out) |
| `▸` | Cursor position |
| `├─` | Tree branch |
| `└─` | Tree end |
| `◀ [VALUE] ▶` | Multi-state toggle (h/l to cycle) |

### Colors (if terminal supports)

| Element | Color |
|---------|-------|
| Header | Bold cyan |
| Section titles | Bold white |
| Cursor line | Inverse/highlight |
| Checked items | Green |
| Disabled items | Dim/grey |
| Keybindings | Yellow |

---

## Related Documents

- ~/.claude/CLAUDE.md (interface specifications)
- src/cli/issue-splitter.sh
- issues/001-fix-issue-splitter-output-handling.md
- issues/002-add-streaming-queue-to-issue-splitter.md
- issues/003-execute-analysis-recommendations.md

---

## Acceptance Criteria

- [ ] Full-screen TUI replaces y/n prompts
- [ ] Arrow keys navigate between options
- [ ] Vim keybindings work (j/k/h/l/i/A)
- [ ] Number keys jump to indexed items
- [ ] Space toggles checkboxes
- [ ] Enter/i/Shift+A confirms selection
- [ ] Nested options expand/collapse properly
- [ ] Multi-state toggles cycle with h/l keys
- [ ] Multi-state only applies to explicitly defined options
- [ ] Number input works for parallel count
- [ ] Directory input allows path entry
- [ ] Issue list supports scrolling
- [ ] 'a' selects all, 'n' selects none
- [ ] 'r' runs with config, 'q' quits
- [ ] Clean exit restores terminal state
- [ ] Works in standard terminal emulators

---

## Notes

This is a significant UI overhaul. Consider:

1. **Graceful degradation** - If terminal doesn't support features, fall back
   to simpler interface or original y/n prompts

2. **Screen size handling** - Detect terminal dimensions, handle resize

3. **Accessibility** - Ensure works with screen readers if possible

4. **Testing** - Test in multiple terminals (xterm, gnome-terminal, tmux, etc.)

5. **Library consideration** - Could use `dialog` or `whiptail` for simpler
   implementation, though custom gives more control

The TUI module (`lib/tui.sh`) could be reused across other project scripts,
making this investment worthwhile beyond just issue-splitter.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:20*

This is a substantial issue that would definitely benefit from splitting. The issue encompasses building a complete TUI framework plus integrating it into the issue-splitter tool. Here's my analysis:

## Sub-Issue Breakdown for Issue 004

This issue should be split into **6 sub-issues** organized by component/layer:

---

### 004a - Create TUI Core Library

**Description:** Build the foundational terminal UI utilities in `src/cli/lib/tui.sh` - terminal state management (init/cleanup), key reading with escape sequence handling, and basic color/formatting utilities.

**Covers:**
- `tui_init()` - alternative screen buffer, cursor hiding, echo disable
- `tui_cleanup()` - terminal state restoration with trap
- `tui_read_key()` - single key input with arrow/escape sequence parsing
- Color/formatting helper functions
- Terminal dimension detection

**Dependencies:** None (foundational layer)

---

### 004b - Implement Checkbox Component

**Description:** Create the checkbox selection component with cursor tracking, toggle functionality, and visual rendering (checked/unchecked/disabled states).

**Covers:**
- Checkbox state management (`CHECKBOX_STATE`, `CHECKBOX_ITEMS`, `CHECKBOX_CURSOR`)
- `checkbox_render()` - visual output with cursor indicator
- `checkbox_toggle()` - state toggling
- `checkbox_select_all()` / `checkbox_select_none()`
- Disabled item handling (`[○]` state)

**Dependencies:** 004a (uses `tui_read_key`)

---

### 004c - Implement Multi-State Toggle Component

**Description:** Create the multi-state toggle component for options with 3+ states (like output format, verbosity) that cycle with h/l keys.

**Covers:**
- Multi-state option definition (`MULTISTATE_OPTIONS` associative array)
- `multistate_render()` - `◀ [VALUE] ▶` display
- `multistate_cycle()` - left/right cycling with wraparound
- Integration with main navigation (h/l keys context-aware)

**Dependencies:** 004a (uses key reading), 004b (integrates with checkbox navigation)

---

### 004d - Implement Number Input and Text Input Components

**Description:** Create input components for numeric values (parallel count) and text/path entry (directory selection).

**Covers:**
- `number_input()` - bounded numeric input with +/- adjustment
- `text_input()` - single-line text entry with editing
- `path_input()` - path entry with potential tab completion
- Inline editing within the TUI context

**Dependencies:** 004a (uses key reading)

---

### 004e - Build Menu Structure and Navigation System

**Description:** Create the hierarchical menu system with sections, cursor movement between sections, and nested option expansion/collapse.

**Covers:**
- Menu structure definition (`MENU_STRUCTURE`, `MENU_STATE`)
- Section-based navigation (Mode, Options, Issues)
- Cursor movement across sections (j/k/g/G)
- Nested option expand/collapse (h/l for non-multistate items)
- Index-based jumping (1-9)
- Scrollable issue list with viewport management

**Dependencies:** 004b (checkbox), 004c (multistate), 004d (inputs)

---

### 004f - Integrate TUI into Issue-Splitter

**Description:** Replace the existing y/n prompts in `issue-splitter.sh` with the new TUI system, wire up configuration to execution, and add graceful degradation.

**Covers:**
- Main render loop integration
- Header/footer rendering with keybinding hints
- Configuration → execution bridging
- Graceful fallback when terminal doesn't support features
- Terminal resize handling
- Testing across terminal emulators

**Dependencies:** 004a, 004b, 004c, 004d, 004e (all components)

---

## Dependency Graph

```
004a (TUI Core)
  │
  ├──► 004b (Checkbox)
  │       │
  ├──► 004c (Multi-State) ──────┐
  │       │                     │
  └──► 004d (Inputs)            │
          │                     │
          └────────► 004e (Menu/Navigation)
                          │
                          └────► 004f (Integration)
```

## Summary

| ID | Name | Dependencies |
|----|------|--------------|
| 004a | create-tui-core-library | None |
| 004b | implement-checkbox-component | 004a |
| 004c | implement-multistate-toggle | 004a, 004b |
| 004d | implement-input-components | 004a |
| 004e | build-menu-navigation-system | 004b, 004c, 004d |
| 004f | integrate-tui-into-issue-splitter | 004a-e (all) |

This split allows parallel work on 004b, 004c, and 004d after 004a is complete, then convergence at 004e before final integration.

---

## Generated Sub-Issues

*Auto-generated on 2025-12-16 00:45*

- 004a-create-tui-core-library.md
- 004b-implement-checkbox-component.md
- 004c-implement-multistate-toggle.md
- 004d-implement-input-components.md
- 004e-build-menu-navigation-system.md
- 004f-integrate-tui-into-issue-splitter.md
