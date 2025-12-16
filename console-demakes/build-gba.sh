#!/bin/bash
# Build script for GBA Ocarina of Time Demake

echo "Building GBA Ocarina of Time Demake..."

# Set up toolchain
source tools/setup-gba.sh

# Build the ROM
cd src-gba
make clean
make

if [ $? -eq 0 ]; then
    echo "✓ Build successful!"
    echo "ROM: src-gba/oot_demake_gba.gba"
    echo "Size: $(wc -c < oot_demake_gba.gba) bytes"
    echo ""
    echo "You can now run this ROM in any GBA emulator:"
    echo "  - mGBA"
    echo "  - VBA-M" 
    echo "  - No$GBA"
    echo "  - Or on real hardware via flash cart"
else
    echo "✗ Build failed!"
    exit 1
fi