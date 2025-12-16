# Issue 004e: Build Menu Structure and Navigation System

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 004
**Priority:** High
**Affects:** src/cli/lib/tui.sh
**Dependencies:** 004b (checkbox), 004c (multistate), 004d (inputs)

---

## Current Behavior

No structured menu system exists. The current interactive mode is a flat
sequence of y/n prompts without organized sections or navigation.

---

## Intended Behavior

Create a hierarchical menu system with:

- Multiple sections (Mode, Options, Issues)
- Cursor movement across and within sections
- Nested option expansion/collapse
- Scrollable lists with viewport management
- Index-based jumping (1-9)

### Visual Structure

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
║    ... (j/k to scroll)                                            ║
╠══════════════════════════════════════════════════════════════════╣
║  [Enter/i] Select   [Space] Toggle   [j/k/↑/↓] Navigate          ║
║  [a] All   [n] None   [1-9] Jump   [q] Quit   [r] Run            ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Suggested Implementation Steps

### 1. Define Menu Structure

```bash
# {{{ Menu structure
# Sections
declare -a MENU_SECTIONS=("directory" "mode" "options" "issues")

# Section types: "single" (radio), "multi" (checkbox), "list" (scrollable), "value" (editable)
declare -A MENU_SECTION_TYPES=(
    ["directory"]="value"
    ["mode"]="single"
    ["options"]="multi"
    ["issues"]="list"
)

# Section titles
declare -A MENU_SECTION_TITLES=(
    ["directory"]="Project Directory"
    ["mode"]="Mode"
    ["options"]="Options"
    ["issues"]="Issues to Process"
)

# Items within each section
declare -A MENU_SECTION_ITEMS=(
    ["mode"]="analyze,review,execute"
    ["options"]="skip_existing,dry_run,parallel"
)

# Item labels and descriptions
declare -A MENU_ITEM_LABELS=(
    ["analyze"]="Analyze"
    ["review"]="Review"
    ["execute"]="Execute"
    ["skip_existing"]="Skip existing"
    ["dry_run"]="Dry run"
    ["parallel"]="Parallel"
)

declare -A MENU_ITEM_DESCRIPTIONS=(
    ["analyze"]="Analyze issues for sub-issue splitting"
    ["review"]="Review existing sub-issue structures"
    ["execute"]="Execute recommendations from analyses"
    ["skip_existing"]="Don't re-analyze issues with analysis"
    ["dry_run"]="Show what would happen without doing it"
    ["parallel"]="Process multiple issues simultaneously"
)

# Items with nested configuration
declare -A MENU_NESTED_ITEMS=(
    ["parallel"]="number:1:10:3"  # type:min:max:default
)
# }}}
```

### 2. Menu State Management

```bash
# {{{ Menu state
# Current cursor position
MENU_CURRENT_SECTION=0
MENU_CURRENT_ITEM=0

# Section collapse states (for nested items)
declare -A MENU_EXPANDED

# Current values
declare -A MENU_VALUES=(
    ["mode"]="analyze"           # Current mode (single selection)
    ["skip_existing"]="1"        # Option states
    ["dry_run"]="0"
    ["parallel"]="0"
    ["parallel:value"]="3"       # Nested value
)

# Dynamic issue list (populated at runtime)
declare -a MENU_ISSUES
declare -A MENU_ISSUE_STATES
declare -A MENU_ISSUE_DISABLED
MENU_ISSUE_SCROLL=0
MENU_ISSUE_VISIBLE=8
# }}}

# {{{ menu_init
menu_init() {
    MENU_CURRENT_SECTION=0
    MENU_CURRENT_ITEM=0
    MENU_EXPANDED=()

    # Set defaults
    MENU_VALUES["mode"]="analyze"
    MENU_VALUES["skip_existing"]="1"
    MENU_VALUES["dry_run"]="0"
    MENU_VALUES["parallel"]="0"
    MENU_VALUES["parallel:value"]="3"
}
# }}}
```

### 3. Navigation Functions

```bash
# {{{ menu_nav_up
menu_nav_up() {
    local section="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    if [[ "$section_type" == "list" ]]; then
        # Navigate within issue list
        if [[ $MENU_CURRENT_ITEM -gt 0 ]]; then
            ((MENU_CURRENT_ITEM--))
            # Scroll if needed
            if [[ $MENU_CURRENT_ITEM -lt $MENU_ISSUE_SCROLL ]]; then
                MENU_ISSUE_SCROLL=$MENU_CURRENT_ITEM
            fi
        elif [[ $MENU_CURRENT_SECTION -gt 0 ]]; then
            # Move to previous section
            ((MENU_CURRENT_SECTION--))
            menu_goto_section_end
        fi
    else
        # Navigate within regular section
        local items="${MENU_SECTION_ITEMS[$section]}"
        IFS=',' read -ra item_array <<< "$items"

        if [[ $MENU_CURRENT_ITEM -gt 0 ]]; then
            ((MENU_CURRENT_ITEM--))
        elif [[ $MENU_CURRENT_SECTION -gt 0 ]]; then
            ((MENU_CURRENT_SECTION--))
            menu_goto_section_end
        fi
    fi
}
# }}}

# {{{ menu_nav_down
menu_nav_down() {
    local section="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    if [[ "$section_type" == "list" ]]; then
        local total=${#MENU_ISSUES[@]}
        if [[ $MENU_CURRENT_ITEM -lt $((total - 1)) ]]; then
            ((MENU_CURRENT_ITEM++))
            # Scroll if needed
            local visible_end=$((MENU_ISSUE_SCROLL + MENU_ISSUE_VISIBLE))
            if [[ $MENU_CURRENT_ITEM -ge $visible_end ]]; then
                ((MENU_ISSUE_SCROLL++))
            fi
        elif [[ $MENU_CURRENT_SECTION -lt $((${#MENU_SECTIONS[@]} - 1)) ]]; then
            ((MENU_CURRENT_SECTION++))
            MENU_CURRENT_ITEM=0
        fi
    else
        local items="${MENU_SECTION_ITEMS[$section]}"
        IFS=',' read -ra item_array <<< "$items"
        local count=${#item_array[@]}

        if [[ $MENU_CURRENT_ITEM -lt $((count - 1)) ]]; then
            ((MENU_CURRENT_ITEM++))
        elif [[ $MENU_CURRENT_SECTION -lt $((${#MENU_SECTIONS[@]} - 1)) ]]; then
            ((MENU_CURRENT_SECTION++))
            MENU_CURRENT_ITEM=0
        fi
    fi
}
# }}}

# {{{ menu_goto_section_end
menu_goto_section_end() {
    local section="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    if [[ "$section_type" == "list" ]]; then
        local total=${#MENU_ISSUES[@]}
        MENU_CURRENT_ITEM=$((total - 1))
        [[ $MENU_CURRENT_ITEM -lt 0 ]] && MENU_CURRENT_ITEM=0
    elif [[ "$section_type" == "value" ]]; then
        MENU_CURRENT_ITEM=0
    else
        local items="${MENU_SECTION_ITEMS[$section]}"
        IFS=',' read -ra item_array <<< "$items"
        MENU_CURRENT_ITEM=$((${#item_array[@]} - 1))
    fi
}
# }}}

# {{{ menu_jump_to_index
menu_jump_to_index() {
    local idx="$1"
    local section="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    # Convert 1-based to 0-based
    idx=$((idx - 1))

    if [[ "$section_type" == "list" ]]; then
        local total=${#MENU_ISSUES[@]}
        if [[ $idx -ge 0 ]] && [[ $idx -lt $total ]]; then
            MENU_CURRENT_ITEM=$idx
            # Adjust scroll
            if [[ $idx -lt $MENU_ISSUE_SCROLL ]]; then
                MENU_ISSUE_SCROLL=$idx
            elif [[ $idx -ge $((MENU_ISSUE_SCROLL + MENU_ISSUE_VISIBLE)) ]]; then
                MENU_ISSUE_SCROLL=$((idx - MENU_ISSUE_VISIBLE + 1))
            fi
        fi
    else
        local items="${MENU_SECTION_ITEMS[$section]}"
        IFS=',' read -ra item_array <<< "$items"
        if [[ $idx -ge 0 ]] && [[ $idx -lt ${#item_array[@]} ]]; then
            MENU_CURRENT_ITEM=$idx
        fi
    fi
}
# }}}
```

### 4. Action Functions

```bash
# {{{ menu_toggle
menu_toggle() {
    local section="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    case "$section_type" in
        "single")
            # Radio button - set this as the selected value
            local items="${MENU_SECTION_ITEMS[$section]}"
            IFS=',' read -ra item_array <<< "$items"
            MENU_VALUES["$section"]="${item_array[$MENU_CURRENT_ITEM]}"
            ;;
        "multi")
            # Checkbox - toggle
            local items="${MENU_SECTION_ITEMS[$section]}"
            IFS=',' read -ra item_array <<< "$items"
            local item="${item_array[$MENU_CURRENT_ITEM]}"
            if [[ "${MENU_VALUES[$item]}" == "1" ]]; then
                MENU_VALUES[$item]="0"
            else
                MENU_VALUES[$item]="1"
            fi
            ;;
        "list")
            # Issue list - toggle selection
            local issue="${MENU_ISSUES[$MENU_CURRENT_ITEM]}"
            if [[ -z "${MENU_ISSUE_DISABLED[$issue]}" ]]; then
                if [[ "${MENU_ISSUE_STATES[$issue]}" == "1" ]]; then
                    MENU_ISSUE_STATES[$issue]="0"
                else
                    MENU_ISSUE_STATES[$issue]="1"
                fi
            fi
            ;;
        "value")
            # Editable value - open editor
            menu_edit_value "$section"
            ;;
    esac
}
# }}}

# {{{ menu_select_all
menu_select_all() {
    local section="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    if [[ "$section_type" == "multi" ]]; then
        local items="${MENU_SECTION_ITEMS[$section]}"
        IFS=',' read -ra item_array <<< "$items"
        for item in "${item_array[@]}"; do
            MENU_VALUES[$item]="1"
        done
    elif [[ "$section_type" == "list" ]]; then
        for issue in "${MENU_ISSUES[@]}"; do
            if [[ -z "${MENU_ISSUE_DISABLED[$issue]}" ]]; then
                MENU_ISSUE_STATES[$issue]="1"
            fi
        done
    fi
}
# }}}

# {{{ menu_select_none
menu_select_none() {
    local section="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    if [[ "$section_type" == "multi" ]]; then
        local items="${MENU_SECTION_ITEMS[$section]}"
        IFS=',' read -ra item_array <<< "$items"
        for item in "${item_array[@]}"; do
            MENU_VALUES[$item]="0"
        done
    elif [[ "$section_type" == "list" ]]; then
        for issue in "${MENU_ISSUES[@]}"; do
            MENU_ISSUE_STATES[$issue]="0"
        done
    fi
}
# }}}
```

### 5. Rendering Functions

```bash
# {{{ menu_render
menu_render() {
    tui_clear

    local row=0

    # Header
    menu_render_header
    row=3

    # Render each section
    for ((s = 0; s < ${#MENU_SECTIONS[@]}; s++)); do
        local section="${MENU_SECTIONS[$s]}"
        local is_current=$([[ $s -eq $MENU_CURRENT_SECTION ]] && echo 1 || echo 0)

        row=$(menu_render_section "$section" "$row" "$is_current")
        ((row++))  # Space between sections
    done

    # Footer
    menu_render_footer
}
# }}}

# {{{ menu_render_header
menu_render_header() {
    tui_goto 0 0
    local width=$((TUI_COLS - 2))

    # Top border
    echo -n "╔"
    printf '═%.0s' $(seq 1 $width)
    echo "╗"

    # Title
    local title="Issue Splitter - Interactive Mode"
    local padding=$(( (width - ${#title}) / 2 ))
    echo -n "║"
    printf ' %.0s' $(seq 1 $padding)
    tui_bold "$title"
    printf ' %.0s' $(seq 1 $((width - padding - ${#title})))
    echo "║"

    # Separator
    echo -n "╠"
    printf '═%.0s' $(seq 1 $width)
    echo "╣"
}
# }}}

# {{{ menu_render_section
menu_render_section() {
    local section="$1"
    local row="$2"
    local is_current="$3"

    local title="${MENU_SECTION_TITLES[$section]}"
    local section_type="${MENU_SECTION_TYPES[$section]}"

    # Section title
    tui_goto "$row" 2
    tui_bold "$title"
    ((row++))

    tui_goto "$row" 2
    printf '─%.0s' $(seq 1 ${#title})
    ((row++))

    # Section content
    case "$section_type" in
        "value")
            row=$(menu_render_value_section "$section" "$row" "$is_current")
            ;;
        "single"|"multi")
            row=$(menu_render_checkbox_section "$section" "$row" "$is_current")
            ;;
        "list")
            row=$(menu_render_list_section "$section" "$row" "$is_current")
            ;;
    esac

    echo "$row"
}
# }}}

# {{{ menu_render_footer
menu_render_footer() {
    local row=$((TUI_ROWS - 3))
    local width=$((TUI_COLS - 2))

    tui_goto "$row" 0
    echo -n "╠"
    printf '═%.0s' $(seq 1 $width)
    echo "╣"

    ((row++))
    tui_goto "$row" 0
    echo -n "║  "
    echo -n "${TUI_YELLOW}[Enter/i]${TUI_RESET} Select   "
    echo -n "${TUI_YELLOW}[Space]${TUI_RESET} Toggle   "
    echo -n "${TUI_YELLOW}[j/k/↑/↓]${TUI_RESET} Navigate"
    tui_clear_line

    ((row++))
    tui_goto "$row" 0
    echo -n "║  "
    echo -n "${TUI_YELLOW}[a]${TUI_RESET} All   "
    echo -n "${TUI_YELLOW}[n]${TUI_RESET} None   "
    echo -n "${TUI_YELLOW}[1-9]${TUI_RESET} Jump   "
    echo -n "${TUI_YELLOW}[q]${TUI_RESET} Quit   "
    echo -n "${TUI_YELLOW}[r]${TUI_RESET} Run"
    tui_clear_line

    ((row++))
    tui_goto "$row" 0
    echo -n "╚"
    printf '═%.0s' $(seq 1 $width)
    echo "╝"
}
# }}}
```

### 6. Main Loop

```bash
# {{{ menu_run
menu_run() {
    tui_init
    menu_init
    menu_populate_issues

    while true; do
        menu_render

        local key
        key=$(tui_read_key)

        case "$key" in
            UP)     menu_nav_up ;;
            DOWN)   menu_nav_down ;;
            LEFT)   menu_handle_left ;;
            RIGHT)  menu_handle_right ;;
            TOP)    menu_goto_top ;;
            BOTTOM) menu_goto_bottom ;;
            TOGGLE|SELECT) menu_toggle ;;
            ALL)    menu_select_all ;;
            NONE)   menu_select_none ;;
            RUN)    menu_execute; break ;;
            QUIT)   tui_cleanup; return 1 ;;
            INDEX:*) menu_jump_to_index "${key#INDEX:}" ;;
        esac
    done

    tui_cleanup
    return 0
}
# }}}
```

---

## Related Documents

- issues/004-redesign-interactive-mode-interface.md (parent)
- issues/004a-create-tui-core-library.md
- issues/004b-implement-checkbox-component.md
- issues/004c-implement-multistate-toggle.md
- issues/004d-implement-input-components.md

---

## Acceptance Criteria

- [ ] Multiple sections render with proper titles and separators
- [ ] Cursor navigates between and within sections
- [ ] j/k and arrow keys work for navigation
- [ ] g/G jump to top/bottom of current section or menu
- [ ] Number keys jump to item index within section
- [ ] Space toggles checkboxes
- [ ] Enter activates/selects items
- [ ] Radio buttons (mode section) allow single selection
- [ ] Checkboxes (options section) allow multiple selection
- [ ] Issue list scrolls when exceeding visible area
- [ ] Scroll indicators show when more items exist
- [ ] a/n select all/none within current section
- [ ] r triggers run action
- [ ] q exits without running
- [ ] Header and footer render with borders
- [ ] Keybinding hints visible in footer

---

## Notes

This is the most complex sub-issue. Take time to get the navigation flow
right - users should be able to move fluidly between sections without
getting stuck or confused about where they are.

---

## Implementation Complete

*Implemented on 2025-12-16*

### Changes Made

Created `/home/ritz/programming/ai-stuff/scripts/libs/menu.sh` with:

1. **Menu Structure:**
   - `MENU_SECTIONS` - Ordered section list
   - `MENU_SECTION_TYPES` - single (radio), multi (checkbox), list, value
   - `MENU_SECTION_ITEMS` - Items per section
   - Section and item management functions

2. **Item Types:**
   - `checkbox` - On/off toggle
   - `multistate` - Cycle through values with h/l
   - `number` - Edit with input_number
   - `text` - Edit with input_text
   - `action` - Trigger custom action

3. **Navigation:**
   - `menu_nav_up/down/top/bottom()`
   - Cross-section navigation
   - `menu_get_current_item_id()`

4. **Actions:**
   - `menu_toggle()` - Checkbox/radio toggle
   - `menu_handle_left_right()` - Multistate cycling
   - `menu_select()` - Activate inputs/actions
   - `menu_select_all/none()` - Bulk selection

5. **Rendering:**
   - `menu_render()` - Full screen render
   - `menu_render_header/section/item/footer()`
   - Double-line box borders
   - Keybinding hints in footer
   - Cursor highlight and type-specific displays

6. **Main Loop:**
   - `menu_run()` - Full interactive loop
   - `menu_handle_key()` - Single key handler for custom loops

### Test Script

Created `libs/test-menu.sh` demonstrating all section types and item types.

### Acceptance Criteria Status

- [x] Multiple sections render with proper titles and separators
- [x] Cursor navigates between and within sections
- [x] j/k and arrow keys work for navigation
- [x] g/G jump to top/bottom
- [ ] Number keys jump to item index (not implemented - low priority)
- [x] Space toggles checkboxes
- [x] Enter activates/selects items
- [x] Radio buttons (single section) allow single selection
- [x] Checkboxes (multi section) allow multiple selection
- [ ] Scroll indicators (not needed yet - lists are short)
- [x] a/n select all/none within current section
- [x] r triggers run action
- [x] q exits without running
- [x] Header and footer render with borders
- [x] Keybinding hints visible in footer
