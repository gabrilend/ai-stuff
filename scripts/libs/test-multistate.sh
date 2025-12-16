#!/usr/bin/env bash
# Test script for multistate.sh component
# Run this to test multi-state toggle functionality

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/tui.sh"
source "${DIR}/multistate.sh"

echo "Multistate Component Test"
echo "========================="
echo

# Test 1: Basic configuration
echo "1. Basic Configuration Tests"
multistate_init

multistate_add "format" "text,json,yaml,csv" "json" "Output Format"
multistate_add "level" "quiet,normal,verbose,debug" "normal" "Log Level"
multistate_add_preset "compression"

echo "   - Added format option: $(multistate_get format)"
echo "   - Added level option: $(multistate_get level)"
echo "   - Added compression preset: $(multistate_get compression)"
echo

# Test 2: Cycling
echo "2. Cycling Tests"
echo "   Format before: $(multistate_get format)"
multistate_cycle_right "format"
echo "   After cycle_right: $(multistate_get format)"
multistate_cycle_right "format"
echo "   After cycle_right: $(multistate_get format)"
multistate_cycle_left "format"
echo "   After cycle_left: $(multistate_get format)"
multistate_set_first "format"
echo "   After set_first: $(multistate_get format)"
multistate_set_last "format"
echo "   After set_last: $(multistate_get format)"
echo

# Test 3: Validation
echo "3. Validation Tests"
if multistate_set "format" "xml"; then
    echo "   ERROR: Invalid value 'xml' was accepted"
else
    echo "   OK: Invalid value 'xml' rejected"
fi
if multistate_set "format" "json"; then
    echo "   OK: Valid value 'json' accepted"
else
    echo "   ERROR: Valid value 'json' rejected"
fi
echo

# Test 4: Type checking
echo "4. Type Checking Tests"
if multistate_exists "format"; then
    echo "   OK: 'format' exists"
else
    echo "   ERROR: 'format' should exist"
fi
if multistate_exists "nonexistent"; then
    echo "   ERROR: 'nonexistent' should not exist"
else
    echo "   OK: 'nonexistent' doesn't exist"
fi
echo

# Test 5: Rendering (non-interactive)
echo "5. Rendering Tests (colors may not show in non-TTY)"
echo -n "   Inline: "
multistate_render_inline "format"
echo
echo -n "   Value only: "
multistate_render_value "format"
echo
echo -n "   All states: "
multistate_render_all_states "format"
echo
echo

# Test 6: Interactive test
echo "6. Interactive Test"
echo "   Press any key to start interactive test, or 'q' to skip."

read -rsn1 key
[[ "$key" == "q" ]] && { echo "   Skipped."; exit 0; }

# Initialize TUI
if ! tui_init; then
    echo "ERROR: Could not initialize TUI mode"
    exit 1
fi

# Interactive demo
tui_clear
multistate_init
multistate_add_preset "output_format" "format"
multistate_add_preset "verbosity" "verbosity"
multistate_add_preset "compression" "compress"
multistate_add "theme" "light,dark,auto" "auto" "Color Theme"

items=("format" "verbosity" "compress" "theme")
current=0

while true; do
    tui_goto 0 0
    tui_bold "Multistate Toggle Test"
    tui_goto 1 0
    echo "${TUI_DIM}Use h/l or ←/→ to cycle values, j/k or ↑/↓ to move, q to quit${TUI_RESET}"
    tui_goto 2 0
    tui_hline 50

    for ((i = 0; i < ${#items[@]}; i++)); do
        tui_goto $((4 + i)) 0
        tui_clear_line

        local hl=0
        [[ $i -eq $current ]] && hl=1
        multistate_render_with_description "${items[$i]}" 20 "$hl"
    done

    tui_goto $((4 + ${#items[@]} + 1)) 0
    tui_hline 50
    tui_goto $((4 + ${#items[@]} + 2)) 0
    echo "Press 'q' to quit and show final values"

    key=$(tui_read_key)

    case "$key" in
        UP)    ((current > 0)) && ((current--)) ;;
        DOWN)  ((current < ${#items[@]} - 1)) && ((current++)) ;;
        LEFT)  multistate_cycle_left "${items[$current]}" ;;
        RIGHT) multistate_cycle_right "${items[$current]}" ;;
        QUIT)  break ;;
    esac
done

tui_cleanup

echo
echo "Final values:"
for item in "${items[@]}"; do
    printf "  %-15s: %s\n" "$item" "$(multistate_get "$item")"
done

echo
echo "All tests completed!"
