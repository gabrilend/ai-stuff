#!/usr/bin/env bash
# Test script for checkbox.sh component
# Run this interactively to test checkbox functionality

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/tui.sh"
source "${DIR}/checkbox.sh"

echo "Checkbox Component Test"
echo "======================="
echo
echo "This test requires an interactive terminal."
echo "Press any key to start the interactive test, or 'q' to quit."

read -rsn1 key
[[ "$key" == "q" ]] && exit 0

# Initialize TUI
if ! tui_init; then
    echo "ERROR: Could not initialize TUI mode"
    echo "Make sure you're running in an interactive terminal."
    exit 1
fi

# Test 1: Basic checkbox list
tui_clear
checkbox_init

# Add test items
checkbox_add_item "item1" "First item" 1            # Pre-checked
checkbox_add_item "item2" "Second item" 0
checkbox_add_item "item3" "Third item (disabled)" 0 1 "This item is disabled"
checkbox_add_item "item4" "Fourth item" 0 0 "With a description"
checkbox_add_item "item5" "Fifth item" 1
checkbox_add_item "item6" "Sixth item" 0
checkbox_add_item "item7" "Seventh item" 0
checkbox_add_item "item8" "Eighth item" 0
checkbox_add_item "item9" "Ninth item" 0 0 "Another description"
checkbox_add_item "item10" "Tenth item" 0
checkbox_add_item "item11" "Eleventh item" 0
checkbox_add_item "item12" "Twelfth item (disabled)" 0 1

checkbox_set_visible_count 8

if checkbox_run "Select Items (Test 1)"; then
    tui_cleanup
    echo
    echo "Test 1: Selection confirmed"
    echo "Selected items:"
    while IFS= read -r item; do
        echo "  - $item"
    done < <(checkbox_get_selected)
    echo "Total selected: $(checkbox_get_selected_count)"
else
    tui_cleanup
    echo
    echo "Test 1: Selection cancelled"
fi

echo
echo "Press any key to run Test 2 (file list), or 'q' to quit."
read -rsn1 key
[[ "$key" == "q" ]] && exit 0

# Test 2: File list simulation
tui_init
tui_clear
checkbox_init

# Simulate a file list
checkbox_add_item "001-fix-output.md" "001-fix-output.md" 1
checkbox_add_item "002-streaming.md" "002-streaming.md [In Progress]" 0 1 "Already has sub-issues"
checkbox_add_item "003-execute.md" "003-execute.md" 1
checkbox_add_item "004-tui.md" "004-tui.md [In Progress]" 1
checkbox_add_item "005-migrate.md" "005-migrate.md" 0
checkbox_add_item "006-rename.md" "006-rename.md" 1

checkbox_set_visible_count 10

if checkbox_run "Select Issues to Process" "Process" "Skip"; then
    tui_cleanup
    echo
    echo "Test 2: Issues to process:"
    while IFS= read -r item; do
        echo "  - $item"
    done < <(checkbox_get_selected)
else
    tui_cleanup
    echo
    echo "Test 2: Skipped"
fi

echo
echo "All tests completed!"
