#!/bin/bash

# test-tiered-themes.sh
# Script to test the new tiered theme system

DIR="/mnt/mtwo/programming/ai-stuff/words-pdf"

# Set up library paths like the main run script
export LD_LIBRARY_PATH="$DIR/libs/libharu-RELEASE_2_3_0/build/src:$LD_LIBRARY_PATH"

# Run the tiered themes test
lua5.2 "$DIR/art-test-tiered-themes.lua" "$DIR"

echo "Tiered themes test completed!"
echo "Check art-test-tiered-output.pdf for results"