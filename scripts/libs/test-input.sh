#!/usr/bin/env bash
# Test script for input.sh component
# Run this to test input components interactively

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/tui.sh"
source "${DIR}/input.sh"

echo "Input Component Test"
echo "===================="
echo
echo "This test requires an interactive terminal."
echo "Press any key to start, or 'q' to quit."

read -rsn1 key
[[ "$key" == "q" ]] && exit 0

# Initialize TUI
if ! tui_init; then
    echo "ERROR: Could not initialize TUI mode"
    exit 1
fi

# Test 1: Number input
tui_clear
tui_goto 0 0
tui_bold "Test 1: Number Input"
tui_goto 2 0
echo "Enter a number between 1 and 10:"

result=$(input_number "Count" 1 10 5 4)
exit_code=$?

tui_goto 8 0
if [[ $exit_code -eq 0 ]]; then
    echo "Result: $result"
else
    echo "Cancelled"
fi

tui_goto 10 0
echo "Press any key to continue to Test 2..."
tui_read_key > /dev/null

# Test 2: Text input
tui_clear
tui_goto 0 0
tui_bold "Test 2: Text Input"
tui_goto 2 0
echo "Enter a project name:"

result=$(input_text "Project Name" "my-project" 50 4)
exit_code=$?

tui_goto 10 0
if [[ $exit_code -eq 0 ]]; then
    echo "Result: '$result'"
else
    echo "Cancelled"
fi

tui_goto 12 0
echo "Press any key to continue to Test 3..."
tui_read_key > /dev/null

# Test 3: Path input
tui_clear
tui_goto 0 0
tui_bold "Test 3: Path Input (directory validation)"
tui_goto 2 0
echo "Enter a directory path:"

result=$(input_path "Directory" "$(pwd)" 1 4)
exit_code=$?

tui_goto 12 0
if [[ $exit_code -eq 0 ]]; then
    echo "Result: '$result'"
else
    echo "Cancelled"
fi

tui_goto 14 0
echo "Press any key to continue to Test 4..."
tui_read_key > /dev/null

# Test 4: Confirmation
tui_clear
tui_goto 0 0
tui_bold "Test 4: Confirmation"
tui_goto 2 0

if input_confirm "Would you like to proceed?" "y"; then
    tui_goto 4 0
    echo "You confirmed!"
else
    tui_goto 4 0
    echo "You declined."
fi

tui_goto 6 0
echo "Press any key to continue to Test 5..."
tui_read_key > /dev/null

# Test 5: Choice selection
tui_clear
tui_goto 0 0
tui_bold "Test 5: Choice Selection"
tui_goto 2 0

result=$(input_choice "Select a color:" "Red" "Green" "Blue" "Yellow")
exit_code=$?

tui_goto 10 0
if [[ $exit_code -eq 0 ]] && [[ "$result" != "0" ]]; then
    colors=("Red" "Green" "Blue" "Yellow")
    echo "You selected: ${colors[$((result-1))]}"
else
    echo "Cancelled"
fi

tui_goto 12 0
echo "Press any key to continue to Test 6..."
tui_read_key > /dev/null

# Test 6: Password input
tui_clear
tui_goto 0 0
tui_bold "Test 6: Password Input"
tui_goto 2 0
echo "Enter a password (masked):"

result=$(input_password "Password" 4)
exit_code=$?

tui_goto 8 0
if [[ $exit_code -eq 0 ]]; then
    echo "Password length: ${#result} characters"
else
    echo "Cancelled"
fi

tui_goto 10 0
echo "Press any key to finish..."
tui_read_key > /dev/null

tui_cleanup
echo
echo "All tests completed!"
