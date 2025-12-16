#!/bin/bash
# GBA Development Environment Setup Script

# Set up toolchain paths
export ARM_TOOLCHAIN_PATH="/mnt/mtwo/programming/ai-stuff/console-demakes/tools/gba-toolchain/gcc-arm-none-eabi-10.3-2021.10"
export PATH="$ARM_TOOLCHAIN_PATH/bin:$PATH"

# Create symlinks for easier access
mkdir -p tools/bin
ln -sf "$ARM_TOOLCHAIN_PATH/bin/arm-none-eabi-gcc" tools/bin/arm-none-eabi-gcc
ln -sf "$ARM_TOOLCHAIN_PATH/bin/arm-none-eabi-objcopy" tools/bin/arm-none-eabi-objcopy
ln -sf "$ARM_TOOLCHAIN_PATH/bin/arm-none-eabi-objdump" tools/bin/arm-none-eabi-objdump

echo "GBA toolchain configured!"
echo "Compiler: $(tools/bin/arm-none-eabi-gcc --version | head -1)"