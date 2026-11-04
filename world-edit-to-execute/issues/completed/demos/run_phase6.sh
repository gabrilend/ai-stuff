#!/bin/bash
# run_phase6.sh
# Runs the Phase 6 demo: the asset system, scenario by scenario.
#
# Each scenario is the integration test's own (src/tests/test_phase6_integration.lua):
#   map_loading  a real map's textures, a pack's sound, the loader's cache
#   fallback     the wire-frame stand-in for a missing asset, and a blank map's grid
#   download     a shared list from another player: only the missing files come over
#   dedup        two packs sharing a file store it once; deleting and gc
#   storage      the storage manager's totals, deleting a pack, gc
#   hotreload    a saved texture reloaded and swapped; a broken save keeps the old one
#
# Nothing touches the network or needs a window. A scenario whose part of
# phase 6 isn't merged yet says so and is skipped.
#
# Usage:
#   ./run_phase6.sh [DIR]

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# Allow override
if [ -n "$1" ]; then
    DIR="$1"
fi

TEST="${DIR}/src/tests/test_phase6_integration.lua"

# {{{ run_scenario
run_scenario() {
    local number="$1" name="$2" title="$3"
    echo "Test ${number}: ${title}..."
    luajit "$TEST" "$DIR" --scenario="$name" | grep -v "^Tests:"
    echo ""
}
# }}}

echo "=== Phase 6: Asset System Demo ==="
echo ""
run_scenario 1 map_loading "Loading assets from a WC3 map"
run_scenario 2 fallback "Wire-frame fallback for missing assets"
run_scenario 3 download "Assets from another player"
run_scenario 4 dedup "Asset deduplication"
run_scenario 5 storage "Storage management"
run_scenario 6 hotreload "Hot-reload"

echo "=== Phase 6 Summary ==="
luajit "$TEST" "$DIR" --summary | sed -n '/=== Phase 6 summary ===/,$p' | tail -n +2
