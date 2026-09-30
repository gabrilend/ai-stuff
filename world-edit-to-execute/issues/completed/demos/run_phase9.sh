#!/bin/bash
# Phase 9 (the World Editor) demo: makes a new two-player melee map, runs
# the editor's integration test on it (every part of the editor, saved,
# reopened, played), then opens the editor's window on the new map.
#   ./issues/completed/demos/run_phase9.sh [project dir]
DIR="${1:-$(cd "$(dirname "$0")/../../.." && pwd)}"
cd "${DIR}" || exit 1
MAP="${DIR}/maps-demo-phase9.w3x"

echo "=== Phase 9: World Editor Demo ==="
echo ""
echo "Making a new map: ${MAP}"
luajit src/editor/new_map.lua "${MAP}" --name "Phase 9 Demo" --size 96 --players human,orc:computer || exit 1
echo ""
echo "Running the editor's integration test..."
luajit src/tests/test_editor_integration.lua "${DIR}" | tail -3
echo ""
echo "Opening the editor on the new map (Triggers, AI, Files, Sounds on the toolbar)..."
./src/render/run-editor "${MAP}"
echo ""
echo "=== Phase 9 Demo Complete ==="
