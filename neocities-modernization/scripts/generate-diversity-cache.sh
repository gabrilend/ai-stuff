#!/usr/bin/env bash
# Wrapper script for diversity cache generation
# Ensures GPU version is used by default

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
