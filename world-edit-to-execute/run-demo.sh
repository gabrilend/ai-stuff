#!/bin/bash
# World Edit to Execute - Interactive Phase Demonstration
# Runs phase demos showcasing project achievements
#
# Usage:
#   ./run-demo.sh                 - Interactive selection
#   ./run-demo.sh [phase_number]  - Run specific phase demo
#   ./run-demo.sh -n [phase]      - Non-interactive (headless) mode
#   ./run-demo.sh -h              - Show help

# {{{ setup_dir_path
# Sets DIR to either the provided directory argument or the default path.
# Only treats $1 as a directory if it exists as one.
setup_dir_path() {
    if [ -n "$1" ] && [ -d "$1" ]; then
        echo "$1"
    else
        echo "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
    fi
}
# }}}

# Check if first arg is a directory, if so use it and shift
if [ -d "$1" ]; then
    DIR="$1"
    shift
else
    DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
fi

COMPLETED_PHASES=5
NON_INTERACTIVE=false
PHASE=""

# {{{ Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
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
            -t|--tests)
                # Run tests and exit
                run_tests
                exit $?
                ;;
            -h|--help)
                echo "Usage: $0 [DIR] [OPTIONS] [PHASE]"
                echo ""
                echo "World Edit to Execute - Phase Demo Runner"
                echo ""
                echo "Options:"
                echo "  -I, --interactive      Interactive mode (default)"
                echo "  -n, --non-interactive  Headless mode (for testing)"
                echo "  -t, --tests            Run all tests with streaming output"
                echo "  -h, --help             Show this help"
                echo ""
                echo "Arguments:"
                echo "  DIR                    Project directory (optional)"
                echo "  PHASE                  Phase number (0-$COMPLETED_PHASES)"
                echo ""
                echo "Examples:"
                echo "  $0                     # Interactive selection"
                echo "  $0 0                   # Run Phase 0 demo (tooling)"
                echo "  $0 1                   # Run Phase 1 demo (file parsing)"
                echo "  $0 -n 1               # Run Phase 1 non-interactively"
                echo "  $0 -t                 # Run all tests"
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

# {{{ show_main_menu
show_main_menu() {
    clear
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}              WORLD EDIT TO EXECUTE${NC}"
    echo -e "${CYAN}              Interactive Phase Demonstration${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "PROJECT STATUS: WC3 Map Engine | Reads .w3x like emulator reads ROMs"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────────┐"
    echo "│ PHASE DEMONSTRATIONS                                                    │"
    echo "├─────────────────────────────────────────────────────────────────────────┤"
    echo -e "│ [0] Phase 0: Tooling & Infrastructure               ${GREEN}✅ 100% Complete${NC}   │"
    echo -e "│ [1] Phase 1: Foundation - File Format Parsing       ${GREEN}✅ 100% Complete${NC}   │"
    echo -e "│ [2] Phase 2: Data Model - Game Objects              ${GREEN}✅ 100% Complete${NC}   │"
    echo -e "│ [3] Phase 3: Logic Layer - Triggers and JASS        ${GREEN}✅ 100% Complete${NC}   │"
    echo -e "│ [4] Phase 4: Runtime - Basic Engine Loop            ${GREEN}✅ 100% Complete${NC}   │"
    echo -e "│ [5] Phase 5: Rendering - Threading Architecture     ${GREEN}✅ In Progress${NC}    │"
    echo -e "│ [6] Phase 6: Asset System - Community Content       ${YELLOW}⏳ Pending${NC}         │"
    echo -e "│ [7] Phase 7: Gameplay - Core Mechanics              ${YELLOW}⏳ Pending${NC}         │"
    echo -e "│ [8] Phase 8: Multiplayer - Network Layer            ${YELLOW}⏳ Pending${NC}         │"
    echo -e "│ [9] Phase 9: Polish - Tools and UX                  ${YELLOW}⏳ Pending${NC}         │"
    echo "├─────────────────────────────────────────────────────────────────────────┤"
    echo "│ [S] Project Statistics & Architecture                                  │"
    echo "│ [T] Run Tests (Phase 1 validation)                                     │"
    echo "│ [Q] Quit                                                               │"
    echo "└─────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo -n "Select option [0-9/S/T/Q]: "
}
# }}}

# {{{ run_phase0_demo
run_phase0_demo() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PHASE 0: TOOLING & INFRASTRUCTURE${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "This phase established development tooling for the project."
    echo ""
    echo -e "${BOLD}Completed Features (18 issues):${NC}"
    echo "  - Issue splitter with automated analysis"
    echo "  - Streaming queue for parallel processing"
    echo "  - Execute mode for auto-generating sub-issues"
    echo "  - Checkbox-style TUI with vim keybindings"
    echo "  - Shared TUI library for cross-project reuse"
    echo "  - Auto-implement via Claude CLI"
    echo ""

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        echo "[Non-interactive] Skipping TUI launch"
        echo "Phase 0 tools available at: ${DIR}/src/cli/issue-splitter.sh"
        return 0
    fi

    echo -e "${BOLD}Controls:${NC}"
    echo "  j/k or arrows  - Navigate"
    echo "  i/space        - Select/toggle"
    echo "  Enter          - Confirm"
    echo "  q              - Quit"
    echo ""
    echo "Press Enter to launch interactive mode..."
    read -r

    "${DIR}/src/cli/issue-splitter.sh" -I
}
# }}}

# {{{ run_phase1_demo
run_phase1_demo() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PHASE 1: FOUNDATION - FILE FORMAT PARSING${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local demo_script="${DIR}/issues/completed/demos/phase1_demo.lua"

    if [[ ! -f "$demo_script" ]]; then
        echo -e "${RED}Error: Demo script not found: $demo_script${NC}"
        return 1
    fi

    # Find lua interpreter (prefer lua5.4 or lua for string.unpack support)
    local lua_cmd=""
    if command -v lua5.4 &>/dev/null; then
        lua_cmd="lua5.4"
    elif command -v lua &>/dev/null; then
        lua_cmd="lua"
    else
        echo -e "${RED}ERROR: No lua interpreter found${NC}"
        return 1
    fi

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        $lua_cmd "$demo_script" -n
    else
        $lua_cmd "$demo_script"
    fi
}
# }}}

# {{{ run_phase2_demo
run_phase2_demo() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PHASE 2: DATA MODEL - GAME OBJECTS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local demo_script="${DIR}/issues/completed/demos/phase2_demo.lua"

    if [[ ! -f "$demo_script" ]]; then
        echo -e "${RED}Error: Demo script not found: $demo_script${NC}"
        return 1
    fi

    # Find lua interpreter (prefer luajit for Phase 2)
    local lua_cmd=""
    if command -v luajit &>/dev/null; then
        lua_cmd="luajit"
    elif command -v lua5.4 &>/dev/null; then
        lua_cmd="lua5.4"
    elif command -v lua &>/dev/null; then
        lua_cmd="lua"
    else
        echo -e "${RED}ERROR: No lua interpreter found${NC}"
        return 1
    fi

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        $lua_cmd "$demo_script" -n
    else
        $lua_cmd "$demo_script"
    fi
}
# }}}

# {{{ run_phase3_demo
run_phase3_demo() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PHASE 3: LOGIC LAYER - TRIGGERS AND JASS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local demo_script="${DIR}/issues/completed/demos/run_phase3.sh"

    if [[ ! -f "$demo_script" ]]; then
        echo -e "${RED}Error: Demo script not found: $demo_script${NC}"
        return 1
    fi

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        bash "$demo_script" -n
    else
        bash "$demo_script"
    fi
}
# }}}

# {{{ run_phase4_demo
run_phase4_demo() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PHASE 4: RUNTIME - BASIC ENGINE LOOP${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local demo_script="${DIR}/issues/completed/demos/run_phase4.sh"

    if [[ ! -f "$demo_script" ]]; then
        echo -e "${RED}Error: Demo script not found: $demo_script${NC}"
        return 1
    fi

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        bash "$demo_script" -n
    else
        bash "$demo_script"
    fi
}
# }}}

# {{{ run_phase5_demo
run_phase5_demo() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PHASE 5: RENDERING - THREADING ARCHITECTURE${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local demo_script="${DIR}/issues/completed/demos/run_phase5.sh"

    if [[ ! -f "$demo_script" ]]; then
        echo -e "${RED}Error: Demo script not found: $demo_script${NC}"
        return 1
    fi

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        bash "$demo_script" -t
    else
        bash "$demo_script"
    fi
}
# }}}

# {{{ run_test_file
# Run a test file and stream output with colorization
# Writes pass/fail counts to temp file
run_test_file() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .lua)

    if [[ ! -f "$test_file" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} ${test_name} (not found)"
        return
    fi

    echo -e "  ${CYAN}▶${NC} ${test_name}"

    # Prefer luajit for bitwise operations (Phase 1 needs it)
    local lua_cmd="lua"
    if command -v luajit &>/dev/null; then
        lua_cmd="luajit"
    elif command -v lua5.4 &>/dev/null; then
        lua_cmd="lua5.4"
    fi

    # Run and stream output, colorizing PASS/FAIL
    # Handle both "PASS" and "PASS: description" formats
    $lua_cmd "$test_file" 2>&1 | while IFS= read -r line; do
        if [[ "$line" =~ PASS:\ (.+) ]]; then
            # "PASS: description" format
            echo -e "    ${GREEN}✓${NC} ${BASH_REMATCH[1]}"
            printf "P" >> "$TEMP_COUNTS"
        elif [[ "$line" =~ \.\.\.\ *PASS$ ]]; then
            # "Testing name... PASS" format
            local desc="${line%...*}"
            desc="${desc#Testing }"
            echo -e "    ${GREEN}✓${NC} ${desc}"
            printf "P" >> "$TEMP_COUNTS"
        elif [[ "$line" =~ FAIL:\ (.+) ]]; then
            # "FAIL: description" format
            echo -e "    ${RED}✗${NC} ${BASH_REMATCH[1]}"
            printf "F" >> "$TEMP_COUNTS"
        elif [[ "$line" =~ \.\.\.\ *FAIL$ ]]; then
            # "Testing name... FAIL" format (unlikely)
            local desc="${line%...*}"
            desc="${desc#Testing }"
            echo -e "    ${RED}✗${NC} ${desc}"
            printf "F" >> "$TEMP_COUNTS"
        elif [[ "$line" == "==="* ]]; then
            # Section header - show abbreviated
            local section="${line//=/}"
            section="${section## }"
            section="${section%% }"
            if [[ -n "$section" ]]; then
                echo -e "    ${BLUE}─${NC} ${section}"
            fi
        fi
    done
}
# }}}

# {{{ run_tests
run_tests() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}ALL PHASE VALIDATION TESTS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"

    # Create temp file for counting pass/fail
    TEMP_COUNTS=$(mktemp)
    export TEMP_COUNTS
    trap "rm -f $TEMP_COUNTS" EXIT

    # Phase 1: File Parsing (MPQ, W3I, WTS, W3E)
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 1: File Parsing ─────────────────────────────────────────────────┐${NC}"
    for test in test_mpq test_w3i test_wts test_w3e test_data; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Phase 2: Data Model (Doodads, Units, Regions, Registry)
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 2: Data Model ───────────────────────────────────────────────────┐${NC}"
    for test in test_doo test_unitsdoo test_w3r test_gameobjects test_registry; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Phase 3: Triggers and JASS
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 3: Triggers and JASS ────────────────────────────────────────────┐${NC}"
    for test in test_jass_lexer test_parser test_transpiler test_triggers; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Phase 4: Runtime
    echo ""
    echo -e "${BOLD}${BLUE}┌─ Phase 4: Runtime ──────────────────────────────────────────────────────┐${NC}"
    for test in test_phase4_core test_phase4_player test_gameloop test_resources; do
        run_test_file "${DIR}/src/tests/${test}.lua"
    done

    # Count results from temp file (counts P and F characters)
    local total_passed=0
    local total_failed=0
    if [[ -f "$TEMP_COUNTS" ]]; then
        local counts
        counts=$(cat "$TEMP_COUNTS")
        # Count P and F characters
        total_passed=$(echo -n "$counts" | tr -cd 'P' | wc -c)
        total_failed=$(echo -n "$counts" | tr -cd 'F' | wc -c)
    fi

    # Summary
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    if [[ $total_failed -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}All tests passed!${NC} ${GREEN}${total_passed}${NC} tests"
    else
        echo -e "Results: ${GREEN}${total_passed} passed${NC}, ${RED}${total_failed} failed${NC}"
    fi
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    rm -f "$TEMP_COUNTS"
    [[ $total_failed -eq 0 ]]
}
# }}}

# {{{ show_statistics
show_statistics() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PROJECT STATISTICS & ARCHITECTURE${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${BOLD}Project Vision:${NC}"
    echo "  A WC3-compatible game engine that reads Warcraft 3 map files (.w3x/.w3m)"
    echo "  like an emulator reads ROMs. Community-supplied visuals rather than"
    echo "  recreating original aesthetics."
    echo ""

    echo -e "${BOLD}Architecture:${NC}"
    echo "  src/mpq/        - MPQ archive parsing (header, hash, block, extract)"
    echo "  src/parsers/    - Content parsers (w3i, wts, w3e)"
    echo "  src/data/       - Unified Map data structure"
    echo "  src/cli/        - Command-line tools (mapdump, issue-splitter)"
    echo ""

    # Count issues
    local total_issues=$(find "${DIR}/issues" -maxdepth 1 -name "*.md" | wc -l)
    local completed_issues=$(find "${DIR}/issues/completed" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
    local test_maps=$(find "${DIR}/assets" -name "*.w3x" 2>/dev/null | wc -l)

    echo -e "${BOLD}Metrics:${NC}"
    echo "  Total Issues:     $total_issues"
    echo "  Completed:        $completed_issues"
    echo "  Test Maps:        $test_maps"
    echo ""

    echo -e "${BOLD}Phase Status:${NC}"
    echo -e "  ${GREEN}[DONE]${NC} Phase 0: Tooling & Infrastructure"
    echo -e "  ${GREEN}[DONE]${NC} Phase 1: File Format Parsing"
    echo -e "  ${GREEN}[DONE]${NC} Phase 2: Data Model - Game Objects"
    echo -e "  ${GREEN}[DONE]${NC} Phase 3: Logic Layer - Triggers and JASS"
    echo -e "  ${GREEN}[DONE]${NC} Phase 4: Runtime - Basic Engine Loop"
    echo -e "  ${CYAN}[WIP]${NC}  Phase 5: Rendering - Threading Architecture"
    echo -e "  ${YELLOW}[TODO]${NC} Phase 6: Asset System - Community Content"
    echo -e "  ${YELLOW}[TODO]${NC} Phase 7: Gameplay - Core Mechanics"
    echo -e "  ${YELLOW}[TODO]${NC} Phase 8: Multiplayer - Network Layer"
    echo -e "  ${YELLOW}[TODO]${NC} Phase 9: Polish - Tools and UX"
    echo ""

    echo -e "${BOLD}Implementation Language:${NC} Lua (LuaJIT compatible)"
}
# }}}

# {{{ run_phase_demo
run_phase_demo() {
    local phase="$1"

    case "$phase" in
        0)
            run_phase0_demo
            ;;
        1)
            run_phase1_demo
            ;;
        2)
            run_phase2_demo
            ;;
        3)
            run_phase3_demo
            ;;
        4)
            run_phase4_demo
            ;;
        5)
            run_phase5_demo
            ;;
        [6-9])
            echo ""
            echo -e "${YELLOW}Phase $phase demo not yet available.${NC}"
            echo "This phase is pending implementation."
            echo ""
            echo "See issues/progress.md for current development status."
            ;;
        S|s)
            show_statistics
            ;;
        T|t)
            run_tests
            ;;
        *)
            echo -e "${RED}Invalid phase: $phase${NC}"
            return 1
            ;;
    esac
}
# }}}

# {{{ wait_for_key
wait_for_key() {
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo ""
        echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -n "Press Enter to continue..."
        read -r
    fi
}
# }}}

# {{{ main
main() {
    parse_args "$@"

    # Direct phase selection
    if [[ -n "$PHASE" ]]; then
        run_phase_demo "$PHASE"
        exit $?
    fi

    # Non-interactive without phase specified
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        echo "Error: Non-interactive mode requires a phase number"
        echo "Usage: $0 -n [phase]"
        exit 1
    fi

    # Interactive menu loop
    while true; do
        show_main_menu
        read -r choice

        case "$choice" in
            [0-9])
                run_phase_demo "$choice"
                wait_for_key
                ;;
            [Ss])
                run_phase_demo "S"
                wait_for_key
                ;;
            [Tt])
                run_phase_demo "T"
                wait_for_key
                ;;
            [Qq])
                echo ""
                echo "Thank you for exploring World Edit to Execute!"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid selection. Please choose 0-9, S, T, or Q.${NC}"
                sleep 2
                ;;
        esac
    done
}
# }}}

main "$@"
