# Issue 004b: Implement Checkbox Component

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 004
**Priority:** High
**Affects:** src/cli/lib/tui.sh or libs/checkbox.sh
**Dependencies:** 004a (uses tui_read_key, colors)

---

## Current Behavior

No checkbox component exists. Interactive selections currently use y/n prompts.

---

## Intended Behavior

Create a checkbox selection component with:

- Visual rendering of checkbox items with cursor indicator
- State tracking for checked/unchecked/disabled items
- Toggle functionality (Space key)
- Select all/none functionality (a/n keys)
- Cursor movement integration

### Visual Elements

| Symbol | Meaning |
|--------|---------|
| `[●]` | Checked/enabled |
| `[ ]` | Unchecked/disabled |
| `[○]` | Unavailable (greyed out) |
| `▸` | Cursor position |

### State Management

```bash
declare -A CHECKBOX_STATE      # item -> 0/1/disabled
declare -a CHECKBOX_ITEMS      # ordered list of items
CHECKBOX_CURSOR=0              # current cursor position
```

---

## Suggested Implementation Steps

### 1. Create Checkbox State Variables

```bash
# {{{ Checkbox state
declare -A CHECKBOX_STATE
declare -a CHECKBOX_ITEMS
declare -a CHECKBOX_LABELS       # Optional display labels
declare -a CHECKBOX_DISABLED     # Indices of disabled items
CHECKBOX_CURSOR=0
CHECKBOX_SCROLL_OFFSET=0
CHECKBOX_VISIBLE_COUNT=10        # Max visible items before scrolling
# }}}
```

### 2. Implement Initialization

```bash
# {{{ checkbox_init
checkbox_init() {
    CHECKBOX_STATE=()
    CHECKBOX_ITEMS=()
    CHECKBOX_LABELS=()
    CHECKBOX_DISABLED=()
    CHECKBOX_CURSOR=0
    CHECKBOX_SCROLL_OFFSET=0
}
# }}}

# {{{ checkbox_add_item
checkbox_add_item() {
    local item="$1"
    local label="${2:-$item}"
    local checked="${3:-0}"
    local disabled="${4:-0}"

    CHECKBOX_ITEMS+=("$item")
    CHECKBOX_LABELS+=("$label")
    CHECKBOX_STATE[$item]="$checked"

    if [[ "$disabled" == "1" ]]; then
        CHECKBOX_DISABLED+=("${#CHECKBOX_ITEMS[@]}")
    fi
}
# }}}
```

### 3. Implement Rendering

```bash
# {{{ checkbox_render
checkbox_render() {
    local visible_height="${1:-$CHECKBOX_VISIBLE_COUNT}"
    local start_row="${2:-0}"
    local total=${#CHECKBOX_ITEMS[@]}

    # Calculate visible range
    local start=$CHECKBOX_SCROLL_OFFSET
    local end=$((start + visible_height))
    [[ $end -gt $total ]] && end=$total

    # Render each visible item
    for ((i = start; i < end; i++)); do
        local item="${CHECKBOX_ITEMS[$i]}"
        local label="${CHECKBOX_LABELS[$i]:-$item}"
        local checked="${CHECKBOX_STATE[$item]:-0}"
        local disabled=0

        # Check if disabled
        for d in "${CHECKBOX_DISABLED[@]}"; do
            [[ "$d" == "$i" ]] && disabled=1 && break
        done

        # Build line
        local prefix="  "
        local box="[ ]"
        local text="$label"

        # Cursor indicator
        if [[ $i -eq $CHECKBOX_CURSOR ]]; then
            prefix="${TUI_BOLD}▸ ${TUI_RESET}"
        fi

        # Checkbox state
        if [[ "$disabled" == "1" ]]; then
            box="${TUI_DIM}[○]${TUI_RESET}"
            text="${TUI_DIM}${text}${TUI_RESET}"
        elif [[ "$checked" == "1" ]]; then
            box="${TUI_GREEN}[●]${TUI_RESET}"
        fi

        # Highlight current line
        if [[ $i -eq $CHECKBOX_CURSOR ]]; then
            tui_goto "$((start_row + i - start))" 0
            tui_clear_line
            echo -n "${prefix}${box} ${TUI_INVERSE}${text}${TUI_RESET}"
        else
            tui_goto "$((start_row + i - start))" 0
            tui_clear_line
            echo -n "${prefix}${box} ${text}"
        fi
    done

    # Show scroll indicators if needed
    if [[ $start -gt 0 ]]; then
        tui_goto "$start_row" "$((TUI_COLS - 5))"
        echo -n "↑ more"
    fi
    if [[ $end -lt $total ]]; then
        tui_goto "$((start_row + visible_height - 1))" "$((TUI_COLS - 5))"
        echo -n "↓ more"
    fi
}
# }}}
```

### 4. Implement Navigation

```bash
# {{{ checkbox_cursor_up
checkbox_cursor_up() {
    if [[ $CHECKBOX_CURSOR -gt 0 ]]; then
        ((CHECKBOX_CURSOR--))

        # Scroll if cursor above visible area
        if [[ $CHECKBOX_CURSOR -lt $CHECKBOX_SCROLL_OFFSET ]]; then
            CHECKBOX_SCROLL_OFFSET=$CHECKBOX_CURSOR
        fi
    fi
}
# }}}

# {{{ checkbox_cursor_down
checkbox_cursor_down() {
    local total=${#CHECKBOX_ITEMS[@]}
    if [[ $CHECKBOX_CURSOR -lt $((total - 1)) ]]; then
        ((CHECKBOX_CURSOR++))

        # Scroll if cursor below visible area
        local visible_end=$((CHECKBOX_SCROLL_OFFSET + CHECKBOX_VISIBLE_COUNT))
        if [[ $CHECKBOX_CURSOR -ge $visible_end ]]; then
            ((CHECKBOX_SCROLL_OFFSET++))
        fi
    fi
}
# }}}

# {{{ checkbox_cursor_top
checkbox_cursor_top() {
    CHECKBOX_CURSOR=0
    CHECKBOX_SCROLL_OFFSET=0
}
# }}}

# {{{ checkbox_cursor_bottom
checkbox_cursor_bottom() {
    local total=${#CHECKBOX_ITEMS[@]}
    CHECKBOX_CURSOR=$((total - 1))

    # Adjust scroll offset
    if [[ $total -gt $CHECKBOX_VISIBLE_COUNT ]]; then
        CHECKBOX_SCROLL_OFFSET=$((total - CHECKBOX_VISIBLE_COUNT))
    fi
}
# }}}

# {{{ checkbox_jump_to_index
checkbox_jump_to_index() {
    local idx="$1"
    local total=${#CHECKBOX_ITEMS[@]}

    # Convert 1-based input to 0-based index
    idx=$((idx - 1))

    if [[ $idx -ge 0 ]] && [[ $idx -lt $total ]]; then
        CHECKBOX_CURSOR=$idx

        # Adjust scroll offset if needed
        if [[ $idx -lt $CHECKBOX_SCROLL_OFFSET ]]; then
            CHECKBOX_SCROLL_OFFSET=$idx
        elif [[ $idx -ge $((CHECKBOX_SCROLL_OFFSET + CHECKBOX_VISIBLE_COUNT)) ]]; then
            CHECKBOX_SCROLL_OFFSET=$((idx - CHECKBOX_VISIBLE_COUNT + 1))
        fi
    fi
}
# }}}
```

### 5. Implement Toggle Functions

```bash
# {{{ checkbox_toggle
checkbox_toggle() {
    local item="${CHECKBOX_ITEMS[$CHECKBOX_CURSOR]}"

    # Check if disabled
    for d in "${CHECKBOX_DISABLED[@]}"; do
        [[ "$d" == "$CHECKBOX_CURSOR" ]] && return 1
    done

    if [[ "${CHECKBOX_STATE[$item]}" == "1" ]]; then
        CHECKBOX_STATE[$item]=0
    else
        CHECKBOX_STATE[$item]=1
    fi
}
# }}}

# {{{ checkbox_select_all
checkbox_select_all() {
    for item in "${CHECKBOX_ITEMS[@]}"; do
        # Skip disabled items
        local idx
        for ((idx = 0; idx < ${#CHECKBOX_ITEMS[@]}; idx++)); do
            if [[ "${CHECKBOX_ITEMS[$idx]}" == "$item" ]]; then
                local disabled=0
                for d in "${CHECKBOX_DISABLED[@]}"; do
                    [[ "$d" == "$idx" ]] && disabled=1 && break
                done
                [[ "$disabled" == "0" ]] && CHECKBOX_STATE[$item]=1
                break
            fi
        done
    done
}
# }}}

# {{{ checkbox_select_none
checkbox_select_none() {
    for item in "${CHECKBOX_ITEMS[@]}"; do
        CHECKBOX_STATE[$item]=0
    done
}
# }}}
```

### 6. Implement Result Retrieval

```bash
# {{{ checkbox_get_selected
checkbox_get_selected() {
    local -a selected=()
    for item in "${CHECKBOX_ITEMS[@]}"; do
        if [[ "${CHECKBOX_STATE[$item]}" == "1" ]]; then
            selected+=("$item")
        fi
    done
    printf '%s\n' "${selected[@]}"
}
# }}}

# {{{ checkbox_get_count
checkbox_get_count() {
    local count=0
    for item in "${CHECKBOX_ITEMS[@]}"; do
        [[ "${CHECKBOX_STATE[$item]}" == "1" ]] && ((count++))
    done
    echo "$count"
}
# }}}
```

### 7. Create Convenience Wrapper

```bash
# {{{ checkbox_run
# Interactive checkbox selection loop
# Returns: selected items via checkbox_get_selected
checkbox_run() {
    local title="${1:-Select items}"

    while true; do
        tui_clear
        tui_goto 0 0
        tui_bold "$title"
        echo
        echo "  Space: toggle  a: all  n: none  Enter: confirm  q: cancel"
        echo

        checkbox_render 10 3

        local key
        key=$(tui_read_key)

        case "$key" in
            UP)     checkbox_cursor_up ;;
            DOWN)   checkbox_cursor_down ;;
            TOP)    checkbox_cursor_top ;;
            BOTTOM) checkbox_cursor_bottom ;;
            TOGGLE) checkbox_toggle ;;
            ALL)    checkbox_select_all ;;
            NONE)   checkbox_select_none ;;
            SELECT) return 0 ;;   # Confirm selection
            QUIT)   return 1 ;;   # Cancel
            INDEX:*) checkbox_jump_to_index "${key#INDEX:}" ;;
        esac
    done
}
# }}}
```

---

## Testing

```bash
#!/usr/bin/env bash
source libs/tui.sh
source libs/checkbox.sh  # or include in tui.sh

tui_init

checkbox_init
checkbox_add_item "option1" "First option" 1      # Pre-checked
checkbox_add_item "option2" "Second option" 0
checkbox_add_item "option3" "Third option (disabled)" 0 1  # Disabled
checkbox_add_item "option4" "Fourth option" 0

if checkbox_run "Select Options"; then
    echo "Selected:"
    checkbox_get_selected
else
    echo "Cancelled"
fi

tui_cleanup
```

---

## Related Documents

- issues/004-redesign-interactive-mode-interface.md (parent)
- issues/004a-create-tui-core-library.md (dependency)

---

## Acceptance Criteria

- [ ] Checkbox items render with correct symbols ([●], [ ], [○])
- [ ] Cursor indicator (▸) shows current position
- [ ] Current line is highlighted/inverse
- [ ] Space toggles checkbox state
- [ ] 'a' selects all non-disabled items
- [ ] 'n' deselects all items
- [ ] j/k and arrow keys move cursor
- [ ] g/G jump to top/bottom
- [ ] Number keys jump to item by index
- [ ] Scrolling works when items exceed visible area
- [ ] Disabled items cannot be toggled
- [ ] `checkbox_get_selected()` returns correct items

---

## Notes

Consider whether this should be a separate file (`libs/checkbox.sh`) or
part of the main TUI library. For now, implement within the context of
issue-splitter but design for reusability.

---

## Implementation Complete

*Implemented on 2025-12-16*

### Changes Made

Created `/home/ritz/programming/ai-stuff/scripts/libs/checkbox.sh` with:

1. **State Management:**
   - `CHECKBOX_STATE` - associative array for checked state
   - `CHECKBOX_DISABLED` - associative array for disabled items
   - `CHECKBOX_ITEMS`, `CHECKBOX_LABELS`, `CHECKBOX_DESCRIPTIONS` - ordered arrays
   - `checkbox_init()` - Reset all state
   - `checkbox_add_item()` - Add item with label, checked, disabled, description

2. **Navigation:**
   - `checkbox_cursor_up()`, `checkbox_cursor_down()`
   - `checkbox_cursor_top()`, `checkbox_cursor_bottom()` (g/G)
   - `checkbox_jump_to_index()` - 1-based index jumping
   - `checkbox_page_up()`, `checkbox_page_down()` - Page navigation
   - Automatic scroll offset management

3. **Toggle Functions:**
   - `checkbox_toggle()` - Toggle current item (respects disabled)
   - `checkbox_select_all()` - Select all non-disabled
   - `checkbox_select_none()` - Deselect all
   - `checkbox_invert_selection()` - Invert all non-disabled

4. **Result Retrieval:**
   - `checkbox_get_selected()` - List of selected IDs
   - `checkbox_get_selected_count()` - Count of selected
   - `checkbox_get_current_id()` - Currently highlighted item
   - `checkbox_is_checked()`, `checkbox_is_disabled()`

5. **Rendering:**
   - `checkbox_render()` - Render at position with visible count
   - `checkbox_render_status()` - Show "Selected: X/Y"
   - Scroll indicators (↑more, ↓more)
   - Color-coded states: green checked, dim disabled
   - Cursor highlight with inverse

6. **Interactive Loop:**
   - `checkbox_run()` - Full interactive selection loop
   - `checkbox_handle_key()` - For integration with other components

### Test Script

Created `libs/test-checkbox.sh` for interactive testing.

### Acceptance Criteria Status

- [x] Checkbox items render with correct symbols ([●], [ ], [○])
- [x] Cursor indicator (▸) shows current position
- [x] Current line is highlighted/inverse
- [x] Space toggles checkbox state
- [x] 'a' selects all non-disabled items
- [x] 'n' deselects all items
- [x] j/k and arrow keys move cursor
- [x] g/G jump to top/bottom
- [x] Number keys jump to item by index
- [x] Scrolling works when items exceed visible area
- [x] Disabled items cannot be toggled
- [x] `checkbox_get_selected()` returns correct items
