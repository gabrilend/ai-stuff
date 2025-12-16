#!/bin/bash
# Phase Demo Runner - Interactive selector for phase completion demos
# Run from project root: ./run_demo.sh

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
DEMOS_DIR="${DIR}/issues/completed/demos"

# {{{ print_header
print_header() {
    echo ""
    echo "========================================"
    echo "  World Edit to Execute - Phase Demos"
    echo "========================================"
    echo ""
}
# }}}

# {{{ print_menu
print_menu() {
    echo "Available demos:"
    echo ""
    echo "  [0] Phase 0 - Tooling Demo"
    echo "      Launch issue-splitter.sh in interactive TUI mode"
    echo "      Demonstrates: checkbox selection, vim keybindings,"
    echo "      streaming mode, auto-implement, review mode"
    echo ""
    echo "  [1] Phase 1 - File Format Parsing Demo"
    echo "      Run validation tests for MPQ, W3I, and WTS parsers"
    echo "      Demonstrates: archive opening, file extraction,"
    echo "      map metadata parsing, string table resolution"
    echo ""
    echo "  [q] Quit"
    echo ""
}
# }}}

# {{{ run_phase0_demo
run_phase0_demo() {
    echo ""
    echo "========================================"
    echo "  Phase 0: Tooling Demo"
    echo "========================================"
    echo ""
    echo "Launching issue-splitter.sh in interactive mode..."
    echo "Use vim keybindings (j/k to navigate, i/space to select, q to quit)"
    echo ""
    echo "Press Enter to continue or Ctrl+C to cancel..."
    read -r

    "${DIR}/src/cli/issue-splitter.sh" -I
}
# }}}

# {{{ run_phase1_demo
run_phase1_demo() {
    if [[ -x "${DEMOS_DIR}/run_phase1.sh" ]]; then
        "${DEMOS_DIR}/run_phase1.sh"
    else
        echo "Error: Phase 1 demo script not found or not executable"
        echo "Expected: ${DEMOS_DIR}/run_phase1.sh"
        exit 1
    fi
}
# }}}

# {{{ main
main() {
    print_header

    # Check for command line argument
    if [[ -n "$1" ]]; then
        case "$1" in
            0) run_phase0_demo; exit 0 ;;
            1) run_phase1_demo; exit 0 ;;
            *) echo "Unknown phase: $1"; exit 1 ;;
        esac
    fi

    # Interactive menu
    while true; do
        print_menu
        printf "Select demo [0-1, q]: "
        read -r choice

        case "$choice" in
            0) run_phase0_demo ;;
            1) run_phase1_demo ;;
            q|Q) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid selection. Please enter 0, 1, or q." ;;
        esac

        echo ""
        echo "Press Enter to return to menu..."
        read -r
        clear
        print_header
    done
}
# }}}

main "$@"
