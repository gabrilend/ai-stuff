#!/bin/bash

# {{{ Phase Demo Runner
# Runs demonstration scripts for completed phases

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Allow override of DIR variable
if [[ $# -gt 0 ]]; then
    DIR="$1"
fi

echo "AI Playground Phase Demo Runner"
echo "==============================="
echo

# Check for completed phases
phase_count=0
for phase_dir in "$DIR/issues/completed/phase-"*; do
    if [[ -d "$phase_dir" ]]; then
        phase_num=$(basename "$phase_dir" | grep -o '[0-9]*')
        if [[ -n "$phase_num" ]]; then
            ((phase_count++))
        fi
    fi
done

if [[ $phase_count -eq 0 ]]; then
    echo "No completed phases found."
    exit 1
fi

echo "Found $phase_count completed phase(s)."
echo

# Interactive mode flag
interactive_mode=false
if [[ "$1" == "-I" ]] || [[ "$2" == "-I" ]]; then
    interactive_mode=true
fi

if [[ "$interactive_mode" == true ]]; then
    echo "Interactive Mode: Select phase to run demo"
    echo "Available phases:"
    for i in $(seq 1 $phase_count); do
        echo "  $i. Phase $i"
    done
    echo
    read -p "Enter phase number (1-$phase_count): " selected_phase
else
    if [[ $# -eq 0 ]] || [[ "$1" == "-I" ]]; then
        read -p "Enter phase number to demo (1-$phase_count): " selected_phase
    else
        selected_phase="$1"
        if [[ "$2" == "-I" ]]; then
            selected_phase="$2"
        fi
    fi
fi

# Validate selection
if [[ ! "$selected_phase" =~ ^[0-9]+$ ]] || [[ $selected_phase -lt 1 ]] || [[ $selected_phase -gt $phase_count ]]; then
    echo "Invalid selection: $selected_phase"
    exit 1
fi

echo "Running Phase $selected_phase demo..."
echo "====================================="
echo

phase_dir="$DIR/issues/completed/phase-$selected_phase"

# Check for test_demo script
if [[ -f "$phase_dir/test_demo.lua" ]]; then
    echo "Running Lua test script..."
    cd "$DIR"
    lua "$phase_dir/test_demo.lua"
elif [[ -f "$phase_dir/test_demo.sh" ]]; then
    echo "Running Bash test script..."
    cd "$DIR"
    bash "$phase_dir/test_demo.sh"
else
    echo "No test demo found in $phase_dir"
    echo "Looking for other demo files..."
    
    demo_files=($(find "$phase_dir" -name "demo*" -o -name "test*" | head -5))
    if [[ ${#demo_files[@]} -gt 0 ]]; then
        echo "Found demo files:"
        for file in "${demo_files[@]}"; do
            echo "  $(basename "$file")"
        done
    else
        echo "No demo files found."
    fi
fi

echo
echo "Phase $selected_phase demo completed."

# Check if Love2d is available and offer to run visual demo
if command -v love >/dev/null 2>&1; then
    echo
    read -p "Would you like to run the Love2d visual demo? (y/n): " run_love
    if [[ "$run_love" =~ ^[Yy] ]]; then
        echo "Starting Love2d visual demo..."
        cd "$DIR"
        love .
    fi
fi
-- }}}