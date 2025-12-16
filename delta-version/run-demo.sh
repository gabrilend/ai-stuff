#!/bin/bash
# Demo runner utility for Delta-Version phase demonstrations
# Discovers, validates, and runs phase demo scripts from issues/completed/demos/

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

# -- {{{ discover_demos
function discover_demos() {
    local demos_dir="${DIR}/issues/completed/demos"

    if [[ -d "$demos_dir" ]]; then
        find "$demos_dir" -name "phase-*-demo.sh" -type f 2>/dev/null | sort
    fi
}
# }}}

# -- {{{ validate_demo
function validate_demo() {
    local demo_script="$1"

    [[ -f "$demo_script" ]] || return 1

    # Check for valid bash shebang
    head -1 "$demo_script" 2>/dev/null | grep -q '^#!/bin/bash' || return 1

    return 0
}
# }}}

# -- {{{ get_phase_number
function get_phase_number() {
    local demo_path="$1"
    basename "$demo_path" | grep -oP 'phase-\K\d+' || echo "?"
}
# }}}

# -- {{{ list_demos
function list_demos() {
    local demos=("$@")
    local count=${#demos[@]}

    if [[ $count -eq 0 ]]; then
        echo "No phase demos found in ${DIR}/issues/completed/demos/"
        echo "Demo scripts should be named: phase-N-demo.sh"
        return 1
    fi

    echo "Available Phase Demos:"
    echo "======================"

    for demo in "${demos[@]}"; do
        local phase_num
        phase_num=$(get_phase_number "$demo")
        local status="Ready"
        validate_demo "$demo" || status="Invalid"
        printf "  Phase %s: %s [%s]\n" "$phase_num" "$(basename "$demo")" "$status"
    done

    echo
    echo "Total: $count demo(s)"
}
# }}}

# -- {{{ run_demo
function run_demo() {
    local demo_script="$1"
    local phase_num
    phase_num=$(get_phase_number "$demo_script")

    echo
    echo "========================================"
    echo "Running Phase $phase_num Demo"
    echo "Script: $(basename "$demo_script")"
    echo "========================================"
    echo

    if validate_demo "$demo_script"; then
        # Run the demo script
        bash "$demo_script"
        local exit_code=$?

        echo
        echo "========================================"
        echo "Demo completed with exit code: $exit_code"
        echo "========================================"

        return $exit_code
    else
        echo "ERROR: Demo script is not valid"
        echo "  - File must exist: $([ -f "$demo_script" ] && echo "Yes" || echo "No")"
        echo "  - Must have #!/bin/bash shebang"
        return 1
    fi
}
# }}}

# -- {{{ run_phase_demo
function run_phase_demo() {
    local target_phase="$1"
    shift
    local demos=("$@")

    for demo in "${demos[@]}"; do
        local phase_num
        phase_num=$(get_phase_number "$demo")

        if [[ "$phase_num" == "$target_phase" ]]; then
            run_demo "$demo"
            return $?
        fi
    done

    echo "ERROR: No demo found for phase $target_phase"
    echo "Use --list to see available demos"
    return 1
}
# }}}

# -- {{{ show_demo_menu
function show_demo_menu() {
    local demos=("$@")
    local count=${#demos[@]}

    echo "=== Delta-Version Phase Demos ==="
    echo "Available demos: $count"
    echo

    if [[ $count -eq 0 ]]; then
        echo "No demos available yet."
        echo "Demo scripts should be placed in: ${DIR}/issues/completed/demos/"
        echo "Named as: phase-N-demo.sh (e.g., phase-1-demo.sh)"
        return 1
    fi

    local i=1
    for demo in "${demos[@]}"; do
        local phase_num
        phase_num=$(get_phase_number "$demo")
        local status="Ready"
        validate_demo "$demo" || status="Invalid"
        printf "  %d. Phase %s Demo [%s]\n" "$i" "$phase_num" "$status"
        ((i++))
    done

    echo
    echo "  q. Quit"
    echo
    read -p "Select demo to run [1-$count, q]: " choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "Exiting."
        return 0
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
        run_demo "${demos[$((choice-1))]}"
        return $?
    else
        echo "Invalid selection: $choice"
        return 1
    fi
}
# }}}

# -- {{{ run_interactive_mode
function run_interactive_mode() {
    local demos
    mapfile -t demos < <(discover_demos)

    show_demo_menu "${demos[@]}"
}
# }}}

# -- {{{ show_help
function show_help() {
    echo "Usage: run-demo.sh [OPTIONS]"
    echo
    echo "Demo runner utility for Delta-Version phase demonstrations."
    echo "Discovers and runs phase demo scripts from issues/completed/demos/"
    echo
    echo "Options:"
    echo "  -p, --phase NUM    Run demo for specific phase number"
    echo "  -l, --list         List available demos without running"
    echo "  -I, --interactive  Run in interactive mode (default)"
    echo "  --help             Show this help message"
    echo
    echo "Examples:"
    echo "  ./run-demo.sh              # Interactive mode"
    echo "  ./run-demo.sh -p 1         # Run phase 1 demo"
    echo "  ./run-demo.sh --list       # List available demos"
    echo "  DIR=/custom/path ./run-demo.sh   # Custom directory"
    echo
    echo "Demo scripts should be named: phase-N-demo.sh"
    echo "Location: \$DIR/issues/completed/demos/"
}
# }}}

# -- {{{ main
function main() {
    local phase_num=""
    local list_only=false
    local interactive=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--phase)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "ERROR: --phase requires a number argument"
                    exit 1
                fi
                phase_num="$2"
                shift 2
                ;;
            -l|--list)
                list_only=true
                shift
                ;;
            -I|--interactive)
                interactive=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Discover demos
    local demos
    mapfile -t demos < <(discover_demos)

    # Execute based on mode
    if [[ "$list_only" == "true" ]]; then
        list_demos "${demos[@]}"
    elif [[ -n "$phase_num" ]]; then
        run_phase_demo "$phase_num" "${demos[@]}"
    else
        # Default to interactive mode
        run_interactive_mode
    fi
}
# }}}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
