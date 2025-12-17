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

# Inline editing state
MENU_EDITING_ITEM=""                  # item_id being edited inline (empty = not editing)
MENU_EDIT_BUFFER=""                   # current edit buffer for inline editing

# Render settings
MENU_HEADER_HEIGHT=4
MENU_FOOTER_HEIGHT=4
MENU_FLAG_WIDTH=10                    # Width of flag value display box
MENU_DESC_MAX_LINES=3                 # Maximum lines for description area

# Render state (used to return values from render functions without subshells)
MENU_RENDER_ROW=0
MENU_RENDER_GLOBAL_INDEX=0
MENU_ITEMS_END_ROW=0                  # Row after last item (for description area)

# Item position cache for incremental updates
declare -A MENU_ITEM_ROWS              # "section:item_idx" -> screen row
declare -A MENU_ITEM_GLOBAL_IDX        # "section:item_idx" -> global index (1-based)
declare -A MENU_ITEM_IDS               # "section:item_idx" -> item_id
MENU_NEEDS_FULL_REDRAW=1               # 1 = need full redraw, 0 = can do incremental

# Previous cursor position (for incremental updates)
MENU_PREV_SECTION=-1
MENU_PREV_ITEM=-1

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

    # Reset inline editing state
    MENU_EDITING_ITEM=""
    MENU_EDIT_BUFFER=""

    # Reset position cache
    MENU_ITEM_ROWS=()
    MENU_ITEM_GLOBAL_IDX=()
    MENU_ITEM_IDS=()
    MENU_NEEDS_FULL_REDRAW=1
    MENU_PREV_SECTION=-1
    MENU_PREV_ITEM=-1

    # DEBUG: Initialize frame-by-frame logging
    # DEPRECATED: Remove after issue 004 is resolved (causes SSD wear)
    # See: scripts/issues/004-fix-tui-menu-incremental-rendering.md
    MENU_DEBUG_FRAME_COUNT=0
    # Store debug frames in project directory (relative to this library)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    MENU_DEBUG_DIR="${script_dir}/../debug/menu_frames"
    rm -rf "$MENU_DEBUG_DIR" 2>/dev/null || true
    mkdir -p "$MENU_DEBUG_DIR"
    echo "=== Debug Session Started: $(date) ===" > "${MENU_DEBUG_DIR}/summary.log"
    echo "Debug directory: $MENU_DEBUG_DIR" >> "${MENU_DEBUG_DIR}/summary.log"
    echo "Cleared debug directory, ready for frame capture" >> "${MENU_DEBUG_DIR}/summary.log"

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
# Types: checkbox (default), multistate, number, text, action, flag
#
# Flag type config format: "default:width" (width optional, default 10)
#   - Inline editable numeric value with right-justified display
#   - Type numbers directly when highlighted
#   - RIGHT sets to default, LEFT sets to 0 (disabled)
#   - Backspace erases, Enter confirms
#   - Value of 0 or empty means flag is disabled
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
        flag)
            # Config format: "default:width" - inline editable value
            # default = value to set on RIGHT, width = display width (default 10)
            local default="${config%%:*}"
            MENU_VALUES[$item_id]="${default:-0}"
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
        flag)
            # RIGHT = set to default, LEFT = set to 0 (disable)
            local config="${MENU_ITEM_CONFIG[$item_id]:-}"
            local default="${config%%:*}"
            if [[ "$direction" == "right" ]]; then
                # Set to default (if there is one)
                if [[ -n "$default" ]] && [[ "$default" != "0" ]]; then
                    MENU_VALUES[$item_id]="$default"
                    # Clear any editing state
                    MENU_EDITING_ITEM=""
                    MENU_EDIT_BUFFER=""
                fi
            else
                # LEFT = disable (set to 0)
                MENU_VALUES[$item_id]="0"
                MENU_EDITING_ITEM=""
                MENU_EDIT_BUFFER=""
            fi
            return 0
            ;;
    esac

    return 1
}
# }}}

# {{{ menu_flag_start_edit
# Start inline editing for a flag item
menu_flag_start_edit() {
    local item_id
    item_id=$(menu_get_current_item_id)
    [[ -z "$item_id" ]] && return 1

    local item_type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"
    [[ "$item_type" != "flag" ]] && return 1

    MENU_EDITING_ITEM="$item_id"
    MENU_EDIT_BUFFER="${MENU_VALUES[$item_id]:-}"
    # If current value is 0, start with empty buffer
    [[ "$MENU_EDIT_BUFFER" == "0" ]] && MENU_EDIT_BUFFER=""
    return 0
}
# }}}

# {{{ menu_flag_commit_edit
# Commit the current edit buffer to the flag value
menu_flag_commit_edit() {
    if [[ -n "$MENU_EDITING_ITEM" ]]; then
        # Commit buffer to value (empty becomes 0)
        local new_val="${MENU_EDIT_BUFFER:-0}"
        MENU_VALUES[$MENU_EDITING_ITEM]="$new_val"
        MENU_EDITING_ITEM=""
        MENU_EDIT_BUFFER=""
    fi
}
# }}}

# {{{ menu_flag_handle_key
# Handle a key during flag inline editing
# Args: key
# Returns: 0 if handled, 1 if should pass through
menu_flag_handle_key() {
    local key="$1"
    local item_id
    item_id=$(menu_get_current_item_id)

    local item_type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"

    # If not on a flag item, don't handle
    [[ "$item_type" != "flag" ]] && return 1

    case "$key" in
        INDEX:*)
            # Digit pressed - start editing if not already, then append
            local digit="${key#INDEX:}"
            if [[ -z "$MENU_EDITING_ITEM" ]]; then
                menu_flag_start_edit
                MENU_EDIT_BUFFER="$digit"
            else
                MENU_EDIT_BUFFER="${MENU_EDIT_BUFFER}${digit}"
            fi
            return 0
            ;;
        BACKSPACE)
            # Erase last character
            if [[ -n "$MENU_EDITING_ITEM" ]] && [[ -n "$MENU_EDIT_BUFFER" ]]; then
                MENU_EDIT_BUFFER="${MENU_EDIT_BUFFER%?}"
            elif [[ -z "$MENU_EDITING_ITEM" ]]; then
                # Start editing and clear the value
                menu_flag_start_edit
                MENU_EDIT_BUFFER=""
            fi
            return 0
            ;;
        SELECT)
            # Enter commits the edit
            if [[ -n "$MENU_EDITING_ITEM" ]]; then
                menu_flag_commit_edit
                return 0
            fi
            # If not editing, select could start editing
            menu_flag_start_edit
            return 0
            ;;
    esac

    # Navigation keys should commit any pending edit
    case "$key" in
        UP|DOWN|TOP|BOTTOM|LEFT|RIGHT|TAB)
            menu_flag_commit_edit
            return 1  # Pass through to normal handling
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
    MENU_RENDER_GLOBAL_INDEX=0  # Track global item number for [1-9] jump

    # Header
    menu_render_header
    row=$MENU_RENDER_ROW

    # Sections
    for ((s = 0; s < ${#MENU_SECTIONS[@]}; s++)); do
        local section_id="${MENU_SECTIONS[$s]}"
        local is_current=$([[ $s -eq $MENU_CURRENT_SECTION ]] && echo 1 || echo 0)
        menu_render_section "$section_id" "$row" "$is_current"
        row=$MENU_RENDER_ROW
        ((++row))  # Space between sections
    done

    # Store where items end (for description area positioning)
    MENU_ITEMS_END_ROW=$row

    # Description area (below items, above footer)
    menu_render_description_area

    # Footer
    menu_render_footer

    # DEBUG: Log full render state
    if [[ -d "$MENU_DEBUG_DIR" ]]; then
        local frame_file="${MENU_DEBUG_DIR}/frame_$(printf '%04d' $MENU_DEBUG_FRAME_COUNT).txt"
        {
            echo "=== FRAME $MENU_DEBUG_FRAME_COUNT (FULL RENDER) ==="
            echo "Timestamp: $(date +%H:%M:%S.%N)"
            echo ""
            echo "--- Full Render Complete ---"
            echo "MENU_HEADER_HEIGHT=$MENU_HEADER_HEIGHT"
            echo "MENU_ITEMS_END_ROW=$MENU_ITEMS_END_ROW"
            echo "MENU_CURRENT_SECTION=$MENU_CURRENT_SECTION"
            echo "MENU_CURRENT_ITEM=$MENU_CURRENT_ITEM"
            echo ""
            echo "--- Item Row Cache ---"
            for key in "${!MENU_ITEM_ROWS[@]}"; do
                echo "  $key → row ${MENU_ITEM_ROWS[$key]}"
            done
            echo ""
            echo "--- Expected Layout ---"
            echo "Row 0-3: Header"
            echo "Row 4: Section 0 title"
            echo "Row 5: Section 0 underline"
            echo "Row 6+: Section 0 items..."
        } > "$frame_file"
        ((MENU_DEBUG_FRAME_COUNT++))
        echo "Frame $((MENU_DEBUG_FRAME_COUNT - 1)): FULL RENDER" >> "${MENU_DEBUG_DIR}/summary.log"
    fi

    # Move cursor to bottom-right to avoid visual artifacts
    tui_goto "$((TUI_ROWS - 1))" "$((TUI_COLS - 1))"
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

    MENU_RENDER_ROW=4
}
# }}}

# {{{ menu_render_section
menu_render_section() {
    local section_id="$1"
    local start_row="$2"
    local is_current="$3"

    local title="${MENU_SECTION_TITLES[$section_id]}"
    local items="${MENU_SECTION_ITEMS[$section_id]:-}"
    local row=$start_row

    # Section title
    tui_goto "$row" 2
    tui_bold "$title"
    ((++row))

    tui_goto "$row" 2
    tui_hline "${#title}" "─"
    ((++row))

    # Items
    if [[ -n "$items" ]]; then
        IFS=',' read -ra arr <<< "$items"
        for ((i = 0; i < ${#arr[@]}; i++)); do
            local item_id="${arr[$i]}"
            local highlight=0

            if [[ "$is_current" == "1" ]] && [[ $i -eq $MENU_CURRENT_ITEM ]]; then
                highlight=1
            fi

            ((++MENU_RENDER_GLOBAL_INDEX))

            # Store item position in cache for incremental updates
            local cache_key="${section_id}:${i}"
            MENU_ITEM_ROWS[$cache_key]=$row
            MENU_ITEM_GLOBAL_IDX[$cache_key]=$MENU_RENDER_GLOBAL_INDEX
            MENU_ITEM_IDS[$cache_key]="$item_id"

            # DEBUG: Log to file what row we're about to render at
            echo "FULL_RENDER: section=$section_id item=$i row=$row (ANSI $((row+1))) label=${MENU_ITEM_LABELS[$item_id]}" >> "${MENU_DEBUG_DIR}/full_render.log"

            menu_render_item "$item_id" "$row" "$highlight" "$MENU_RENDER_GLOBAL_INDEX"
            ((++row))
        done
    fi

    # Set global return value
    MENU_RENDER_ROW=$row
}
# }}}

# {{{ menu_render_item
menu_render_item() {
    local item_id="$1"
    local row="$2"
    local highlight="$3"
    local item_num="${4:-}"

    local label="${MENU_ITEM_LABELS[$item_id]:-$item_id}"
    local type="${MENU_ITEM_TYPES[$item_id]:-checkbox}"
    local disabled="${MENU_ITEM_DISABLED[$item_id]:-}"
    local value="${MENU_VALUES[$item_id]:-}"

    # DEBUG: Log actual row used for tui_goto
    echo "  menu_render_item: tui_goto row=$row col=0 (ANSI $((row+1));1) item=$item_id" >> "${MENU_DEBUG_DIR}/full_render.log"

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
        flag)
            echo -n "  "  # No checkbox prefix for flag (value shown inline)
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
        flag)
            # Inline editable value with right-justified display
            local config="${MENU_ITEM_CONFIG[$item_id]:-}"
            local default="${config%%:*}"
            local width="${config#*:}"
            [[ "$width" == "$config" ]] && width="$MENU_FLAG_WIDTH"
            [[ -z "$width" ]] && width="$MENU_FLAG_WIDTH"

            # Check if we're editing this item
            local is_editing=0
            local display_value="$value"
            if [[ "$MENU_EDITING_ITEM" == "$item_id" ]]; then
                is_editing=1
                display_value="$MENU_EDIT_BUFFER"
            fi

            # Right-justify the value
            local padded
            printf -v padded "%${width}s" "$display_value"

            echo -n ": ["
            if [[ "$is_editing" == "1" ]]; then
                # Editing mode - show cursor
                echo -n "${TUI_INVERSE}${padded}${TUI_RESET}"
            elif [[ "$value" == "0" ]] || [[ -z "$value" ]]; then
                # Disabled (0 or empty) - dim
                echo -n "${TUI_DIM}${padded}${TUI_RESET}"
            else
                # Active value
                echo -n "${TUI_GREEN}${padded}${TUI_RESET}"
            fi
            echo -n "]"

            # Show hint when highlighted
            if [[ "$highlight" == "1" ]]; then
                if [[ -n "$default" ]] && [[ "$default" != "0" ]]; then
                    echo -n " ${TUI_DIM}(→=${default}, ←=off)${TUI_RESET}"
                else
                    echo -n " ${TUI_DIM}(←=off)${TUI_RESET}"
                fi
            fi
            ;;
        action)
            echo -n " ${TUI_CYAN}→${TUI_RESET}"
            ;;
    esac

    # Note: Descriptions are now shown in a dedicated area below items
    # See menu_render_description_area()
}
# }}}

# {{{ menu_redraw_single_item
# Redraw a single item at a specific row (for incremental updates)
# Args: row item_id global_idx highlight
menu_redraw_single_item() {
    local row="$1"
    local item_id="$2"
    local global_idx="$3"
    local highlight="$4"

    menu_render_item "$item_id" "$row" "$highlight" "$global_idx"
}
# }}}

# {{{ menu_compute_item_row
# Compute the screen row for an item by walking through the layout
# Args: section_idx item_idx
# Sets: MENU_COMPUTED_ROW (global, to avoid subshell)
menu_compute_item_row() {
    local target_section="$1"
    local target_item="$2"

    # Start after header
    local row=$MENU_HEADER_HEIGHT

    # Walk through sections
    for ((s = 0; s <= target_section; s++)); do
        local section_id="${MENU_SECTIONS[$s]}"

        # Section title + underline = 2 rows
        ((row += 2))

        if [[ $s -eq $target_section ]]; then
            # Target section - add rows for items before target
            ((row += target_item))
            break
        else
            # Earlier section - add all item rows + spacing
            local count
            count=$(menu_get_section_item_count "$section_id")
            ((row += count))
            ((++row))  # Space between sections
        fi
    done

    MENU_COMPUTED_ROW=$row
}
# }}}

# {{{ menu_compute_global_index
# Compute the 1-based global index for an item
# Args: section_idx item_idx
# Sets: MENU_COMPUTED_GLOBAL_IDX (global, to avoid subshell)
menu_compute_global_index() {
    local target_section="$1"
    local target_item="$2"

    local idx=0

    for ((s = 0; s <= target_section; s++)); do
        local section_id="${MENU_SECTIONS[$s]}"

        if [[ $s -eq $target_section ]]; then
            ((idx += target_item + 1))
            break
        else
            local count
            count=$(menu_get_section_item_count "$section_id")
            ((idx += count))
        fi
    done

    MENU_COMPUTED_GLOBAL_IDX=$idx
}
# }}}

# {{{ menu_get_item_id_at
# Get the item ID at a specific section and item index
# Args: section_idx item_idx
# Sets: MENU_COMPUTED_ITEM_ID (global, to avoid subshell)
menu_get_item_id_at() {
    local section_idx="$1"
    local item_idx="$2"

    local section_id="${MENU_SECTIONS[$section_idx]}"
    local items="${MENU_SECTION_ITEMS[$section_id]:-}"

    MENU_COMPUTED_ITEM_ID=""
    if [[ -n "$items" ]]; then
        IFS=',' read -ra arr <<< "$items"
        if [[ $item_idx -lt ${#arr[@]} ]]; then
            MENU_COMPUTED_ITEM_ID="${arr[$item_idx]}"
        fi
    fi
}
# }}}

# {{{ menu_incremental_update
# Update display incrementally (only changed items + description area)
# Returns: 0 if incremental update done, 1 if full redraw needed
#
# Performs incremental update for adjacent items in the same section.
# Cross-section moves and jumps trigger full redraw for simplicity.
menu_incremental_update() {
    # Can't do incremental if we need full redraw or no previous position
    if [[ "$MENU_NEEDS_FULL_REDRAW" == "1" ]]; then
        return 1
    fi

    if [[ "$MENU_PREV_SECTION" -lt 0 ]] || [[ "$MENU_PREV_ITEM" -lt 0 ]]; then
        return 1
    fi

    # If position didn't change, nothing to do
    if [[ "$MENU_PREV_SECTION" -eq "$MENU_CURRENT_SECTION" ]] && \
       [[ "$MENU_PREV_ITEM" -eq "$MENU_CURRENT_ITEM" ]]; then
        return 0
    fi

    # Only do incremental for same section, adjacent items (diff of 1)
    if [[ "$MENU_PREV_SECTION" -ne "$MENU_CURRENT_SECTION" ]]; then
        return 1  # Different sections - full redraw
    fi

    local item_diff=$((MENU_CURRENT_ITEM - MENU_PREV_ITEM))
    if [[ $item_diff -lt -1 ]] || [[ $item_diff -gt 1 ]]; then
        return 1  # Jumped more than 1 item - full redraw
    fi

    # Compute positions on-the-fly (avoids caching issues)
    # Get section IDs for cache lookup
    local old_section_id="${MENU_SECTIONS[$MENU_PREV_SECTION]}"
    local new_section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
    local old_cache_key="${old_section_id}:${MENU_PREV_ITEM}"
    local new_cache_key="${new_section_id}:${MENU_CURRENT_ITEM}"

    # Use CACHED row values from full render (not recomputed)
    local old_row="${MENU_ITEM_ROWS[$old_cache_key]}"
    local new_row="${MENU_ITEM_ROWS[$new_cache_key]}"
    local old_global_idx="${MENU_ITEM_GLOBAL_IDX[$old_cache_key]}"
    local new_global_idx="${MENU_ITEM_GLOBAL_IDX[$new_cache_key]}"
    local old_item_id="${MENU_ITEM_IDS[$old_cache_key]}"
    local new_item_id="${MENU_ITEM_IDS[$new_cache_key]}"

    # DEBUG: Write to file to see what's happening
    {
        echo "=== Incremental Update Debug ==="
        echo "PREV: section=$MENU_PREV_SECTION item=$MENU_PREV_ITEM"
        echo "CURR: section=$MENU_CURRENT_SECTION item=$MENU_CURRENT_ITEM"
        echo "old_row=$old_row old_global_idx=$old_global_idx old_item_id=$old_item_id"
        echo "new_row=$new_row new_global_idx=$new_global_idx new_item_id=$new_item_id"
        echo "MENU_HEADER_HEIGHT=$MENU_HEADER_HEIGHT"
        echo "==="
    } >> /tmp/menu_debug.log

    # If we couldn't get item IDs, need full redraw
    if [[ -z "$old_item_id" ]] || [[ -z "$new_item_id" ]]; then
        return 1
    fi

    # DEBUG: Frame-by-frame logging
    local frame_file="${MENU_DEBUG_DIR}/frame_$(printf '%04d' $MENU_DEBUG_FRAME_COUNT).txt"

    {
        echo "=== FRAME $MENU_DEBUG_FRAME_COUNT ==="
        echo "Timestamp: $(date +%H:%M:%S.%N)"
        echo ""
        echo "--- Navigation State ---"
        echo "PREV: section=$MENU_PREV_SECTION item=$MENU_PREV_ITEM"
        echo "CURR: section=$MENU_CURRENT_SECTION item=$MENU_CURRENT_ITEM"
        echo ""
        echo "--- Computed Values (from menu_compute_item_row) ---"
        echo "old_row=$old_row (ANSI: $((old_row + 1)))"
        echo "new_row=$new_row (ANSI: $((new_row + 1)))"
        echo "old_global_idx=$old_global_idx"
        echo "new_global_idx=$new_global_idx"
        echo "old_item_id=$old_item_id → '${MENU_ITEM_LABELS[$old_item_id]}'"
        echo "new_item_id=$new_item_id → '${MENU_ITEM_LABELS[$new_item_id]}'"
        echo ""
        echo "--- Cached Values (from full render) ---"
        local old_section_id="${MENU_SECTIONS[$MENU_PREV_SECTION]}"
        local new_section_id="${MENU_SECTIONS[$MENU_CURRENT_SECTION]}"
        local old_cache_key="${old_section_id}:${MENU_PREV_ITEM}"
        local new_cache_key="${new_section_id}:${MENU_CURRENT_ITEM}"
        echo "old_cache_key=$old_cache_key → cached_row=${MENU_ITEM_ROWS[$old_cache_key]}"
        echo "new_cache_key=$new_cache_key → cached_row=${MENU_ITEM_ROWS[$new_cache_key]}"
        if [[ "${MENU_ITEM_ROWS[$old_cache_key]}" != "$old_row" ]]; then
            echo "!!! MISMATCH: old computed=$old_row vs cached=${MENU_ITEM_ROWS[$old_cache_key]}"
        fi
        if [[ "${MENU_ITEM_ROWS[$new_cache_key]}" != "$new_row" ]]; then
            echo "!!! MISMATCH: new computed=$new_row vs cached=${MENU_ITEM_ROWS[$new_cache_key]}"
        fi
        echo ""
        echo "--- Constants ---"
        echo "MENU_HEADER_HEIGHT=$MENU_HEADER_HEIGHT"
        echo "MENU_ITEMS_END_ROW=$MENU_ITEMS_END_ROW"
        echo "TUI_ROWS=$TUI_ROWS TUI_COLS=$TUI_COLS"
        echo ""
        echo "--- Operations Sequence ---"
    } > "$frame_file"

    # Build content strings
    local old_content="$old_global_idx [ ] ${MENU_ITEM_LABELS[$old_item_id]}"
    local new_content="$new_global_idx▸[●] ${MENU_ITEM_LABELS[$new_item_id]}"

    # Log to debug file FIRST (all file I/O before screen output)
    {
        echo "STEP 1: position to ANSI row $((old_row + 1)), col 1"
        echo "STEP 2: clear line"
        echo "STEP 3: write '$old_content'"
        echo "STEP 4: position to ANSI row $((new_row + 1)), col 1"
        echo "STEP 5: clear line"
        echo "STEP 6: write '$new_content' (with reverse video)"
    } >> "$frame_file"

    # ALL screen output in ONE printf call to eliminate buffering issues
    # Format: \033[row;colH = position, \033[K = clear to end of line (matches tui_clear_line)
    printf '\033[%d;1H\033[K%s\033[%d;1H\033[K%d▸[●] \033[7m%s\033[0m' \
        "$((old_row + 1))" "$old_content" \
        "$((new_row + 1))" "$new_global_idx" "${MENU_ITEM_LABELS[$new_item_id]}"

    echo "" >> "$frame_file"
    echo "--- Expected Screen State (rows 4-12) ---" >> "$frame_file"
    # Draw expected state based on our data model
    for ((r = 4; r <= 12; r++)); do
        local expected_line="row $r: "
        if [[ $r -eq $old_row ]]; then
            expected_line+="[OLD→UNHIGHLIGHT] $old_content"
        elif [[ $r -eq $new_row ]]; then
            expected_line+="[NEW→HIGHLIGHT] $new_content"
        else
            expected_line+="(unchanged)"
        fi
        echo "$expected_line" >> "$frame_file"
    done

    ((MENU_DEBUG_FRAME_COUNT++))

    # Also append to summary log
    echo "Frame $((MENU_DEBUG_FRAME_COUNT - 1)): old_row=$old_row new_row=$new_row" >> "${MENU_DEBUG_DIR}/summary.log"

    menu_render_description_area

    # Move cursor to bottom-right to avoid visual artifacts
    tui_goto "$((TUI_ROWS - 1))" "$((TUI_COLS - 1))"

    return 0
}
# }}}

# {{{ menu_render_description_area
# Render the description area below items (separator + description text)
menu_render_description_area() {
    local row=$MENU_ITEMS_END_ROW

    # Draw separator line
    tui_goto "$row" 0
    tui_hline "$TUI_COLS" "─"
    ((++row))

    # Get current item's description
    local item_id
    item_id=$(menu_get_current_item_id)
    local desc="${MENU_ITEM_DESCRIPTIONS[$item_id]:-}"

    # Calculate available width for description (with padding)
    local desc_width=$((TUI_COLS - 4))

    # Clear and render description lines
    for ((i = 0; i < MENU_DESC_MAX_LINES; i++)); do
        tui_goto "$((row + i))" 0
        tui_clear_line
    done

    if [[ -n "$desc" ]]; then
        # Word-wrap description to fit width
        local line_num=0
        local remaining="$desc"

        while [[ -n "$remaining" ]] && [[ $line_num -lt $MENU_DESC_MAX_LINES ]]; do
            local line
            if [[ ${#remaining} -le $desc_width ]]; then
                line="$remaining"
                remaining=""
            else
                # Find last space before width limit for word wrap
                line="${remaining:0:$desc_width}"
                local last_space
                # Find last space in the substring
                if [[ "$line" == *" "* ]]; then
                    # Get everything up to and including the last space
                    local before_last_space="${line% *}"
                    last_space=${#before_last_space}
                    line="${remaining:0:$last_space}"
                    remaining="${remaining:$((last_space + 1))}"
                else
                    # No space found, hard break
                    remaining="${remaining:$desc_width}"
                fi
            fi

            tui_goto "$((row + line_num))" 2
            echo -n "${TUI_DIM}${line}${TUI_RESET}"
            ((++line_num))
        done

        # Show ellipsis if description was truncated
        if [[ -n "$remaining" ]]; then
            tui_goto "$((row + MENU_DESC_MAX_LINES - 1))" "$((TUI_COLS - 5))"
            echo -n "${TUI_DIM}...${TUI_RESET}"
        fi
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
    # Initial render (always full)
    MENU_NEEDS_FULL_REDRAW=1
    menu_render
    MENU_NEEDS_FULL_REDRAW=0
    MENU_PREV_SECTION=$MENU_CURRENT_SECTION
    MENU_PREV_ITEM=$MENU_CURRENT_ITEM

    while true; do
        local key
        key=$(tui_read_key)

        # Save current position before handling key
        MENU_PREV_SECTION=$MENU_CURRENT_SECTION
        MENU_PREV_ITEM=$MENU_CURRENT_ITEM

        # Track if this key only changes cursor position (can use incremental)
        local nav_only=0

        # First, try flag inline editing (handles digits, backspace, enter on flag items)
        if menu_flag_handle_key "$key"; then
            # Flag editing changes display, need full redraw of current item
            MENU_NEEDS_FULL_REDRAW=1
            menu_render
            MENU_NEEDS_FULL_REDRAW=0
            continue
        fi

        case "$key" in
            UP)
                menu_nav_up
                nav_only=1
                ;;
            DOWN)
                menu_nav_down
                nav_only=1
                ;;
            TOP)
                menu_nav_top
                nav_only=1
                ;;
            BOTTOM)
                menu_nav_bottom
                nav_only=1
                ;;
            INDEX:*)
                # Number key pressed - jump to that index (1-based)
                # (only reached if not on a flag item)
                local index="${key#INDEX:}"
                menu_nav_to_global_index "$index"
                nav_only=1
                ;;
            LEFT)
                menu_handle_left_right "left"
                MENU_NEEDS_FULL_REDRAW=1
                ;;
            RIGHT)
                menu_handle_left_right "right"
                MENU_NEEDS_FULL_REDRAW=1
                ;;
            TOGGLE)
                menu_toggle
                MENU_NEEDS_FULL_REDRAW=1
                ;;
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
                MENU_NEEDS_FULL_REDRAW=1
                ;;
            ALL)
                menu_select_all
                MENU_NEEDS_FULL_REDRAW=1
                ;;
            NONE)
                menu_select_none
                MENU_NEEDS_FULL_REDRAW=1
                ;;
            RUN)
                menu_flag_commit_edit  # Commit any pending flag edit
                return 0
                ;;
            QUIT|ESCAPE)
                menu_flag_commit_edit  # Commit any pending flag edit
                return 1
                ;;
        esac

        # Update display
        if [[ "$nav_only" == "1" ]] && [[ "$MENU_NEEDS_FULL_REDRAW" != "1" ]]; then
            # Try incremental update (only redraw old and new cursor positions)
            if ! menu_incremental_update; then
                # Incremental failed, do full redraw
                menu_render
                MENU_NEEDS_FULL_REDRAW=0
            fi
        else
            # Need full redraw
            menu_render
            MENU_NEEDS_FULL_REDRAW=0
        fi
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
