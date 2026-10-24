#!/usr/bin/env bash
# generate-diversity-cache.sh -- checks for the GPU library, then runs
# scripts/precompute-diversity-sequences-gpu.
#
# Nothing in the build calls it (run.sh runs the GPU step itself), and its
# embeddings check names a model folder that no longer exists
# (embeddinggemma_latest), so it stops there. Kept for now; listed for the
# refactoring pass.
#
# Usage:  scripts/generate-diversity-cache.sh [DIR]

# --help: print the header above and exit, before any work (libs/script-help.sh)
source "$(dirname "$(readlink -f "$0")")/../libs/script-help.sh"
script_help "$0" "$@"

set -euo pipefail

DIR="${1:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
cd "$DIR" || exit 1

# Check for GPU library
if [ ! -f "libs/vulkan-compute/build/libvkcompute.so" ]; then
    echo "Error: GPU library not found" >&2
    echo "Build it with: cd libs/vulkan-compute && make" >&2
    exit 1
fi

# Check for embeddings
if [ ! -f "assets/embeddings/embeddinggemma_latest/embeddings.json" ]; then
    echo "Error: Embeddings not found" >&2
    echo "Generate them with: ./run.sh --generate-embeddings" >&2
    exit 1
fi

echo "🎲 Generating diversity cache with GPU..."
echo ""

# Run GPU script
exec "$DIR/scripts/precompute-diversity-sequences-gpu" "$DIR"
