#!/bin/bash
# run_phase2.sh
# Phase 2 Demo Runner - Data Model (Game Objects)
#
# Runs Phase 2 integration tests followed by the interactive demo.
# Validates all Phase 2 components work together before showing results.
#
# Usage:
#   ./run_phase2.sh         - Run tests then interactive demo
#   ./run_phase2.sh -n      - Run tests and demo non-interactively

# {{{ setup_dir
DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
# }}}

# {{{ Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
# }}}

# {{{ find_lua
# Find appropriate lua interpreter
find_lua() {
    if command -v luajit &>/dev/null; then
        echo "luajit"
    elif command -v lua5.4 &>/dev/null; then
        echo "lua5.4"
    elif command -v lua &>/dev/null; then
        echo "lua"
    else
        echo ""
    fi
}
# }}}

# {{{ main
main() {
    local LUA_CMD=$(find_lua)
    local NON_INTERACTIVE=false

    if [[ "$1" == "-n" || "$1" == "--non-interactive" ]]; then
        NON_INTERACTIVE=true
    fi

    if [[ -z "$LUA_CMD" ]]; then
        echo -e "${RED}ERROR: No lua interpreter found (need luajit, lua5.4, or lua)${NC}"
        exit 1
    fi

    cd "$DIR"

    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PHASE 2: DATA MODEL - GAME OBJECTS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Run integration tests
    echo -e "${YELLOW}Running Phase 2 Integration Tests...${NC}"
    echo ""

    if $LUA_CMD src/tests/test_phase2_integration.lua; then
        echo ""
        echo -e "${GREEN}Integration tests passed!${NC}"
        echo ""

        # Run demo
        echo -e "${YELLOW}Running Phase 2 Demo...${NC}"
        echo ""

        if [[ "$NON_INTERACTIVE" == "true" ]]; then
            $LUA_CMD issues/completed/demos/phase2_demo.lua -n
        else
            $LUA_CMD issues/completed/demos/phase2_demo.lua
        fi
    else
        echo ""
        echo -e "${RED}Integration tests failed, skipping demo${NC}"
        exit 1
    fi
}
# }}}

main "$@"
