#!/bin/bash
# scripts/generate-config.sh
# Generates src/000-config.h from config.txt
# This script parses the config file and creates a C header with #define statements
# Run before compilation to update compile-time constants

# Hard-coded project directory (can be overridden via argument)
DIR="/mnt/mtwo/programming/ai-stuff/games/physics-sim"

# Allow directory override via argument
if [ -n "$1" ]; then
    DIR="$1"
fi

CONFIG_FILE="${DIR}/config.txt"
OUTPUT_FILE="${DIR}/src/000-config.h"

# Check config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Generate header file
{
    echo "// src/000-config.h"
    echo "// Auto-generated from config.txt - do not edit manually"
    echo "// Regenerate with: scripts/generate-config.sh"
    echo ""
    echo "#ifndef CONFIG_H"
    echo "#define CONFIG_H"
    echo ""

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Parse KEY=VALUE (trim whitespace)
        key="${line%%=*}"
        value="${line#*=}"
        key="${key// /}"
        value="${value// /}"

        # Skip if no valid key
        [ -z "$key" ] && continue

        # Detect if value needs .0f suffix (for floats)
        # Keys containing CREDITS are floats
        if [[ "$key" == *"CREDITS"* ]]; then
            echo "#define $key ${value}.0f"
        else
            echo "#define $key $value"
        fi
    done < "$CONFIG_FILE"

    echo ""
    echo "#endif // CONFIG_H"
} > "$OUTPUT_FILE"

echo "Generated: $OUTPUT_FILE"
