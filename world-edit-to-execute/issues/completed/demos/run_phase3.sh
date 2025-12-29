#!/bin/bash
# run_phase3.sh
# Runs the Phase 3 demo: Logic Layer - Triggers and JASS
#
# Usage:
#   ./run_phase3.sh         # Interactive mode
#   ./run_phase3.sh -n      # Non-interactive (just stats)
#   ./run_phase3.sh -t      # Run tests only

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# {{{ run_tests
run_tests() {
    echo "Running Phase 3 Integration Tests..."
    echo ""

    luajit "$DIR/src/tests/test_309a_trigger_files.lua" && \
    luajit "$DIR/src/tests/test_309b_lexer.lua" && \
    luajit "$DIR/src/tests/test_309c_parser.lua" && \
    luajit "$DIR/src/tests/test_309d_transpiler.lua" && \
    luajit "$DIR/src/tests/test_309e_runtime.lua" && \
    luajit "$DIR/src/tests/test_309f_events.lua"

    return $?
}
# }}}

# {{{ main
main() {
    case "${1:-}" in
        -t|--tests)
            run_tests
            ;;
        -n|--non-interactive)
            luajit "$DIR/issues/completed/demos/phase3_demo.lua" -n
            ;;
        *)
            luajit "$DIR/issues/completed/demos/phase3_demo.lua"
            ;;
    esac
}
# }}}

main "$@"
