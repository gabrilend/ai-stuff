#!/usr/bin/env bash
# Menu Navigation System - Hierarchical menu with multiple section types
# Brings together checkbox, multistate, and input components into a unified
# navigation system with sections and keyboard controls.
#
# Usage: source this file after all component libraries, then use menu_* functions.

# Prevent double-sourcing
[[ -n "${_MENU_LOADED:-}" ]] && return 0
_MENU_LOADED=1

# Library directory
MENU_LIB_DIR="${MENU_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Ensure dependencies are loaded
[[ -z "${_TUI_LOADED:-}" ]] && source "${MENU_LIB_DIR}/tui.sh"
[[ -z "${_CHECKBOX_LOADED:-}" ]] && source "${MENU_LIB_DIR}/checkbox.sh"
[[ -z "${_MULTISTATE_LOADED:-}" ]] && source "${MENU_LIB_DIR}/multistate.sh"
[[ -z "${_INPUT_LOADED:-}" ]] && source "${MENU_LIB_DIR}/input.sh"

# ============================================================================
# Menu Structure
# ============================================================================

# Section definitions
declare -a MENU_SECTIONS              # Ordered section IDs
declare -A MENU_SECTION_TYPES         # section_id -> type (single|multi|list|value)
declare -A MENU_SECTION_TITLES        # section_id -> display title
declare -A MENU_SECTION_ITEMS         # section_id -> comma-separated item IDs

# Item definitions
declare -A MENU_ITEM_LABELS           # item_id -> display label
declare -A MENU_ITEM_DESCRIPTIONS     # item_id -> description
declare -A MENU_ITEM_TYPES            # item_id -> type (checkbox|multistate|number|text|action)
declare -A MENU_ITEM_CONFIG           # item_id -> type-specific config

# State
declare -A MENU_VALUES                # item_id -> current value
declare -A MENU_ITEM_DISABLED         # item_id -> 1 if disabled

# Navigation
MENU_CURRENT_SECTION=0
MENU_CURRENT_ITEM=0
MENU_TITLE=""
MENU_SUBTITLE=""

# Render settings
MENU_HEADER_HEIGHT=4
MENU_FOOTER_HEIGHT=4

# ============================================================================
# Initialization
# ============================================================================

# {{{ menu_init
# Initialize/reset menu state
menu_init() {
    MENU_SECTIONS=()
    MENU_SECTION_TYPES=()
    MENU_SECTION_TITLES=()
    MENU_SECTION_ITEMS=()

    MENU_ITEM_LABELS=()
    MENU_ITEM_DESCRIPTIONS=()
    MENU_ITEM_TYPES=()
    MENU_ITEM_CONFIG=()

    MENU_VALUES=()
    MENU_ITEM_DISABLED=()

    MENU_CURRENT_SECTION=0
    MENU_CURRENT_ITEM=0
    MENU_TITLE=""
    MENU_SUBTITLE=""

    # Reset component states
    checkbox_init
    multistate_init
}
# }}}

# {{{ menu_set_title
menu_set_title() {
    MENU_TITLE="$1"
    MENU_SUBTITLE="${2:-}"
}
# }}}

# ============================================================================
# Section Management
# ============================================================================

# {{{ menu_add_section
# Add a section to the menu
# Args: id type title
# Types: single (radio), multi (checkbox), list (scrollable checkbox), value (editable)
menu_add_section() {
    local id="$1"
    local type="$2"
    local title="$3"

    MENU_SECTIONS+=("$id")
    MENU_SECTION_TYPES[$id]="$type"
    MENU_SECTION_TITLES[$id]="$title"
    MENU_SECTION_ITEMS[$id]=""
}
# }}}

# ============================================================================
# Item Management
# ============================================================================

# {{{ menu_add_item
# Add an item to a section
# Args: section_id item_id label [type] [config] [description]
# Types: checkbox (default), multistate, number, text, action
menu_add_item() {
    local section_id="$1"
    local item_id="$2"
    local label="$3"
    local type="${4:-checkbox}"
    local config="${5:-}"
    local description="${6:-}"

    # Add to section
    if [[ -z "${MENU_SECTION_ITEMS[$section_id]}" ]]; then
        MENU_SECTION_ITEMS[$section_id]="$item_id"
    else
        MENU_SECTION_ITEMS[$section_id]="${MENU_SECTION_ITEMS[$section_id]},$item_id"
    fi

    MENU_ITEM_LABELS[$item_id]="$label"
    MENU_ITEM_DESCRIPTIONS[$item_id]="$description"
    MENU_ITEM_TYPES[$item_id]="$type"
    MENU_ITEM_CONFIG[$item_id]="$config"

    # Set default value based on type
    case "$type" in
        checkbox)
            MENU_VALUES[$item_id]="${config:-0}"
            ;;
        multistate)
            # Config format: "state1,state2,state3:default"
            local states="${config%:*}"
            local default="${config#*:}"
            [[ "$default" == "$config" ]] && default="${states%%,*}"
            multistate_add "$item_id" "$states" "$default" "$label"
            ;;
        number)
            # Config format: "min:max:default"
            IFS=':' read -r min max default <<< "$config"
            MENU_VALUES[$item_id]="${default:-$min}"
            ;;
        text)
            MENU_VALUES[$item_id]="${config:-}"
            ;;
        action)
            # No value for actions
            ;;
    esac
}
# }}}

# {{{ menu_set_value
menu_set_value() {
    local item_id="$1"
    local value="$2"

    local type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"

    case "$type" in
        multistate)
            multistate_set "$item_id" "$value"
            ;;
        *)
            MENU_VALUES[$item_id]="$value"
            ;;
    esac
}
# }}}

# {{{ menu_get_value
menu_get_value() {
    local item_id="$1"

    local type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"

    case "$type" in
        multistate)
            multistate_get "$item_id"
            ;;
        *)
            echo "${MENU_VALUES[$item_id]:-}"
            ;;
    esac
}
# }}}

# {{{ menu_set_disabled
menu_set_disabled() {
    local item_id="$1"
    local disabled="${2:-1}"

    if [[ "$disabled" == "1" ]]; then
        MENU_ITEM_DISABLED[$item_id]=1
    else
        unset 'MENU_ITEM_DISABLED[$item_id]'
    fi
}
# }}}

# ============================================================================
# Navigation
# ============================================================================

# {{{ menu_get_items_in_section
# Get array of items in a section
menu_get_items_in_section() {
    local section_id="$1"
    local items="${MENU_SECTION_ITEMS[$section_id]:-}"
    IFS=',' read -ra result <<< "$items"
    printf '%s\n' "${result[@]}"
}
# }}}

# {{{ menu_get_section_item_count
menu_get_section_item_count() {
    local section_id="$1"
    local items="${MENU_SECTION_ITEMS[$section_id]:-}"
    if [[ -z "$items" ]]; then
        echo 0
    else
        IFS=',' read -ra arr <<< "$items"
        echo "${#arr[@]}"
    fi
}
# }}}

# {{{ menu_nav_up
menu_nav_up() {
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local count
    count=$(menu_get_section_item_count "$section_id")

    if [[ $MENU_CURRENT_ITEM -gt 0 ]]; then
        ((MENU_CURRENT_ITEM--))
    elif [[ $MENU_CURRENT_SECTION -gt 0 ]]; then
        ((MENU_CURRENT_SECTION--))
        section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
        count=$(menu_get_section_item_count "$section_id")
        MENU_CURRENT_ITEM=$((count - 1))
        [[ $MENU_CURRENT_ITEM -lt 0 ]] && MENU_CURRENT_ITEM=0
    fi
}
# }}}

# {{{ menu_nav_down
menu_nav_down() {
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local count
    count=$(menu_get_section_item_count "$section_id")

    if [[ $MENU_CURRENT_ITEM -lt $((count - 1)) ]]; then
        ((MENU_CURRENT_ITEM++))
    elif [[ $MENU_CURRENT_SECTION -lt $((${#MENU_SECTIONS[@]} - 1)) ]]; then
        ((MENU_CURRENT_SECTION++))
        MENU_CURRENT_ITEM=0
    fi
}
# }}}

# {{{ menu_nav_top
menu_nav_top() {
    MENU_CURRENT_SECTION=0
    MENU_CURRENT_ITEM=0
}
# }}}

# {{{ menu_nav_bottom
menu_nav_bottom() {
    MENU_CURRENT_SECTION=$((${#MENU_SECTIONS[@]} - 1))
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local count
    count=$(menu_get_section_item_count "$section_id")
    MENU_CURRENT_ITEM=$((count - 1))
    [[ $MENU_CURRENT_ITEM -lt 0 ]] && MENU_CURRENT_ITEM=0
}
# }}}

# {{{ menu_nav_to_index
# Navigate to a specific 1-based index within the current section
# Args: index (1-based, as displayed to user)
menu_nav_to_index() {
    local index="$1"
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local count
    count=$(menu_get_section_item_count "$section_id")

    # Convert 1-based user input to 0-based array index
    local target=$((index - 1))

    # Clamp to valid range
    if [[ $target -lt 0 ]]; then
        target=0
    elif [[ $target -ge $count ]]; then
        target=$((count - 1))
    fi

    MENU_CURRENT_ITEM=$target
}
# }}}

# {{{ menu_nav_to_global_index
# Navigate to a specific 1-based global index across all sections
# Args: index (1-based, as displayed to user)
menu_nav_to_global_index() {
    local target_index="$1"
    local current_index=0

    for ((s=0; s<${#MENU_SECTIONS[@]}; s++)); do
        local section_id="${MENU_SECTIONS[$s]}"
        local count
        count=$(menu_get_section_item_count "$section_id")

        for ((i=0; i<count; i++)); do
            current_index=$((current_index + 1))
            if [[ $current_index -eq $target_index ]]; then
                MENU_CURRENT_SECTION=$s
                MENU_CURRENT_ITEM=$i
                return 0
            fi
        done
    done

    # If index is too large, go to last item
    if [[ $target_index -gt $current_index ]]; then
        menu_nav_bottom
    fi
}
# }}}

# {{{ menu_get_current_item_id
menu_get_current_item_id() {
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local items="${MENU_SECTION_ITEMS[$section_id]:-}"
    IFS=',' read -ra arr <<< "$items"
    echo "${arr[$MENU_CURRENT_ITEM]:-}"
}
# }}}

# ============================================================================
# Actions
# ============================================================================

# {{{ menu_toggle
# Toggle current item (for checkboxes and radio buttons)
menu_toggle() {
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section_id]}"
    local item_id
    item_id=$(menu_get_current_item_id)

    [[ -z "$item_id" ]] && return 1
    [[ -n "${MENU_ITEM_DISABLED[$item_id]:-}" ]] && return 1

    local item_type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"

    case "$section_type" in
        single)
            # Radio button - set this as selected, clear others
            local items="${MENU_SECTION_ITEMS[$section_id]}"
            IFS=',' read -ra arr <<< "$items"
            for it in "${arr[@]}"; do
                MENU_VALUES[$it]=0
            done
            MENU_VALUES[$item_id]=1
            ;;
        multi|list)
            # Checkbox - toggle
            if [[ "${MENU_VALUES[$item_id]:-0}" == "1" ]]; then
                MENU_VALUES[$item_id]=0
            else
                MENU_VALUES[$item_id]=1
            fi
            ;;
    esac
}
# }}}

# {{{ menu_handle_left_right
# Handle left/right keys for checkboxes (select/deselect) and multistate (cycle)
menu_handle_left_right() {
    local direction="$1"  # "left" or "right"
    local item_id
    item_id=$(menu_get_current_item_id)

    [[ -z "$item_id" ]] && return 1
    [[ -n "${MENU_ITEM_DISABLED[$item_id]:-}" ]] && return 1

    local item_type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section_id]}"

    case "$item_type" in
        checkbox)
            # RIGHT = select (check), LEFT = deselect (uncheck)
            if [[ "$direction" == "right" ]]; then
                if [[ "$section_type" == "single" ]]; then
                    # Radio button - clear others first
                    local items="${MENU_SECTION_ITEMS[$section_id]}"
                    IFS=',' read -ra arr <<< "$items"
                    for it in "${arr[@]}"; do
                        MENU_VALUES[$it]=0
                    done
                fi
                MENU_VALUES[$item_id]=1
            else
                # LEFT = deselect (but not for single/radio sections)
                if [[ "$section_type" != "single" ]]; then
                    MENU_VALUES[$item_id]=0
                fi
            fi
            return 0
            ;;
        multistate)
            # LEFT/RIGHT cycles through multistate options
            multistate_cycle "$item_id" "$direction"
            return 0
            ;;
    esac

    return 1
}
# }}}

# {{{ menu_select
# Select/activate current item (for inputs and actions)
menu_select() {
    local item_id
    item_id=$(menu_get_current_item_id)

    [[ -z "$item_id" ]] && return 1
    [[ -n "${MENU_ITEM_DISABLED[$item_id]:-}" ]] && return 1

    local item_type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"
    local config="${MENU_ITEM_CONFIG[$item_id]:-}"
    local label="${MENU_ITEM_LABELS[$item_id]:-$item_id}"

    case "$item_type" in
        number)
            IFS=':' read -r min max default <<< "$config"
            local current="${MENU_VALUES[$item_id]:-$default}"
            local result
            result=$(input_number "$label" "$min" "$max" "$current")
            if [[ $? -eq 0 ]] && [[ "$result" != "-1" ]]; then
                MENU_VALUES[$item_id]="$result"
            fi
            ;;
        text)
            local current="${MENU_VALUES[$item_id]:-}"
            local result
            result=$(input_text "$label" "$current")
            if [[ $? -eq 0 ]]; then
                MENU_VALUES[$item_id]="$result"
            fi
            ;;
        action)
            # Return the action ID for the caller to handle
            echo "$item_id"
            return 2  # Special return code for action
            ;;
        *)
            # For checkbox/multistate, select = toggle
            menu_toggle
            ;;
    esac
}
# }}}

# {{{ menu_select_all
# Select all items in current section
menu_select_all() {
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section_id]}"

    if [[ "$section_type" == "multi" ]] || [[ "$section_type" == "list" ]]; then
        local items="${MENU_SECTION_ITEMS[$section_id]}"
        IFS=',' read -ra arr <<< "$items"
        for item in "${arr[@]}"; do
            if [[ -z "${MENU_ITEM_DISABLED[$item]:-}" ]]; then
                MENU_VALUES[$item]=1
            fi
        done
    fi
}
# }}}

# {{{ menu_select_none
# Deselect all items in current section
menu_select_none() {
    local section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local section_type="${MENU_SECTION_TYPES[$section_id]}"

    if [[ "$section_type" == "multi" ]] || [[ "$section_type" == "list" ]]; then
        local items="${MENU_SECTION_ITEMS[$section_id]}"
        IFS=',' read -ra arr <<< "$items"
        for item in "${arr[@]}"; do
            MENU_VALUES[$item]=0
        done
    fi
}
# }}}

# ============================================================================
# Rendering
# ============================================================================

# {{{ menu_render
# Render the full menu
menu_render() {
    tui_clear

    local row=0
    local global_index=0  # Track global item number for [1-9] jump

    # Header
    row=$(menu_render_header)

    # Sections
    for ((s = 0; s < ${#MENU_SECTIONS[@]}; s++)); do
        local section_id="${MENU_SECTIONS[$s]}"
        local is_current=$([[ $s -eq $MENU_CURRENT_SECTION ]] && echo 1 || echo 0)
        # menu_render_section returns "row:global_index"
        local result
        result=$(menu_render_section "$section_id" "$row" "$is_current" "$global_index")
        row="${result%:*}"
        global_index="${result#*:}"
        ((row++))  # Space between sections
    done

    # Footer
    menu_render_footer
}
# }}}

# {{{ menu_render_header
menu_render_header() {
    local width=$((TUI_COLS - 2))

    tui_goto 0 0
    tui_box_top "$TUI_COLS" double

    tui_goto 1 0
    tui_box_line "$TUI_COLS" "${TUI_BOLD}${MENU_TITLE}${TUI_RESET}" center double

    if [[ -n "$MENU_SUBTITLE" ]]; then
        tui_goto 2 0
        tui_box_line "$TUI_COLS" "${TUI_DIM}${MENU_SUBTITLE}${TUI_RESET}" center double
    fi

    tui_goto 3 0
    tui_box_separator "$TUI_COLS" double

    echo 4
}
# }}}

# {{{ menu_render_section
menu_render_section() {
    local section_id="$1"
    local start_row="$2"
    local is_current="$3"
    local global_index="${4:-0}"

    local title="${MENU_SECTION_TITLES[$section_id]}"
    local items="${MENU_SECTION_ITEMS[$section_id]:-}"
    local row=$start_row

    # Section title
    tui_goto "$row" 2
    tui_bold "$title"
    ((row++))

    tui_goto "$row" 2
    tui_hline "${#title}" "─"
    ((row++))

    # Items
    if [[ -n "$items" ]]; then
        IFS=',' read -ra arr <<< "$items"
        for ((i = 0; i < ${#arr[@]}; i++)); do
            local item_id="${arr[$i]}"
            local highlight=0

            if [[ "$is_current" == "1" ]] && [[ $i -eq $MENU_CURRENT_ITEM ]]; then
                highlight=1
            fi

            ((global_index++))
            menu_render_item "$item_id" "$row" "$highlight" "$global_index"
            ((row++))
        done
    fi

    # Return both row and global_index
    echo "$row:$global_index"
}
# }}}

# {{{ menu_render_item
menu_render_item() {
    local item_id="$1"
    local row="$2"
    local highlight="$3"
    local item_num="${4:-}"

    local label="${MENU_ITEM_LABELS[$item_id]:-$item_id}"
    local desc="${MENU_ITEM_DESCRIPTIONS[$item_id]:-}"
    local type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"
    local disabled="${MENU_ITEM_DISABLED[$item_id]:-}"
    local value="${MENU_VALUES[$item_id]:-}"

    tui_goto "$row" 0
    tui_clear_line

    # Item number (1-9 shown, 10+ shown as *)
    if [[ -n "$item_num" ]]; then
        if [[ "$item_num" -le 9 ]]; then
            echo -n "${TUI_DIM}${item_num}${TUI_RESET}"
        else
            echo -n "${TUI_DIM}*${TUI_RESET}"
        fi
    fi

    # Cursor indicator
    if [[ "$highlight" == "1" ]]; then
        echo -n "${TUI_BOLD}▸${TUI_RESET}"
    else
        echo -n " "
    fi

    case "$type" in
        checkbox)
            if [[ -n "$disabled" ]]; then
                echo -n "${TUI_DIM}[○]${TUI_RESET}"
            elif [[ "$value" == "1" ]]; then
                echo -n "${TUI_GREEN}[●]${TUI_RESET}"
            else
                echo -n "[ ]"
            fi
            echo -n " "
            ;;
        multistate)
            echo -n "  "  # No checkbox for multistate
            ;;
        number)
            echo -n "  "
            ;;
        text)
            echo -n "  "
            ;;
        action)
            echo -n "  "
            ;;
    esac

    # Label
    if [[ "$highlight" == "1" ]]; then
        if [[ -n "$disabled" ]]; then
            echo -n "${TUI_DIM}${TUI_INVERSE}${label}${TUI_RESET}"
        else
            echo -n "${TUI_INVERSE}${label}${TUI_RESET}"
        fi
    else
        if [[ -n "$disabled" ]]; then
            echo -n "${TUI_DIM}${label}${TUI_RESET}"
        else
            echo -n "$label"
        fi
    fi

    # Type-specific value display
    case "$type" in
        multistate)
            echo -n " "
            if [[ "$highlight" == "1" ]]; then
                echo -n "${TUI_CYAN}◀${TUI_RESET}"
                echo -n "[$(multistate_get "$item_id" | tr '[:lower:]' '[:upper:]')]"
                echo -n "${TUI_CYAN}▶${TUI_RESET}"
            else
                echo -n "${TUI_DIM}◀${TUI_RESET}"
                echo -n "[$(multistate_get "$item_id" | tr '[:lower:]' '[:upper:]')]"
                echo -n "${TUI_DIM}▶${TUI_RESET}"
            fi
            ;;
        number)
            local config="${MENU_ITEM_CONFIG[$item_id]:-}"
            IFS=':' read -r min max default <<< "$config"
            echo -n " [${value}] ${TUI_DIM}(${min}-${max})${TUI_RESET}"
            ;;
        text)
            local display_val="${value:0:30}"
            [[ ${#value} -gt 30 ]] && display_val="${display_val}..."
            echo -n " [${display_val}]"
            ;;
        action)
            echo -n " ${TUI_CYAN}→${TUI_RESET}"
            ;;
    esac

    # Description (on highlight)
    if [[ "$highlight" == "1" ]] && [[ -n "$desc" ]]; then
        echo
        tui_goto "$((row + 1))" 6
        echo -n "${TUI_DIM}${desc}${TUI_RESET}"
    fi
}
# }}}

# {{{ menu_render_footer
menu_render_footer() {
    local row=$((TUI_ROWS - 4))

    tui_goto "$row" 0
    tui_box_separator "$TUI_COLS" double

    ((row++))
    tui_goto "$row" 0
    tui_box_line "$TUI_COLS" \
        "${TUI_YELLOW}[Enter/i]${TUI_RESET} Select  ${TUI_YELLOW}[Space]${TUI_RESET} Toggle  ${TUI_YELLOW}[j/k]${TUI_RESET} Navigate  ${TUI_YELLOW}[h/l]${TUI_RESET} Cycle" \
        left double

    ((row++))
    tui_goto "$row" 0
    tui_box_line "$TUI_COLS" \
        "${TUI_YELLOW}[1-9]${TUI_RESET} Jump  ${TUI_YELLOW}[a]${TUI_RESET} All  ${TUI_YELLOW}[n]${TUI_RESET} None  ${TUI_YELLOW}[g/G]${TUI_RESET} Top/Bot  ${TUI_YELLOW}[r]${TUI_RESET} Run  ${TUI_YELLOW}[q]${TUI_RESET} Quit" \
        left double

    ((row++))
    tui_goto "$row" 0
    tui_box_bottom "$TUI_COLS" double
}
# }}}

# ============================================================================
# Main Loop
# ============================================================================

# {{{ menu_run
# Run the menu interactively
# Returns: 0 if user pressed Run, 1 if Quit
menu_run() {
    while true; do
        menu_render

        local key
        key=$(tui_read_key)

        case "$key" in
            UP)     menu_nav_up ;;
            DOWN)   menu_nav_down ;;
            TOP)    menu_nav_top ;;
            BOTTOM) menu_nav_bottom ;;
            LEFT)   menu_handle_left_right "left" ;;
            RIGHT)  menu_handle_left_right "right" ;;
            TOGGLE) menu_toggle ;;
            SELECT)
                local action
                action=$(menu_select)
                local ret=$?
                if [[ $ret -eq 2 ]]; then
                    # Action was triggered
                    case "$action" in
                        run) return 0 ;;
                        quit) return 1 ;;
                        *) ;;  # Custom actions handled by caller
                    esac
                fi
                ;;
            INDEX:*)
                # Number key pressed - jump to that index (1-based)
                local index="${key#INDEX:}"
                menu_nav_to_global_index "$index"
                ;;
            ALL)    menu_select_all ;;
            NONE)   menu_select_none ;;
            RUN)    return 0 ;;
            QUIT|ESCAPE) return 1 ;;
        esac
    done
}
# }}}

# {{{ menu_handle_key
# Handle a single key (for custom loops)
# Returns: "run", "quit", action_id, or empty string
menu_handle_key() {
    local key="$1"

    case "$key" in
        UP)     menu_nav_up ;;
        DOWN)   menu_nav_down ;;
        TOP)    menu_nav_top ;;
        BOTTOM) menu_nav_bottom ;;
        LEFT)   menu_handle_left_right "left" ;;
        RIGHT)  menu_handle_left_right "right" ;;
        TOGGLE) menu_toggle ;;
        SELECT)
            local action
            action=$(menu_select)
            if [[ $? -eq 2 ]]; then
                echo "$action"
                return
            fi
            ;;
        INDEX:*)
            # Number key pressed - jump to that index (1-based)
            local index="${key#INDEX:}"
            menu_nav_to_global_index "$index"
            ;;
        ALL)    menu_select_all ;;
        NONE)   menu_select_none ;;
        RUN)    echo "run"; return ;;
        QUIT|ESCAPE) echo "quit"; return ;;
    esac

    echo ""
}
# }}}
