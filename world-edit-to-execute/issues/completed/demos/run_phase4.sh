#!/bin/bash
# run_phase4.sh
# Runs the Phase 4 demo: Runtime - Basic Engine Loop
#
# Tests the core runtime systems: game loop, ECS, pathfinding, movement,
# collision detection, resource management, and player state.
#
# Usage:
#   ./run_phase4.sh         # Interactive demo
#   ./run_phase4.sh -n      # Non-interactive (stats only)
#   ./run_phase4.sh -t      # Run tests only
#   ./run_phase4.sh -a      # Run all tests (comprehensive)
#   ./run_phase4.sh -v      # Visual demo (LÖVE2D)

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# {{{ Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'
# }}}

# {{{ print_banner
print_banner() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Phase 4: Runtime - Basic Engine Loop${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}
# }}}

# {{{ run_test
# Run a single test file and track pass/fail
run_test() {
    local name="$1"
    local script="$2"

    if [[ ! -f "$script" ]]; then
        echo -e "  ${YELLOW}[SKIP]${NC} $name (not found)"
        return 1
    fi

    if lua "$script" > /dev/null 2>&1; then
        echo -e "  ${GREEN}[PASS]${NC} $name"
        return 0
    else
        echo -e "  ${RED}[FAIL]${NC} $name"
        return 1
    fi
}
# }}}

# {{{ run_core_tests
run_core_tests() {
    echo -e "${BLUE}=== Core System Tests ===${NC}"
    echo ""

    local passed=0
    local total=0

    # Core systems (408a)
    run_test "Phase 4 Core (gameloop, ECS, pathfinding)" "$DIR/src/tests/test_phase4_core.lua" && ((passed++))
    ((total++))

    # Entity systems (408b)
    run_test "Phase 4 Entity (movement, collision)" "$DIR/src/tests/test_phase4_entity.lua" && ((passed++))
    ((total++))

    # Game loop
    run_test "Game Loop" "$DIR/src/tests/test_gameloop.lua" && ((passed++))
    ((total++))

    run_test "Timers" "$DIR/src/tests/test_timers.lua" && ((passed++))
    ((total++))

    echo ""
    echo -e "Core Systems: ${passed}/${total} passed"
    echo ""

    return $((total - passed))
}
# }}}

# {{{ run_ecs_tests
run_ecs_tests() {
    echo -e "${BLUE}=== ECS Tests ===${NC}"
    echo ""

    local passed=0
    local total=0

    run_test "Entity Manager" "$DIR/src/tests/test_ecs_entity.lua" && ((passed++))
    ((total++))

    run_test "Component Registry" "$DIR/src/tests/test_ecs_component.lua" && ((passed++))
    ((total++))

    run_test "Component Queries" "$DIR/src/tests/test_ecs_query.lua" && ((passed++))
    ((total++))

    run_test "System Registration" "$DIR/src/tests/test_ecs_system.lua" && ((passed++))
    ((total++))

    run_test "WC3 Components" "$DIR/src/tests/test_wc3_components.lua" && ((passed++))
    ((total++))

    echo ""
    echo -e "ECS: ${passed}/${total} passed"
    echo ""

    return $((total - passed))
}
# }}}

# {{{ run_pathfinding_tests
run_pathfinding_tests() {
    echo -e "${BLUE}=== Pathfinding Tests ===${NC}"
    echo ""

    local passed=0
    local total=0

    run_test "Pathing Grid" "$DIR/src/tests/test_pathing_grid.lua" && ((passed++))
    ((total++))

    run_test "A* Algorithm" "$DIR/src/tests/test_astar.lua" && ((passed++))
    ((total++))

    run_test "Coordinate Conversion" "$DIR/src/tests/test_pathing_coords.lua" && ((passed++))
    ((total++))

    run_test "Movement Types" "$DIR/src/tests/test_movement_types.lua" && ((passed++))
    ((total++))

    run_test "Path Smoothing" "$DIR/src/tests/test_path_smoothing.lua" && ((passed++))
    ((total++))

    echo ""
    echo -e "Pathfinding: ${passed}/${total} passed"
    echo ""

    return $((total - passed))
}
# }}}

# {{{ run_movement_tests
run_movement_tests() {
    echo -e "${BLUE}=== Movement & Collision Tests ===${NC}"
    echo ""

    local passed=0
    local total=0

    run_test "Movement Core" "$DIR/src/tests/test_movement_core.lua" && ((passed++))
    ((total++))

    run_test "Path Following" "$DIR/src/tests/test_movement_path.lua" && ((passed++))
    ((total++))

    run_test "Movement Orders" "$DIR/src/tests/test_orders.lua" && ((passed++))
    ((total++))

    run_test "Advanced Movement" "$DIR/src/tests/test_advanced_movement.lua" && ((passed++))
    ((total++))

    run_test "Collision Shapes" "$DIR/src/tests/test_collision_shapes.lua" && ((passed++))
    ((total++))

    run_test "Spatial Hash" "$DIR/src/tests/test_spatial_hash.lua" && ((passed++))
    ((total++))

    run_test "Collision Queries" "$DIR/src/tests/test_collision_queries.lua" && ((passed++))
    ((total++))

    run_test "Movement-Collision Integration" "$DIR/src/tests/test_movement_collision.lua" && ((passed++))
    ((total++))

    run_test "Projectiles & Picking" "$DIR/src/tests/test_projectile_picking.lua" && ((passed++))
    ((total++))

    echo ""
    echo -e "Movement & Collision: ${passed}/${total} passed"
    echo ""

    return $((total - passed))
}
# }}}

# {{{ run_player_tests
run_player_tests() {
    echo -e "${BLUE}=== Player & Resource Tests ===${NC}"
    echo ""

    local passed=0
    local total=0

    run_test "Player State" "$DIR/src/tests/test_player.lua" && ((passed++))
    ((total++))

    run_test "Resources" "$DIR/src/tests/test_resources.lua" && ((passed++))
    ((total++))

    echo ""
    echo -e "Player & Resources: ${passed}/${total} passed"
    echo ""

    return $((total - passed))
}
# }}}

# {{{ run_all_tests
run_all_tests() {
    print_banner
    echo "Running comprehensive Phase 4 test suite..."
    echo ""

    local total_failed=0

    run_core_tests || ((total_failed+=$?))
    run_ecs_tests || ((total_failed+=$?))
    run_pathfinding_tests || ((total_failed+=$?))
    run_movement_tests || ((total_failed+=$?))
    run_player_tests || ((total_failed+=$?))

    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    if [[ $total_failed -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}All Phase 4 tests passed!${NC}"
    else
        echo -e "${YELLOW}${BOLD}Some tests failed: ${total_failed} failures${NC}"
    fi
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    return $total_failed
}
# }}}

# {{{ run_quick_tests
run_quick_tests() {
    print_banner
    echo "Running quick Phase 4 validation..."
    echo ""

    local passed=0
    local total=0

    # Just run the comprehensive core test
    if lua "$DIR/src/tests/test_phase4_core.lua"; then
        echo ""
        echo -e "${GREEN}Phase 4 core systems validated!${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}Phase 4 core tests failed${NC}"
        return 1
    fi
}
# }}}

# {{{ run_visual_demo
run_visual_demo() {
    print_banner
    echo "Launching LÖVE2D visual demo..."
    echo ""
    echo "Controls:"
    echo "  Left Click  - Move red units to position"
    echo "  Space       - Pause/Resume"
    echo "  R           - Reset simulation"
    echo "  Escape      - Quit"
    echo ""

    if command -v love &>/dev/null; then
        love "$DIR/issues/completed/demos/phase4_love"
    else
        echo -e "${RED}Error: LÖVE2D not found. Install with: sudo apt install love${NC}"
        return 1
    fi
}
# }}}

# {{{ main
main() {
    case "${1:-}" in
        -t|--tests)
            run_quick_tests
            ;;
        -a|--all)
            run_all_tests
            ;;
        -n|--non-interactive)
            lua "$DIR/issues/completed/demos/phase4_demo.lua" -n
            ;;
        -v|--visual)
            run_visual_demo
            ;;
        *)
            lua "$DIR/issues/completed/demos/phase4_demo.lua"
            ;;
    esac
}
# }}}

main "$@"
