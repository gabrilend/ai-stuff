#!/bin/bash
# run-demo.sh
# Runs phase demos for World Edit to Execute
#
# Usage:
#   ./run-demo.sh [phase_number]  - Run specific phase demo
#   ./run-demo.sh                 - Interactive selection
#   ./run-demo.sh -I              - Interactive mode
#   ./run-demo.sh -n [phase]      - Non-interactive (headless) mode
#
# This script allows viewing the progress of each completed phase
# through visual demonstrations of implemented functionality.

# {{{ Configuration
DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
COMPLETED_PHASES=1  # Update as phases complete
NON_INTERACTIVE=false
PHASE=""
# }}}

# {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -I|--interactive)
                # Interactive mode (default behavior)
                shift
                ;;
            -n|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS] [PHASE]"
                echo ""
                echo "Options:"
                echo "  -I, --interactive      Interactive mode (default)"
                echo "  -n, --non-interactive  Headless mode (for testing)"
                echo "  -h, --help             Show this help"
                echo ""
                echo "Arguments:"
                echo "  PHASE                  Phase number (1-$COMPLETED_PHASES)"
                echo ""
                echo "Examples:"
                echo "  $0                     # Interactive selection"
                echo "  $0 1                   # Run Phase 1 demo"
                echo "  $0 -n 1               # Run Phase 1 non-interactively"
                exit 0
                ;;
            [0-9]*)
                PHASE="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}
# }}}

# {{{ select_phase
select_phase() {
    if [[ -n "$PHASE" ]]; then
        return
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  WORLD EDIT TO EXECUTE - Phase Demos"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Available phase demos:"
    echo ""

    for i in $(seq 1 $COMPLETED_PHASES); do
        case $i in
            1) echo "  [1] Phase 1 - Foundation: File Format Parsing" ;;
            2) echo "  [2] Phase 2 - Data Model: Game Objects" ;;
            3) echo "  [3] Phase 3 - Logic Layer: Triggers and JASS" ;;
            4) echo "  [4] Phase 4 - Runtime: Basic Engine Loop" ;;
            5) echo "  [5] Phase 5 - Rendering: Visual Abstraction" ;;
            6) echo "  [6] Phase 6 - Asset System: Community Content" ;;
            7) echo "  [7] Phase 7 - Gameplay: Core Mechanics" ;;
            8) echo "  [8] Phase 8 - Multiplayer: Network Layer" ;;
            9) echo "  [9] Phase 9 - Polish: Tools and UX" ;;
        esac
    done

    echo ""
    read -p "Select phase (1-$COMPLETED_PHASES): " PHASE
}
# }}}

# {{{ run_demo
run_demo() {
    local phase="$1"

    # Validate phase number
    if [[ ! "$phase" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid phase number: $phase"
        exit 1
    fi

    if [[ "$phase" -lt 1 || "$phase" -gt "$COMPLETED_PHASES" ]]; then
        echo "Error: Phase $phase demo not available"
        echo "Available phases: 1-$COMPLETED_PHASES"
        exit 1
    fi

    local demo_script="$DIR/issues/completed/demos/phase${phase}_demo.lua"

    if [[ ! -f "$demo_script" ]]; then
        echo "Error: Demo script not found: $demo_script"
        exit 1
    fi

    # Run the demo
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        lua5.4 "$demo_script" -n
    else
        lua5.4 "$demo_script"
    fi
}
# }}}

# {{{ main
main() {
    parse_args "$@"
    select_phase
    run_demo "$PHASE"
}
# }}}

main "$@"
