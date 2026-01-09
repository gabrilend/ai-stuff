#!/bin/bash
# Authorship Tool - Phase Demo Runner
# Runs demonstration programs for completed phases

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Allow directory to be provided as argument
if [ -n "$1" ]; then
    DIR="$1"
fi

cd "$DIR" || exit 1

clear
echo "=========================================="
echo "  Authorship Tool - Phase Demonstrations"
echo "=========================================="
echo ""
echo "Select a phase to demonstrate:"
echo ""
echo "  1) Phase 1 - Foundation & Core Infrastructure"
echo "  2) Phase 2 - Document Analysis & Entity Extraction (not yet available)"
echo "  3) Phase 3 - Semantic Graph Construction (not yet available)"
echo "  4) Phase 4 - Question Generation System (not yet available)"
echo ""
echo "  q) Quit"
echo ""
read -p "Enter phase number: " phase

case $phase in
    1)
        if [ -f "${DIR}/issues/completed/demos/run-phase-1-demo.sh" ]; then
            "${DIR}/issues/completed/demos/run-phase-1-demo.sh" "$DIR"
        else
            echo ""
            echo "Phase 1 demo not yet implemented."
            echo "Complete issues 101-107 to create Phase 1 demo."
            echo ""
        fi
        ;;
    2|3|4)
        echo ""
        echo "Phase $phase demo not yet available."
        echo "This phase has not been completed yet."
        echo ""
        ;;
    q|Q)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo ""
        echo "Invalid selection."
        echo ""
        ;;
esac
