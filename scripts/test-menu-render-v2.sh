#!/usr/bin/env bash
# Test script v2 - mimics menu.sh structure more closely
# Adds: header box, sections, description area

# set -e  # Disabled - causes issues with bash arithmetic and conditionals

# ============================================================================
# Terminal Setup
# ============================================================================

COLS=$(tput cols)
ROWS=$(tput lines)

cleanup() {
    printf '\033[?25h'  # Show cursor
    printf '\033[?1049l'  # Exit alternate screen
    stty echo icanon 2>/dev/null || true
}
trap cleanup EXIT

init_terminal() {
    printf '\033[?1049h'  # Enter alternate screen
    printf '\033[?25l'    # Hide cursor
    printf '\033[2J'      # Clear screen
    stty -echo -icanon min 1 time 0
}

# ============================================================================
# Cursor Positioning
# ============================================================================

goto() {
    local row="$1"
    local col="${2:-0}"
    printf '\033[%d;%dH' "$((row + 1))" "$((col + 1))"
}

clear_line() {
    printf '\033[K'
}

hline() {
    local len="$1"
    local char="${2:-─}"
    for ((i = 0; i < len; i++)); do
        printf '%s' "$char"
    done
}

# ============================================================================
# Test Data - Mimics menu.sh structure
# ============================================================================

# Two sections like menu.sh
declare -a SECTION_NAMES=("Mode" "Options")
declare -a SECTION1_ITEMS=("Analyze" "Review" "Execute" "Implement")
declare -a SECTION2_ITEMS=("Streaming" "Skip Existing" "Archive" "Dry Run")
declare -a ITEM_DESCS=(
    "Run analysis on issues"
    "Review existing sub-issues"
    "Execute recommendations"
    "Auto-implement via Claude"
    "Enable parallel streaming"
    "Skip already-analyzed"
    "Save copies to archive"
    "Show what would happen"
)

CURRENT_SECTION=0
CURRENT_ITEM=0
PREV_SECTION=-1
PREV_ITEM=-1

# Layout constants (matching menu.sh)
HEADER_HEIGHT=4        # Title box: top + title + subtitle + separator
ITEMS_END_ROW=0        # Set during full render
RENDER_ROW=0           # Used to return row from render functions

# ============================================================================
# Layout Calculation
# ============================================================================

# Compute row for an item (same logic as menu_compute_item_row)
compute_item_row() {
    local target_section="$1"
    local target_item="$2"

    local row=$HEADER_HEIGHT  # Start after header

    for ((s = 0; s <= target_section; s++)); do
        # Section title + underline = 2 rows
        row=$((row + 2))

        if [[ $s -eq $target_section ]]; then
            # Add rows for items before target
            row=$((row + target_item))
            break
        else
            # Earlier section - add all items + spacing
            if [[ $s -eq 0 ]]; then
                row=$((row + ${#SECTION1_ITEMS[@]}))
            else
                row=$((row + ${#SECTION2_ITEMS[@]}))
            fi
            row=$((row + 1))  # Space between sections
        fi
    done

    echo "$row"
}

# Get item count for a section
get_section_count() {
    if [[ "$1" -eq 0 ]]; then
        echo "${#SECTION1_ITEMS[@]}"
    else
        echo "${#SECTION2_ITEMS[@]}"
    fi
}

# Get item label
get_item_label() {
    local section="$1"
    local item="$2"
    if [[ $section -eq 0 ]]; then
        echo "${SECTION1_ITEMS[$item]}"
    else
        echo "${SECTION2_ITEMS[$item]}"
    fi
}

# Get global index (1-based)
get_global_index() {
    local section="$1"
    local item="$2"
    if [[ $section -eq 0 ]]; then
        echo "$((item + 1))"
    else
        echo "$((${#SECTION1_ITEMS[@]} + item + 1))"
    fi
}

# ============================================================================
# Rendering
# ============================================================================

render_header() {
    # Row 0: Top border
    goto 0 0
    printf '╔'
    hline "$((COLS - 2))" '═'
    printf '╗'

    # Row 1: Title
    goto 1 0
    printf '║'
    printf '\033[1m%*s\033[0m' "$(( (COLS + 14) / 2 ))" "Test Menu v2"
    goto 1 "$((COLS - 1))"
    printf '║'

    # Row 2: Subtitle
    goto 2 0
    printf '║'
    printf '\033[2m%*s\033[0m' "$(( (COLS + 20) / 2 ))" "With Sections"
    goto 2 "$((COLS - 1))"
    printf '║'

    # Row 3: Separator
    goto 3 0
    printf '╠'
    hline "$((COLS - 2))" '═'
    printf '╣'
}

render_section() {
    local section_idx="$1"
    local start_row="$2"
    local is_current="$3"

    local title="${SECTION_NAMES[$section_idx]}"
    local row=$start_row

    # Section title
    goto "$row" 2
    printf '\033[1m%s\033[0m' "$title"
    row=$((row + 1))

    # Underline
    goto "$row" 2
    hline "${#title}" '─'
    row=$((row + 1))

    # Items
    local count
    count=$(get_section_count "$section_idx")

    for ((i = 0; i < count; i++)); do
        local highlight=0
        if [[ "$is_current" == "1" ]] && [[ $i -eq $CURRENT_ITEM ]]; then
            highlight=1
        fi

        local label
        label=$(get_item_label "$section_idx" "$i")
        local global_idx
        global_idx=$(get_global_index "$section_idx" "$i")

        render_item "$label" "$row" "$highlight" "$global_idx"
        row=$((row + 1))
    done

    RENDER_ROW=$row  # Return via global variable
}

render_item() {
    local label="$1"
    local row="$2"
    local highlight="$3"
    local item_num="${4:-}"

    goto "$row" 0
    clear_line

    # Item number
    if [[ -n "$item_num" ]]; then
        if [[ "$item_num" -le 9 ]]; then
            printf '\033[2m%d\033[0m' "$item_num"
        else
            printf '\033[2m*\033[0m'
        fi
    fi

    # Highlight indicator
    if [[ "$highlight" == "1" ]]; then
        printf '\033[1m▸\033[0m'
    else
        printf ' '
    fi

    # Checkbox
    printf '[ ] '

    # Label
    if [[ "$highlight" == "1" ]]; then
        printf '\033[7m%s\033[0m' "$label"
    else
        printf '%s' "$label"
    fi
}

render_description_area() {
    local row=$ITEMS_END_ROW

    # Separator line
    goto "$row" 0
    hline "$COLS" '─'
    row=$((row + 1))

    # Get description for current item
    local global_idx
    global_idx=$(get_global_index "$CURRENT_SECTION" "$CURRENT_ITEM")
    local desc="${ITEM_DESCS[$((global_idx - 1))]}"

    # Clear description lines (3 max)
    for ((i = 0; i < 3; i++)); do
        goto "$((row + i))" 0
        clear_line
    done

    # Render description
    if [[ -n "$desc" ]]; then
        goto "$row" 2
        printf '\033[2m%s\033[0m' "$desc"
    fi
}

render_all() {
    printf '\033[2J'  # Clear screen

    render_header
    local row=$HEADER_HEIGHT

    # Section 0
    local is_current=0
    [[ $CURRENT_SECTION -eq 0 ]] && is_current=1
    render_section 0 "$row" "$is_current"
    row=$((RENDER_ROW + 1))  # Space between sections

    # Section 1
    is_current=0
    [[ $CURRENT_SECTION -eq 1 ]] && is_current=1
    render_section 1 "$row" "$is_current"
    row=$RENDER_ROW

    ITEMS_END_ROW=$row

    render_description_area
    render_status "Full render"
    render_debug ""
}

# Incremental update - redraw only changed items
incremental_update() {
    if [[ $PREV_SECTION -lt 0 ]] || [[ $PREV_ITEM -lt 0 ]]; then
        return 1
    fi

    # Only handle same-section adjacent moves
    if [[ $PREV_SECTION -ne $CURRENT_SECTION ]]; then
        return 1  # Cross-section, need full redraw
    fi

    local item_diff=$((CURRENT_ITEM - PREV_ITEM))
    if [[ $item_diff -lt -1 ]] || [[ $item_diff -gt 1 ]]; then
        return 1  # Jumped more than 1
    fi

    if [[ $PREV_ITEM -eq $CURRENT_ITEM ]]; then
        return 0  # No change
    fi

    # Compute rows
    local old_row
    old_row=$(compute_item_row "$PREV_SECTION" "$PREV_ITEM")
    local new_row
    new_row=$(compute_item_row "$CURRENT_SECTION" "$CURRENT_ITEM")

    local old_label
    old_label=$(get_item_label "$PREV_SECTION" "$PREV_ITEM")
    local new_label
    new_label=$(get_item_label "$CURRENT_SECTION" "$CURRENT_ITEM")

    local old_idx
    old_idx=$(get_global_index "$PREV_SECTION" "$PREV_ITEM")
    local new_idx
    new_idx=$(get_global_index "$CURRENT_SECTION" "$CURRENT_ITEM")

    render_debug "old_row=$old_row new_row=$new_row"

    # Unhighlight old
    render_item "$old_label" "$old_row" 0 "$old_idx"

    # Highlight new
    render_item "$new_label" "$new_row" 1 "$new_idx"

    # Update description
    render_description_area

    render_status "Incremental: $old_row -> $new_row"
    return 0
}

render_status() {
    goto "$((ROWS - 3))" 0
    clear_line
    printf '\033[2mStatus: %s\033[0m' "$1"
}

render_debug() {
    goto "$((ROWS - 2))" 0
    clear_line
    printf '\033[33mDebug: %s\033[0m' "$1"
}

# ============================================================================
# Input & Navigation
# ============================================================================

read_key() {
    local key
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 rest || true
        key="${key}${rest}"
    fi
    echo "$key"
}

move_down() {
    PREV_SECTION=$CURRENT_SECTION
    PREV_ITEM=$CURRENT_ITEM

    local count
    count=$(get_section_count "$CURRENT_SECTION")

    if [[ $CURRENT_ITEM -lt $((count - 1)) ]]; then
        CURRENT_ITEM=$((CURRENT_ITEM + 1))
    elif [[ $CURRENT_SECTION -lt 1 ]]; then
        # Move to next section
        CURRENT_SECTION=$((CURRENT_SECTION + 1))
        CURRENT_ITEM=0
    fi
}

move_up() {
    PREV_SECTION=$CURRENT_SECTION
    PREV_ITEM=$CURRENT_ITEM

    if [[ $CURRENT_ITEM -gt 0 ]]; then
        CURRENT_ITEM=$((CURRENT_ITEM - 1))
    elif [[ $CURRENT_SECTION -gt 0 ]]; then
        # Move to previous section
        CURRENT_SECTION=$((CURRENT_SECTION - 1))
        local count
        count=$(get_section_count "$CURRENT_SECTION")
        CURRENT_ITEM=$((count - 1))
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    init_terminal
    render_all

    while true; do
        goto "$((ROWS - 1))" "$((COLS - 1))"

        local key
        key=$(read_key)

        case "$key" in
            j|$'\x1b[B')
                move_down
                if ! incremental_update; then
                    render_all
                fi
                ;;
            k|$'\x1b[A')
                move_up
                if ! incremental_update; then
                    render_all
                fi
                ;;
            r)
                PREV_SECTION=-1
                PREV_ITEM=-1
                render_all
                ;;
            q)
                break
                ;;
        esac
    done
}

main "$@"
