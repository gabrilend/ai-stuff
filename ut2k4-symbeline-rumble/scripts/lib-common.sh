#!/usr/bin/env bash
# lib-common.sh
#
# Common library functions shared across all build and automation scripts.
# Source this file at the beginning of scripts to get standard functionality.

# -- {{{ load_config
# Loads and parses the config.sh file, setting variables
# from KEY=value pairs while supporting ${PROJECT_DIR} expansion
load_config() {
    local config_file="$1"
    local config_local="${config_file%.sh}.local"

    if [ ! -f "$config_file" ]; then
        echo "ERROR: Configuration file not found: $config_file" >&2
        return 1
    fi

    # Parse the main config file
    while IFS='=' read -r key value; do
        # Skip comments and blank lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # Expand ${PROJECT_DIR} in values
        value="${value//\$\{PROJECT_DIR\}/$PROJECT_DIR}"

        # Set the variable
        case "$key" in
            UT2004_DIR)      UT2004_DIR="$value" ;;
            PACKAGE_NAME)    PACKAGE_NAME="$value" ;;
            MUTATOR_CLASS)   MUTATOR_CLASS="$value" ;;
            VERSION)         VERSION="$value" ;;
        esac
    done < "$config_file"

    # Load local overrides if they exist (git-ignored)
    if [ -f "$config_local" ]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue

            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            value="${value//\$\{PROJECT_DIR\}/$PROJECT_DIR}"

            case "$key" in
                UT2004_DIR)      UT2004_DIR="$value" ;;
                PACKAGE_NAME)    PACKAGE_NAME="$value" ;;
                MUTATOR_CLASS)   MUTATOR_CLASS="$value" ;;
                VERSION)         VERSION="$value" ;;
            esac
        done < "$config_local"
    fi

    # Export for child processes
    export PROJECT_DIR
    export UT2004_DIR
    export PACKAGE_NAME
    export MUTATOR_CLASS
    export VERSION

    return 0
}
# }}}

# -- {{{ print_header
# Prints a formatted section header
print_header() {
    echo "" >&2
    echo "==========================================" >&2
    echo "$1" >&2
    echo "==========================================" >&2
}
# }}}

# -- {{{ print_info
# Prints an info message to stderr
print_info() {
    echo "[INFO] $*" >&2
}
# }}}

# -- {{{ print_warning
# Prints a warning message to stderr
print_warning() {
    echo "[WARNING] $*" >&2
}
# }}}

# -- {{{ print_error
# Prints an error message to stderr
print_error() {
    echo "[ERROR] $*" >&2
}
# }}}
