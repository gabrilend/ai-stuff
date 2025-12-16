#!/usr/bin/env bash
# Test script for tui.sh library
# Run this to verify all TUI functions work correctly

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/tui.sh"

echo "TUI Library Test"
echo "================"
echo

# Test 1: Color support detection
echo "1. Color Support"
echo "   Colors supported: $TUI_COLORS_SUPPORTED"
if [[ $TUI_COLORS_SUPPORTED -eq 1 ]]; then
    echo -n "   Sample: "
    tui_color red "red "
    tui_color green "green "
    tui_color yellow "yellow "
    tui_color cyan "cyan "
    tui_bold "bold "
    tui_dim "dim "
    tui_highlight "inverse"
    echo
fi
echo

# Test 2: Dimension detection
echo "2. Terminal Dimensions"
echo "   Columns: $TUI_COLS"
echo "   Rows: $TUI_ROWS"
echo

# Test 3: Box drawing
echo "3. Box Drawing (single style)"
tui_box_top 40 single
tui_box_line 40 "Hello, TUI!" center single
tui_box_separator 40 single
tui_box_line 40 "Left aligned" left single
tui_box_line 40 "Right aligned" right single
tui_box_bottom 40 single
echo

# Test 4: Box drawing (double style)
echo "4. Box Drawing (double style)"
tui_box_top 40 double
tui_box_line 40 "Double borders" center double
tui_box_bottom 40 double
echo

# Test 5: Progress bar
echo "5. Progress Bar"
for i in 0 25 50 75 100; do
    echo -n "   $i%: "
    tui_progress_bar "$i" 100 20
    echo
done
echo

# Test 6: Spinner
echo "6. Spinner Frames"
echo -n "   "
for i in {0..9}; do
    tui_spinner "$i"
    echo -n " "
done
echo
echo

# Test 7: Interactive key test (requires TUI mode)
echo "7. Key Input Test"
echo "   Do you want to test interactive key input? (y/n)"
read -rsn1 answer

if [[ "$answer" == "y" ]]; then
    if ! tui_init; then
        echo "   ERROR: Could not initialize TUI mode"
        exit 1
    fi

    tui_clear
    tui_goto 0 0
    tui_bold "TUI Key Input Test"
    echo
    echo "Terminal: ${TUI_COLS}x${TUI_ROWS}"
    echo "Press keys to test (q to quit)"
    echo
    tui_hline 40
    echo
    echo

    row=6
    while true; do
        tui_goto "$row" 0
        tui_clear_line
        echo -n "Waiting for key... "

        key=$(tui_read_key)

        tui_goto "$row" 0
        tui_clear_line
        echo "Key pressed: ${TUI_CYAN}${key}${TUI_RESET}"

        ((row++))
        if [[ $row -gt $((TUI_ROWS - 3)) ]]; then
            row=6
            tui_goto 6 0
            for ((i=6; i < TUI_ROWS - 2; i++)); do
                tui_clear_line
                echo
            done
            tui_goto 6 0
        fi

        [[ "$key" == "QUIT" ]] && break
    done

    tui_cleanup
    echo
    echo "TUI mode cleaned up successfully"
fi

echo
echo "All tests completed!"
