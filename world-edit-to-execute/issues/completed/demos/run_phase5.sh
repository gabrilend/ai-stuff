#!/bin/bash
# run_phase5.sh
# Runs the Phase 5 demo: Rendering - Threading Architecture
#
# Demonstrates the v2 threading architecture with interactive visualization:
# - Ring buffer task lists per worker
# - Weight-based load balancing
# - Watch list sync (parallel pointer swaps)
# - Self-hosted updater task
# - Helper spawning on overload
#
# Controls:
#   F5: Toggle threading demo overlay
#   T:  Inject test task
#   H:  Inject heavy task
#   S:  Inject sleep task
#   1-9: Set auto-injection rate (x10 tasks/sec)
#   R:  Reset statistics
#
# Usage:
#   ./run_phase5.sh         # Interactive mode (graphics)
#   ./run_phase5.sh -t      # Run threading tests only

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# Allow override
if [ -n "$1" ] && [ "$1" != "-t" ] && [ "$1" != "--tests" ]; then
    DIR="$1"
fi

# {{{ run_tests
run_tests() {
    echo "Running Phase 5 Threading Tests..."
    echo ""

    cd "${DIR}/src/render"

    # Compile test
    gcc -pthread -Wall -g -Og \
        -o test_threading test_threading.c threading.c \
        -I/usr/include/luajit-2.1 \
        -lluajit-5.1 \
        -lm -lpthread -ldl -lrt \
        2>&1

    if [ $? -ne 0 ]; then
        echo "Compilation failed"
        return 1
    fi

    # Run tests
    ./test_threading
    result=$?

    # Cleanup
    rm -f test_threading

    cd - > /dev/null
    return $result
}
# }}}

# {{{ run_demo
run_demo() {
    echo "=== Phase 5: Threading Architecture Demo ==="
    echo ""
    echo "Press F5 to toggle threading visualization"
    echo ""

    cd "${DIR}/src/render"

    # Run the build script which compiles and runs
    bash run

    cd - > /dev/null
}
# }}}

# {{{ main
main() {
    case "${1:-}" in
        -t|--tests)
            run_tests
            ;;
        *)
            run_demo
            ;;
    esac
}
# }}}

main "$@"
