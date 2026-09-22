#!/usr/bin/env bash
# Test script for debugging menu item incremental rendering
# Isolates the cursor positioning and item rendering logic

# set -e  # Disabled - causes issues with bash arithmetic

# ============================================================================
# Terminal Setup
# ============================================================================

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
# Cursor Positioning (0-indexed input, converts to 1-indexed ANSI)
# ============================================================================

goto() {
    local row="$1"
    local col="${2:-0}"
    printf '\033[%d;%dH' "$((row + 1))" "$((col + 1))"
}

clear_line() {
    printf '\033[K'
}

# ============================================================================
# Test Data
# ============================================================================

ITEMS=("Analyze" "Review" "Execute" "Implement" "Stream")
CURRENT=0
PREVIOUS=-1

# Layout constants
HEADER_ROWS=2      # Title + separator
FIRST_ITEM_ROW=2   # Items start at row 2 (0-indexed)

# ============================================================================
# Rendering
# ============================================================================

render_header() {
    goto 0 0
    printf '\033[1mTest Menu - Incremental Render Debug\033[0m'
    goto 1 0
    printf '%.s─' {1..40}
}

# Render a single item
# Args: index row highlight
render_item() {
    local idx="$1"
    local row="$2"
    local highlight="$3"

    goto "$row" 0
    clear_line

    # Item number
    printf '\033[2m%d\033[0m' "$((idx + 1))"

    # Highlight indicator
    if [[ "$highlight" == "1" ]]; then
        printf '\033[1m>\033[0m'
    else
        printf ' '
    fi

    # Checkbox
    printf '[ ] '

    # Label
    if [[ "$highlight" == "1" ]]; then
        printf '\033[7m%s\033[0m' "${ITEMS[$idx]}"
    else
        printf '%s' "${ITEMS[$idx]}"
    fi
}

# Full render of all items
render_all() {
    render_header
    for ((i = 0; i < ${#ITEMS[@]}; i++)); do
        local row=$((FIRST_ITEM_ROW + i))
        local highlight=0
        [[ $i -eq $CURRENT ]] && highlight=1
        render_item "$i" "$row" "$highlight"
    done
    render_status "Full render complete"
}

# Incremental update - only redraw changed items
incremental_update() {
    if [[ $PREVIOUS -lt 0 ]]; then
        return 1
    fi

    if [[ $PREVIOUS -eq $CURRENT ]]; then
        return 0
    fi

    local old_row=$((FIRST_ITEM_ROW + PREVIOUS))
    local new_row=$((FIRST_ITEM_ROW + CURRENT))

    # Debug info
    render_debug "PREV=$PREVIOUS CURR=$CURRENT old_row=$old_row new_row=$new_row"

    # Unhighlight old item
    render_item "$PREVIOUS" "$old_row" 0

    # Highlight new item
    render_item "$CURRENT" "$new_row" 1

    render_status "Incremental: row $old_row -> $new_row"
    return 0
}

render_status() {
    local msg="$1"
    goto 10 0
    clear_line
    printf '\033[2mStatus: %s\033[0m' "$msg"
}

render_debug() {
    local msg="$1"
    goto 11 0
    clear_line
    printf '\033[33mDebug: %s\033[0m' "$msg"
}

render_help() {
    goto 13 0
    printf '\033[2mControls: j/DOWN=down, k/UP=up, r=full redraw, q=quit\033[0m'
}

# ============================================================================
# Input Handling
# ============================================================================

read_key() {
    local key
    IFS= read -rsn1 key

    # Check for escape sequence (arrow keys)
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 rest || true
        key="${key}${rest}"
    fi

    echo "$key"
}

move_down() {
    PREVIOUS=$CURRENT
    if [[ $CURRENT -lt $((${#ITEMS[@]} - 1)) ]]; then
        CURRENT=$((CURRENT + 1))
    fi
}

move_up() {
    PREVIOUS=$CURRENT
    if [[ $CURRENT -gt 0 ]]; then
        CURRENT=$((CURRENT - 1))
    fi
}

# ============================================================================
# Main Loop
# ============================================================================

main() {
    init_terminal
    render_all
    render_help

    while true; do
        # Position cursor at bottom right to avoid artifacts
        goto 20 0

        local key
        key=$(read_key)

        case "$key" in
            j|$'\x1b[B')  # Down
                move_down
                if ! incremental_update; then
                    render_all
                fi
                ;;
            k|$'\x1b[A')  # Up
                move_up
                if ! incremental_update; then
                    render_all
                fi
                ;;
            r)  # Force full redraw
                PREVIOUS=-1
                render_all
                ;;
            q)  # Quit
                break
                ;;
        esac
    done
}

main "$@"
