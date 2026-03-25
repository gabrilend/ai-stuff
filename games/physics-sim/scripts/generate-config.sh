#!/bin/bash
# {{{ scripts/generate-config.sh
# Generates src/000-config.h from config
# This script parses the config file and creates a C header with #define statements
# Run before compilation to update compile-time constants
# Issue 113: Added auto-generation, validation, and missing key detection

# Hard-coded project directory (can be overridden via argument)
DIR="/mnt/mtwo/programming/ai-stuff/games/physics-sim"

# Allow directory override via argument
if [ -n "$1" ]; then
    DIR="$1"
fi

CONFIG_FILE="${DIR}/config"
OUTPUT_FILE="${DIR}/src/000-config.h"

# Required keys and their default values
# Issue 113: Define all required configuration keys
declare -A REQUIRED_KEYS=(
    ["MAX_BALLS"]="1024"
    ["MAX_PARTICLES"]="1024"
    ["MAX_SPAWN_CREDITS"]="30"
    ["TRAJECTORY_HISTORY_FRAMES"]="4"
    ["EDITOR_ADVANCED_MODE"]="0"
    ["BACKGROUND_COLOR"]="0"
)

# {{{ generate_default_config
# Creates a new config file with the polyglot header and all required keys
generate_default_config() {
    cat > "$CONFIG_FILE" << 'HEADER'
#!/bin/bash
# config - Compile-time configuration for physics-sim
# Run this file to edit: ./config
# Parsed by scripts/generate-config.sh → src/000-config.h
exec ${EDITOR:-${VISUAL:-vi}} "$0"
exit
# --- Configuration below ---

# System capacities
HEADER
    echo "MAX_BALLS=${REQUIRED_KEYS[MAX_BALLS]}" >> "$CONFIG_FILE"
    echo "MAX_PARTICLES=${REQUIRED_KEYS[MAX_PARTICLES]}" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "# Spawning limits" >> "$CONFIG_FILE"
    echo "MAX_SPAWN_CREDITS=${REQUIRED_KEYS[MAX_SPAWN_CREDITS]}" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "# Trajectory history (issue 222)" >> "$CONFIG_FILE"
    echo "TRAJECTORY_HISTORY_FRAMES=${REQUIRED_KEYS[TRAJECTORY_HISTORY_FRAMES]}" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "# Editor settings" >> "$CONFIG_FILE"
    echo "# 0 = material presets (standard mode), 1 = raw RGB editing (advanced mode)" >> "$CONFIG_FILE"
    echo "EDITOR_ADVANCED_MODE=${REQUIRED_KEYS[EDITOR_ADVANCED_MODE]}" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    echo "# Background color (issue 413)" >> "$CONFIG_FILE"
    echo "# 0=slate (default), 1=black, 2=tan, 3=felt, 4=navy, 5=plum, 6=charcoal, 7=mahogany" >> "$CONFIG_FILE"
    echo "BACKGROUND_COLOR=${REQUIRED_KEYS[BACKGROUND_COLOR]}" >> "$CONFIG_FILE"

    chmod +x "$CONFIG_FILE"
}
# }}}

# {{{ validate_and_append_missing_keys
# Checks each required key exists in config, appends missing keys with defaults
# Non-destructive: preserves user's existing values
validate_and_append_missing_keys() {
    local missing_keys=()

    for key in "${!REQUIRED_KEYS[@]}"; do
        if ! grep -q "^${key}=" "$CONFIG_FILE"; then
            missing_keys+=("$key")
        fi
    done

    if [ ${#missing_keys[@]} -gt 0 ]; then
        echo "" >> "$CONFIG_FILE"
        echo "# Auto-added missing keys (issue 113)" >> "$CONFIG_FILE"
        for key in "${missing_keys[@]}"; do
            echo "${key}=${REQUIRED_KEYS[$key]}" >> "$CONFIG_FILE"
            echo "Added missing key: ${key}=${REQUIRED_KEYS[$key]}"
        done
    fi
}
# }}}

# {{{ validate_integer_values
# Validates that all config values are valid integers
# Returns 1 on validation error
validate_integer_values() {
    local errors=0

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments, blank lines, and bash script lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^exec ]] && continue
        [[ "$line" =~ ^exit ]] && continue
        [[ "$line" =~ ^#!/ ]] && continue

        # Parse KEY=VALUE
        if [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            value="${value// /}"  # Trim whitespace

            # Validate value is a non-negative integer
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                echo "ERROR: Invalid value for $key: '$value' (expected non-negative integer)"
                errors=1
            fi
        fi
    done < "$CONFIG_FILE"

    return $errors
}
# }}}

# Generate default config if missing
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found, generating default: $CONFIG_FILE"
    generate_default_config
fi

# Validate and append missing keys (non-destructive)
validate_and_append_missing_keys

# Validate all values are integers
if ! validate_integer_values; then
    echo "Config validation failed. Please fix the errors above."
    exit 1
fi

# Generate header file
{
    echo "// src/000-config.h"
    echo "// Auto-generated from config - do not edit manually"
    echo "// Regenerate with: scripts/generate-config.sh"
    echo "// Edit config with: ./config"
    echo ""
    echo "#ifndef CONFIG_H"
    echo "#define CONFIG_H"
    echo ""

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments, blank lines, and bash script lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^exec ]] && continue
        [[ "$line" =~ ^exit ]] && continue
        [[ "$line" =~ ^#!/ ]] && continue

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
# }}}
