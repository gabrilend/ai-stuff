#!/bin/bash

# test-clean-with-poems.sh
# Script to test the updated clean art test with sample poems

DIR="/mnt/mtwo/programming/ai-stuff/words-pdf"

# Set up library paths
export LD_LIBRARY_PATH="$DIR/libs/libharu-RELEASE_2_3_0/build/src:$LD_LIBRARY_PATH"

# Run the updated clean test
lua5.2 "$DIR/art-test-clean.lua" "$DIR"

echo "Updated clean art test completed!"
echo "Check art-test-output.pdf for results with sample poems"