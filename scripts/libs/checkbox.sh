#!/usr/bin/env bash
# Checkbox Component - Interactive checkbox selection for TUI
# Provides checkbox lists with cursor navigation, toggle, and bulk selection.
#
# Usage: source this file after tui.sh, then use checkbox_* functions.
# See bottom of file for example usage.

# Prevent double-sourcing
[[ -n "${_CHECKBOX_LOADED:-}" ]] && return 0
_CHECKBOX_LOADED=1

# Library directory
CHECKBOX_LIB_DIR="${CHECKBOX_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Ensure TUI library is loaded
if [[ -z "${_TUI_LOADED:-}" ]]; then
    source "${CHECKBOX_LIB_DIR}/tui.sh"
fi

# ============================================================================
# Checkbox State
# ============================================================================

# State storage
declare -A CHECKBOX_STATE        # item_id -> 0/1 (checked state)
declare -A CHECKBOX_DISABLED     # item_id -> 1 (if disabled)
declare -a CHECKBOX_ITEMS        # ordered list of item IDs
declare -a CHECKBOX_LABELS       # display labels for items
declare -a CHECKBOX_DESCRIPTIONS # optional descriptions

# Cursor and scroll
CHECKBOX_CURSOR=0
CHECKBOX_SCROLL_OFFSET=0
CHECKBOX_VISIBLE_COUNT=10

# Visual symbols
CHECKBOX_CHECKED="●"
CHECKBOX_UNCHECKED=" "
CHECKBOX_DISABLED="○"
CHECKBOX_CURSOR_CHAR="▸"

# ============================================================================
# Initialization
# ============================================================================

# {{{ checkbox_init
# Initialize/reset checkbox state
checkbox_init() {
    CHECKBOX_STATE=()
    CHECKBOX_DISABLED=()
    CHECKBOX_ITEMS=()
    CHECKBOX_LABELS=()
    CHECKBOX_DESCRIPTIONS=()
    CHECKBOX_CURSOR=0
    CHECKBOX_SCROLL_OFFSET=0
}
# }}}

# {{{ checkbox_set_visible_count
# Set how many items are visible before scrolling
checkbox_set_visible_count() {
    CHECKBOX_VISIBLE_COUNT="${1:-10}"
}
# }}}

# ============================================================================
# Item Management
# ============================================================================

# {{{ checkbox_add_item
# Add an item to the checkbox list
# Args: id label [checked] [disabled] [description]
checkbox_add_item() {
    local id="$1"
    local label="${2:-$id}"
    local checked="${3:-0}"
    local disabled="${4:-0}"
    local description="${5:-}"

    CHECKBOX_ITEMS+=("$id")
    CHECKBOX_LABELS+=("$label")
    CHECKBOX_DESCRIPTIONS+=("$description")

    CHECKBOX_STATE[$id]="$checked"
    if [[ "$disabled" == "1" ]]; then
        CHECKBOX_DISABLED[$id]=1
    fi
}
# }}}

# {{{ checkbox_set_checked
# Set the checked state of an item
checkbox_set_checked() {
    local id="$1"
    local checked="${2:-1}"
    CHECKBOX_STATE[$id]="$checked"
}
# }}}

# {{{ checkbox_set_disabled
# Set the disabled state of an item
checkbox_set_disabled() {
    local id="$1"
    local disabled="${2:-1}"
    if [[ "$disabled" == "1" ]]; then
        CHECKBOX_DISABLED[$id]=1
    else
        unset 'CHECKBOX_DISABLED[$id]'
    fi
}
# }}}

# {{{ checkbox_is_checked
# Check if an item is checked
checkbox_is_checked() {
    local id="$1"
    [[ "${CHECKBOX_STATE[$id]:-0}" == "1" ]]
}
# }}}

# {{{ checkbox_is_disabled
# Check if an item is disabled
checkbox_is_disabled() {
    local id="$1"
    [[ -n "${CHECKBOX_DISABLED[$id]:-}" ]]
}
# }}}

# ============================================================================
# Navigation
# ============================================================================

# {{{ checkbox_cursor_up
# Move cursor up
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
# Move cursor down
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
# Move cursor to first item
checkbox_cursor_top() {
    CHECKBOX_CURSOR=0
    CHECKBOX_SCROLL_OFFSET=0
}
# }}}

# {{{ checkbox_cursor_bottom
# Move cursor to last item
checkbox_cursor_bottom() {
    local total=${#CHECKBOX_ITEMS[@]}
    CHECKBOX_CURSOR=$((total - 1))
    [[ $CHECKBOX_CURSOR -lt 0 ]] && CHECKBOX_CURSOR=0

    # Adjust scroll offset
    if [[ $total -gt $CHECKBOX_VISIBLE_COUNT ]]; then
        CHECKBOX_SCROLL_OFFSET=$((total - CHECKBOX_VISIBLE_COUNT))
        [[ $CHECKBOX_SCROLL_OFFSET -lt 0 ]] && CHECKBOX_SCROLL_OFFSET=0
    fi
}
# }}}

# {{{ checkbox_jump_to_index
# Jump to item by 1-based index
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

# {{{ checkbox_page_up
# Move up by one page
checkbox_page_up() {
    local page_size=$((CHECKBOX_VISIBLE_COUNT - 1))
    CHECKBOX_CURSOR=$((CHECKBOX_CURSOR - page_size))
    [[ $CHECKBOX_CURSOR -lt 0 ]] && CHECKBOX_CURSOR=0

    CHECKBOX_SCROLL_OFFSET=$((CHECKBOX_SCROLL_OFFSET - page_size))
    [[ $CHECKBOX_SCROLL_OFFSET -lt 0 ]] && CHECKBOX_SCROLL_OFFSET=0
}
# }}}

# {{{ checkbox_page_down
# Move down by one page
checkbox_page_down() {
    local total=${#CHECKBOX_ITEMS[@]}
    local page_size=$((CHECKBOX_VISIBLE_COUNT - 1))

    CHECKBOX_CURSOR=$((CHECKBOX_CURSOR + page_size))
    [[ $CHECKBOX_CURSOR -ge $total ]] && CHECKBOX_CURSOR=$((total - 1))
    [[ $CHECKBOX_CURSOR -lt 0 ]] && CHECKBOX_CURSOR=0

    CHECKBOX_SCROLL_OFFSET=$((CHECKBOX_SCROLL_OFFSET + page_size))
    local max_offset=$((total - CHECKBOX_VISIBLE_COUNT))
    [[ $max_offset -lt 0 ]] && max_offset=0
    [[ $CHECKBOX_SCROLL_OFFSET -gt $max_offset ]] && CHECKBOX_SCROLL_OFFSET=$max_offset
}
# }}}

# ============================================================================
# Toggle Functions
# ============================================================================

# {{{ checkbox_toggle
# Toggle the current item
checkbox_toggle() {
    local id="${CHECKBOX_ITEMS[$CHECKBOX_CURSOR]}"

    # Can't toggle disabled items
    if [[ -n "${CHECKBOX_DISABLED[$id]:-}" ]]; then
        return 1
    fi

    if [[ "${CHECKBOX_STATE[$id]:-0}" == "1" ]]; then
        CHECKBOX_STATE[$id]=0
    else
        CHECKBOX_STATE[$id]=1
    fi
}
# }}}

# {{{ checkbox_select_all
# Select all non-disabled items
checkbox_select_all() {
    local total=${#CHECKBOX_ITEMS[@]}
    for ((i = 0; i < total; i++)); do
        local id="${CHECKBOX_ITEMS[$i]}"
        if [[ -z "${CHECKBOX_DISABLED[$id]:-}" ]]; then
            CHECKBOX_STATE[$id]=1
        fi
    done
}
# }}}

# {{{ checkbox_select_none
# Deselect all items
checkbox_select_none() {
    local total=${#CHECKBOX_ITEMS[@]}
    for ((i = 0; i < total; i++)); do
        local id="${CHECKBOX_ITEMS[$i]}"
        CHECKBOX_STATE[$id]=0
    done
}
# }}}

# {{{ checkbox_invert_selection
# Invert selection of all non-disabled items
checkbox_invert_selection() {
    local total=${#CHECKBOX_ITEMS[@]}
    for ((i = 0; i < total; i++)); do
        local id="${CHECKBOX_ITEMS[$i]}"
        if [[ -z "${CHECKBOX_DISABLED[$id]:-}" ]]; then
            if [[ "${CHECKBOX_STATE[$id]:-0}" == "1" ]]; then
                CHECKBOX_STATE[$id]=0
            else
                CHECKBOX_STATE[$id]=1
            fi
        fi
    done
}
# }}}

# ============================================================================
# Result Retrieval
# ============================================================================

# {{{ checkbox_get_selected
# Get list of selected item IDs
checkbox_get_selected() {
    local total=${#CHECKBOX_ITEMS[@]}
    local first=1
    for ((i = 0; i < total; i++)); do
        local id="${CHECKBOX_ITEMS[$i]}"
        if [[ "${CHECKBOX_STATE[$id]:-0}" == "1" ]]; then
            if [[ $first -eq 1 ]]; then
                first=0
            fi
            echo "$id"
        fi
    done
}
# }}}

# {{{ checkbox_get_selected_count
# Get count of selected items
checkbox_get_selected_count() {
    local count=0
    local total=${#CHECKBOX_ITEMS[@]}
    for ((i = 0; i < total; i++)); do
        local id="${CHECKBOX_ITEMS[$i]}"
        if [[ "${CHECKBOX_STATE[$id]:-0}" == "1" ]]; then
            ((count++))
        fi
    done
    echo "$count"
}
# }}}

# {{{ checkbox_get_current_id
# Get ID of currently selected item
checkbox_get_current_id() {
    echo "${CHECKBOX_ITEMS[$CHECKBOX_CURSOR]:-}"
}
# }}}

# ============================================================================
# Rendering
# ============================================================================

# {{{ checkbox_render
# Render the checkbox list at specified position
# Args: [start_row] [visible_count] [width]
checkbox_render() {
    local start_row="${1:-0}"
    local visible="${2:-$CHECKBOX_VISIBLE_COUNT}"
    local width="${3:-$TUI_COLS}"

    local total=${#CHECKBOX_ITEMS[@]}

    # Calculate visible range
    local start=$CHECKBOX_SCROLL_OFFSET
    local end=$((start + visible))
    [[ $end -gt $total ]] && end=$total

    # Max width for label
    local label_width=$((width - 10))  # Account for prefix, checkbox, padding

    # Render each visible item
    local row=$start_row
    for ((i = start; i < end; i++)); do
        local id="${CHECKBOX_ITEMS[$i]}"
        local label="${CHECKBOX_LABELS[$i]:-$id}"
        local desc="${CHECKBOX_DESCRIPTIONS[$i]:-}"
        local checked="${CHECKBOX_STATE[$id]:-0}"
        local disabled="${CHECKBOX_DISABLED[$id]:-}"

        tui_goto "$row" 0
        tui_clear_line

        # Cursor indicator
        if [[ $i -eq $CHECKBOX_CURSOR ]]; then
            echo -n "${TUI_BOLD}${CHECKBOX_CURSOR_CHAR} ${TUI_RESET}"
        else
            echo -n "  "
        fi

        # Checkbox
        if [[ -n "$disabled" ]]; then
            echo -n "${TUI_DIM}[${CHECKBOX_DISABLED}]${TUI_RESET}"
        elif [[ "$checked" == "1" ]]; then
            echo -n "${TUI_GREEN}[${CHECKBOX_CHECKED}]${TUI_RESET}"
        else
            echo -n "[${CHECKBOX_UNCHECKED}]"
        fi

        echo -n " "

        # Truncate label if too long
        if [[ ${#label} -gt $label_width ]]; then
            label="${label:0:$((label_width - 3))}..."
        fi

        # Label with highlighting for current item
        if [[ $i -eq $CHECKBOX_CURSOR ]]; then
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

        # Description (if room and exists)
        if [[ -n "$desc" ]] && [[ $i -eq $CHECKBOX_CURSOR ]]; then
            local remaining=$((width - ${#label} - 8))
            if [[ $remaining -gt 5 ]]; then
                if [[ ${#desc} -gt $((remaining - 3)) ]]; then
                    desc="${desc:0:$((remaining - 6))}..."
                fi
                echo -n "  ${TUI_DIM}$desc${TUI_RESET}"
            fi
        fi

        ((row++))
    done

    # Clear remaining lines if list is shorter than visible area
    while [[ $row -lt $((start_row + visible)) ]]; do
        tui_goto "$row" 0
        tui_clear_line
        ((row++))
    done

    # Scroll indicators
    if [[ $start -gt 0 ]]; then
        tui_goto "$start_row" "$((width - 6))"
        echo -n "${TUI_DIM}↑more${TUI_RESET}"
    fi
    if [[ $end -lt $total ]]; then
        tui_goto "$((start_row + visible - 1))" "$((width - 6))"
        echo -n "${TUI_DIM}↓more${TUI_RESET}"
    fi
}
# }}}

# {{{ checkbox_render_status
# Render a status line showing selection count
# Args: [row] [format]
checkbox_render_status() {
    local row="${1:-$((CHECKBOX_VISIBLE_COUNT + 1))}"
    local format="${2:-Selected: %d/%d}"

    local selected
    selected=$(checkbox_get_selected_count)
    local total=${#CHECKBOX_ITEMS[@]}

    tui_goto "$row" 0
    tui_clear_line
    printf "${TUI_DIM}${format}${TUI_RESET}" "$selected" "$total"
}
# }}}

# ============================================================================
# Interactive Loop
# ============================================================================

# {{{ checkbox_run
# Run an interactive checkbox selection loop
# Args: title [confirm_label] [cancel_label]
# Returns: 0 if confirmed, 1 if cancelled
checkbox_run() {
    local title="${1:-Select items}"
    local confirm="${2:-Confirm}"
    local cancel="${3:-Cancel}"

    local header_height=4
    local footer_height=3
    local list_height=$((TUI_ROWS - header_height - footer_height))
    [[ $list_height -gt $CHECKBOX_VISIBLE_COUNT ]] && list_height=$CHECKBOX_VISIBLE_COUNT

    while true; do
        # Header
        tui_goto 0 0
        tui_clear_line
        tui_bold "$title"
        tui_goto 1 0
        tui_clear_line
        echo "${TUI_DIM}Space: toggle  a: all  n: none  Enter: ${confirm}  q: ${cancel}${TUI_RESET}"
        tui_goto 2 0
        tui_hline "$TUI_COLS" "─"

        # Checkbox list
        checkbox_render "$header_height" "$list_height" "$TUI_COLS"

        # Status
        checkbox_render_status "$((header_height + list_height + 1))"

        # Read key
        local key
        key=$(tui_read_key)

        case "$key" in
            UP)     checkbox_cursor_up ;;
            DOWN)   checkbox_cursor_down ;;
            TOP)    checkbox_cursor_top ;;
            BOTTOM) checkbox_cursor_bottom ;;
            PGUP)   checkbox_page_up ;;
            PGDN)   checkbox_page_down ;;
            TOGGLE) checkbox_toggle ;;
            ALL)    checkbox_select_all ;;
            NONE)   checkbox_select_none ;;
            SELECT) return 0 ;;   # Confirm selection
            QUIT|ESCAPE) return 1 ;;   # Cancel
            INDEX:*)
                local idx="${key#INDEX:}"
                checkbox_jump_to_index "$idx"
                ;;
        esac
    done
}
# }}}

# {{{ checkbox_handle_key
# Handle a single key event (for integration with other components)
# Returns: 0 if handled, 1 if not
checkbox_handle_key() {
    local key="$1"

    case "$key" in
        UP)     checkbox_cursor_up; return 0 ;;
        DOWN)   checkbox_cursor_down; return 0 ;;
        TOP)    checkbox_cursor_top; return 0 ;;
        BOTTOM) checkbox_cursor_bottom; return 0 ;;
        PGUP)   checkbox_page_up; return 0 ;;
        PGDN)   checkbox_page_down; return 0 ;;
        TOGGLE) checkbox_toggle; return 0 ;;
        ALL)    checkbox_select_all; return 0 ;;
        NONE)   checkbox_select_none; return 0 ;;
        INDEX:*)
            local idx="${key#INDEX:}"
            checkbox_jump_to_index "$idx"
            return 0
            ;;
    esac

    return 1  # Key not handled
}
# }}}
