#!/bin/bash
# phase-demo.sh — pick a completed phase and run its demonstration.
#
# What it is (for a general): a front desk for the demos. It counts how many
# phase demos exist, asks which one you want, and runs it. Each phase demo is a
# self-contained show of everything the project could do as of that phase. Set
# DIR to relocate the project; pass a number to skip the prompt.

set -u
DIR="${DIR:-/home/ritz/programming/ai-stuff/filesystem-tapestry}"
DEMO_DIR="$DIR/issues/completed/demos"

# -- {{{ list_demos
# Find the phase demos, ordered, so the menu and the count stay in sync with
# whatever is actually on disk (no hard-coded phase total to go stale).
list_demos() {
    ls -1 "$DEMO_DIR"/phase-*-demo.sh 2>/dev/null | sort
}
# }}}

# -- {{{ main
main() {
    local demos
    mapfile -t demos < <(list_demos)
    local n=${#demos[@]}
    if [ "$n" -eq 0 ]; then
        echo "no phase demos found in $DEMO_DIR" >&2
        exit 1
    fi

    local choice="${1:-}"
    if [ -z "$choice" ]; then
        echo "completed phase demos:"
        local i
        for i in "${!demos[@]}"; do
            printf "  %d) %s\n" "$((i + 1))" "$(basename "${demos[$i]}")"
        done
        printf "choose a phase 1-%d: " "$n"
        read -r choice
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$n" ]; then
        echo "not a valid choice: $choice" >&2
        exit 1
    fi

    DIR="$DIR" bash "${demos[$((choice - 1))]}"
}
# }}}

main "$@"
