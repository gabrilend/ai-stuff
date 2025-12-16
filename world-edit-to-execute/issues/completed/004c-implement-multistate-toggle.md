# Issue 004c: Implement Multi-State Toggle Component

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 004
**Priority:** Medium
**Affects:** src/cli/lib/tui.sh
**Dependencies:** 004a (uses key reading), 004b (integrates with checkbox navigation)

---

## Current Behavior

No multi-state toggle component exists. Options with multiple values must
currently be selected through separate prompts or nested menus.

---

## Intended Behavior

Create a multi-state toggle component for options with 3+ defined states
that cycle with h/l (or left/right arrow) keys.

### Visual Design

```
  Output Format      ◀ [JSON] ▶        (h/l to cycle)
```

### Example Multi-State Options

- Output format: `text` ↔ `json` ↔ `yaml`
- Verbosity: `quiet` ↔ `normal` ↔ `verbose` ↔ `debug`
- Compression: `none` ↔ `fast` ↔ `balanced` ↔ `max`

### Behavior

- `→` / `l` cycles forward through states
- `←` / `h` cycles backward through states
- Wraps around (last → first, first → last)
- Only applies to explicitly defined multi-state options
- Regular checkboxes ignore h/l (or use them for collapse/expand)

---

## Suggested Implementation Steps

### 1. Define Multi-State Configuration

```bash
# {{{ Multi-state configuration
# Format: name -> "state1,state2,state3,..."
declare -A MULTISTATE_OPTIONS=(
    ["output_format"]="text,json,yaml"
    ["verbosity"]="quiet,normal,verbose,debug"
)

# Current values
declare -A MULTISTATE_VALUES

# Labels for display (optional, defaults to option name)
declare -A MULTISTATE_LABELS=(
    ["output_format"]="Output Format"
    ["verbosity"]="Verbosity Level"
)
# }}}
```

### 2. Implement Initialization

```bash
# {{{ multistate_init
multistate_init() {
    MULTISTATE_VALUES=()

    # Set defaults to first option
    for name in "${!MULTISTATE_OPTIONS[@]}"; do
        local options="${MULTISTATE_OPTIONS[$name]}"
        local first="${options%%,*}"
        MULTISTATE_VALUES[$name]="$first"
    done
}
# }}}

# {{{ multistate_add
multistate_add() {
    local name="$1"
    local options="$2"        # comma-separated list
    local default="${3:-}"    # optional default value
    local label="${4:-$name}"

    MULTISTATE_OPTIONS[$name]="$options"
    MULTISTATE_LABELS[$name]="$label"

    if [[ -n "$default" ]]; then
        MULTISTATE_VALUES[$name]="$default"
    else
        # Default to first option
        MULTISTATE_VALUES[$name]="${options%%,*}"
    fi
}
# }}}
```

### 3. Implement Rendering

```bash
# {{{ multistate_render
multistate_render() {
    local name="$1"
    local width="${2:-20}"      # Width for label column
    local highlight="${3:-0}"   # Whether this item is selected

    local label="${MULTISTATE_LABELS[$name]:-$name}"
    local current="${MULTISTATE_VALUES[$name]}"

    # Pad label to width
    local padded_label
    printf -v padded_label "%-${width}s" "$label"

    # Build display
    local display
    if [[ "$highlight" == "1" ]]; then
        display="${TUI_BOLD}▸ ${padded_label}${TUI_RESET}"
        display+=" ${TUI_CYAN}◀${TUI_RESET}"
        display+=" ${TUI_INVERSE}[${current^^}]${TUI_RESET}"
        display+=" ${TUI_CYAN}▶${TUI_RESET}"
    else
        display="  ${padded_label}"
        display+=" ${TUI_DIM}◀${TUI_RESET}"
        display+=" [${current^^}]"
        display+=" ${TUI_DIM}▶${TUI_RESET}"
    fi

    echo -n "$display"
}
# }}}

# {{{ multistate_render_inline
# Compact inline version for status bars
multistate_render_inline() {
    local name="$1"
    local current="${MULTISTATE_VALUES[$name]}"
    echo -n "◀${current^^}▶"
}
# }}}
```

### 4. Implement Cycling

```bash
# {{{ multistate_cycle
multistate_cycle() {
    local name="$1"
    local direction="$2"  # "left" (-1) or "right" (+1)

    local options="${MULTISTATE_OPTIONS[$name]}"
    local current="${MULTISTATE_VALUES[$name]}"

    # Split options into array
    IFS=',' read -ra opts <<< "$options"
    local count=${#opts[@]}

    # Find current index
    local idx=0
    for ((i = 0; i < count; i++)); do
        if [[ "${opts[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    # Calculate new index with wraparound
    if [[ "$direction" == "right" ]] || [[ "$direction" == "1" ]]; then
        idx=$(( (idx + 1) % count ))
    else
        idx=$(( (idx - 1 + count) % count ))
    fi

    MULTISTATE_VALUES[$name]="${opts[$idx]}"
}
# }}}

# {{{ multistate_cycle_left
multistate_cycle_left() {
    multistate_cycle "$1" "left"
}
# }}}

# {{{ multistate_cycle_right
multistate_cycle_right() {
    multistate_cycle "$1" "right"
}
# }}}
```

### 5. Implement Value Access

```bash
# {{{ multistate_get
multistate_get() {
    local name="$1"
    echo "${MULTISTATE_VALUES[$name]}"
}
# }}}

# {{{ multistate_set
multistate_set() {
    local name="$1"
    local value="$2"

    # Validate value is in options
    local options="${MULTISTATE_OPTIONS[$name]}"
    if [[ ",$options," == *",$value,"* ]]; then
        MULTISTATE_VALUES[$name]="$value"
        return 0
    fi
    return 1
}
# }}}

# {{{ multistate_get_options
multistate_get_options() {
    local name="$1"
    local options="${MULTISTATE_OPTIONS[$name]}"
    IFS=',' read -ra opts <<< "$options"
    printf '%s\n' "${opts[@]}"
}
# }}}
```

### 6. Integration with Checkbox/Menu System

```bash
# {{{ multistate_is_multistate
# Check if an option name is a multistate toggle
multistate_is_multistate() {
    local name="$1"
    [[ -n "${MULTISTATE_OPTIONS[$name]:-}" ]]
}
# }}}

# {{{ Handle h/l keys in main navigation
# Example integration in menu event handler:
handle_left_right_key() {
    local direction="$1"  # "left" or "right"
    local current_item="$2"

    if multistate_is_multistate "$current_item"; then
        multistate_cycle "$current_item" "$direction"
    else
        # Handle as expand/collapse for nested items
        # or ignore for regular checkboxes
        :
    fi
}
# }}}
```

---

## Testing

```bash
#!/usr/bin/env bash
source libs/tui.sh

tui_init

multistate_init
multistate_add "format" "text,json,yaml,csv" "json" "Output Format"
multistate_add "level" "quiet,normal,verbose,debug" "normal" "Verbosity"

tui_clear
echo "Multi-State Toggle Test"
echo "Press h/l to cycle, q to quit"
echo

row=3
current=0
items=("format" "level")

while true; do
    for ((i = 0; i < ${#items[@]}; i++)); do
        tui_goto $((row + i)) 0
        tui_clear_line
        local hl=0
        [[ $i -eq $current ]] && hl=1
        multistate_render "${items[$i]}" 20 $hl
    done

    key=$(tui_read_key)
    case "$key" in
        UP)    ((current > 0)) && ((current--)) ;;
        DOWN)  ((current < ${#items[@]} - 1)) && ((current++)) ;;
        LEFT)  multistate_cycle "${items[$current]}" left ;;
        RIGHT) multistate_cycle "${items[$current]}" right ;;
        QUIT)  break ;;
    esac
done

tui_cleanup
echo "Final values:"
echo "  format: $(multistate_get format)"
echo "  level: $(multistate_get level)"
```

---

## Related Documents

- issues/004-redesign-interactive-mode-interface.md (parent)
- issues/004a-create-tui-core-library.md (dependency)
- issues/004b-implement-checkbox-component.md (integration)

---

## Acceptance Criteria

- [ ] Multi-state options display as `◀ [VALUE] ▶`
- [ ] h/← cycles left (backward) through options
- [ ] l/→ cycles right (forward) through options
- [ ] Values wrap around at boundaries
- [ ] Current item highlighted when selected
- [ ] `multistate_get()` returns current value
- [ ] `multistate_set()` validates and sets value
- [ ] `multistate_is_multistate()` correctly identifies multi-state items
- [ ] Regular checkboxes unaffected by h/l keys
- [ ] Works with any number of states (2+)

---

## Notes

Keep the implementation simple. The main complexity is in the integration
with the menu navigation system (004e), not the component itself.

---

## Implementation Complete

*Implemented on 2025-12-16*

### Changes Made

Created `/home/ritz/programming/ai-stuff/scripts/libs/multistate.sh` with:

1. **Configuration:**
   - `MULTISTATE_OPTIONS` - Option definitions (name -> states)
   - `MULTISTATE_VALUES` - Current values
   - `MULTISTATE_LABELS` - Display labels
   - `MULTISTATE_STATE_DESCRIPTIONS` - Per-state descriptions
   - `multistate_init()`, `multistate_add()`, `multistate_add_description()`

2. **Value Access:**
   - `multistate_get()`, `multistate_set()` (with validation)
   - `multistate_get_options()`, `multistate_get_index()`, `multistate_get_count()`

3. **Cycling:**
   - `multistate_cycle()` - Cycle left/right with wraparound
   - `multistate_cycle_left()`, `multistate_cycle_right()` - Convenience functions
   - `multistate_set_first()`, `multistate_set_last()`

4. **Type Checking:**
   - `multistate_exists()`, `multistate_is_multistate()`

5. **Rendering:**
   - `multistate_render()` - Full render with label and arrows
   - `multistate_render_inline()` - Compact `◀VALUE▶`
   - `multistate_render_value()` - Just `[VALUE]`
   - `multistate_render_with_description()` - Includes state description
   - `multistate_render_all_states()` - Shows all states with current highlighted

6. **Key Handling:**
   - `multistate_handle_key()` - Handles LEFT/RIGHT/HOME/END

7. **Presets:**
   - `multistate_add_preset()` with: output_format, verbosity, compression, boolean, onoff

### Test Script

Created `libs/test-multistate.sh` for both automated and interactive testing.

### Acceptance Criteria Status

- [x] Multi-state options display as `◀ [VALUE] ▶`
- [x] h/← cycles left (backward) through options
- [x] l/→ cycles right (forward) through options
- [x] Values wrap around at boundaries
- [x] Current item highlighted when selected
- [x] `multistate_get()` returns current value
- [x] `multistate_set()` validates and sets value
- [x] `multistate_is_multistate()` correctly identifies multi-state items
- [x] Regular checkboxes unaffected by h/l keys (handled by integration)
- [x] Works with any number of states (2+)
