#!/usr/bin/env bash
# Test script for menu.sh - the menu navigation system
# Run this interactively to test the full menu experience

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/tui.sh"
source "${DIR}/checkbox.sh"
source "${DIR}/multistate.sh"
source "${DIR}/input.sh"
source "${DIR}/menu.sh"

echo "Menu Navigation System Test"
echo "==========================="
echo
echo "This test demonstrates the full menu system with:"
echo "  - Radio buttons (single selection)"
echo "  - Checkboxes (multiple selection)"
echo "  - Multi-state toggles"
echo "  - Number inputs"
echo
echo "Press any key to start, or 'q' to quit."

read -rsn1 key
[[ "$key" == "q" ]] && exit 0

# Initialize TUI
if ! tui_init; then
    echo "ERROR: Could not initialize TUI mode"
    exit 1
fi

# Build the menu
menu_init
menu_set_title "Issue Splitter" "Interactive Mode"

# Section 1: Mode (radio buttons)
menu_add_section "mode" "single" "Mode"
menu_add_item "mode" "analyze" "Analyze" "checkbox" "1" "Analyze issues for sub-issue splitting"
menu_add_item "mode" "review" "Review" "checkbox" "0" "Review existing sub-issue structures"
menu_add_item "mode" "execute" "Execute" "checkbox" "0" "Execute recommendations from analyses"

# Section 2: Options (checkboxes and multi-state)
menu_add_section "options" "multi" "Options"
menu_add_item "options" "skip_existing" "Skip existing" "checkbox" "1" "Don't re-analyze issues with analysis"
menu_add_item "options" "dry_run" "Dry run" "checkbox" "0" "Show what would happen without doing it"
menu_add_item "options" "parallel" "Parallel count" "number" "1:10:3" "Number of parallel processes"
menu_add_item "options" "output_format" "Output format" "multistate" "text,json,yaml:text" "Format for output"

# Section 3: Files (list)
menu_add_section "files" "list" "Issues to Process"
menu_add_item "files" "file1" "001-fix-output.md" "checkbox" "1"
menu_add_item "files" "file2" "002-streaming.md" "checkbox" "1"
menu_add_item "files" "file3" "003-execute.md" "checkbox" "1"
menu_add_item "files" "file4" "004-tui.md" "checkbox" "0"
menu_set_disabled "file4" 1  # Disable this one

# Run the menu
if menu_run; then
    tui_cleanup
    echo
    echo "Configuration confirmed!"
    echo
    echo "Selected mode:"
    for mode in analyze review execute; do
        if [[ "$(menu_get_value "$mode")" == "1" ]]; then
            echo "  - $mode"
        fi
    done
    echo
    echo "Options:"
    echo "  - Skip existing: $(menu_get_value skip_existing)"
    echo "  - Dry run: $(menu_get_value dry_run)"
    echo "  - Parallel: $(menu_get_value parallel)"
    echo "  - Output format: $(menu_get_value output_format)"
    echo
    echo "Selected files:"
    for f in file1 file2 file3 file4; do
        if [[ "$(menu_get_value "$f")" == "1" ]]; then
            echo "  - ${MENU_ITEM_LABELS[$f]}"
        fi
    done
else
    tui_cleanup
    echo
    echo "Cancelled by user."
fi

echo
echo "Test completed!"
