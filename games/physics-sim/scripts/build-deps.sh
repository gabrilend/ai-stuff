#!/bin/bash
# scripts/build-deps.sh
# Downloads and builds project dependencies (raylib) locally in the libs/ directory.
# This enables reproducible builds independent of system package installations.
#
# Usage:
#   ./scripts/build-deps.sh              # Build deps using default directory
#   ./scripts/build-deps.sh /custom/dir  # Build deps at custom directory
#   ./scripts/build-deps.sh --clean      # Remove and rebuild dependencies

# Hard-coded project directory
DIR="/mnt/mtwo/programming/ai-stuff/games/physics-sim"

# Raylib version tag to checkout (empty string means latest master)
RAYLIB_VERSION="5.0"

# cJSON version tag to checkout (empty string means latest master)
CJSON_VERSION="v1.7.18"

# {{{ parse_arguments
parse_arguments() {
    CLEAN_BUILD=0

    for arg in "$@"; do
        case "$arg" in
            --clean)
                CLEAN_BUILD=1
                ;;
            --help|-h)
                echo "Usage: build-deps.sh [OPTIONS] [DIRECTORY]"
                echo ""
                echo "Options:"
                echo "  --clean    Remove existing dependencies and rebuild"
                echo "  --help     Show this help message"
                echo ""
                echo "Arguments:"
                echo "  DIRECTORY  Project directory (default: $DIR)"
                exit 0
                ;;
            *)
                # Assume it's a directory path
                DIR="$arg"
                ;;
        esac
    done
}
# }}}

# {{{ check_requirements
check_requirements() {
    echo "Checking build requirements..."

    local missing=0

    if ! command -v git &> /dev/null; then
        echo "ERROR: git is not installed"
        missing=1
    fi

    if ! command -v make &> /dev/null; then
        echo "ERROR: make is not installed"
        missing=1
    fi

    if ! command -v gcc &> /dev/null; then
        echo "ERROR: gcc is not installed"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo "Please install missing dependencies and try again."
        exit 1
    fi

    echo "All build requirements satisfied."
}
# }}}

# {{{ setup_directories
setup_directories() {
    local libs_dir="${DIR}/libs"

    if [ ! -d "$libs_dir" ]; then
        echo "Creating libs directory: $libs_dir"
        mkdir -p "$libs_dir"
    fi
}
# }}}

# {{{ clean_raylib
clean_raylib() {
    local raylib_dir="${DIR}/libs/raylib"

    if [ -d "$raylib_dir" ]; then
        echo "Removing existing raylib directory..."
        rm -rf "$raylib_dir"
    fi
}
# }}}

# {{{ download_raylib
download_raylib() {
    local raylib_dir="${DIR}/libs/raylib"

    if [ -d "$raylib_dir" ]; then
        echo "Raylib already exists at: $raylib_dir"
        echo "Use --clean to force a fresh download."
        return 0
    fi

    echo "Cloning raylib repository..."
    git clone --depth 1 https://github.com/raysan5/raylib.git "$raylib_dir"

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to clone raylib repository"
        exit 1
    fi

    # Checkout specific version if set
    if [ -n "$RAYLIB_VERSION" ]; then
        echo "Checking out raylib version: $RAYLIB_VERSION"
        cd "$raylib_dir"
        git fetch --tags --depth 1
        git checkout "$RAYLIB_VERSION" 2>/dev/null || {
            echo "WARNING: Version $RAYLIB_VERSION not found, using latest"
        }
        cd "${DIR}"
    fi

    echo "Raylib downloaded successfully."
}
# }}}

# {{{ build_raylib
build_raylib() {
    local raylib_src="${DIR}/libs/raylib/src"

    if [ ! -d "$raylib_src" ]; then
        echo "ERROR: Raylib source directory not found: $raylib_src"
        exit 1
    fi

    echo "Building raylib..."
    echo "This may take a few minutes..."

    cd "$raylib_src"

    # Build raylib as a static library
    # PLATFORM_DESKTOP enables X11/OpenGL on Linux
    make PLATFORM=PLATFORM_DESKTOP

    if [ $? -ne 0 ]; then
        echo "ERROR: Raylib build failed"
        exit 1
    fi

    cd "${DIR}"

    echo "Raylib built successfully."
}
# }}}

# {{{ clean_cjson
clean_cjson() {
    local cjson_dir="${DIR}/libs/cjson"

    if [ -d "$cjson_dir" ]; then
        echo "Removing existing cjson directory..."
        rm -rf "$cjson_dir"
    fi
}
# }}}

# {{{ download_cjson
# cJSON is a single-translation-unit library (cJSON.c + cJSON.h). The project's
# Makefile compiles cJSON.c directly, so we only need the source tree in place.
# Pinning a tag avoids surprise breakage from upstream master.
download_cjson() {
    local cjson_dir="${DIR}/libs/cjson"

    if [ -d "$cjson_dir" ]; then
        echo "cJSON already exists at: $cjson_dir"
        echo "Use --clean to force a fresh download."
        return 0
    fi

    echo "Cloning cJSON repository..."
    git clone --depth 1 https://github.com/DaveGamble/cJSON.git "$cjson_dir"

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to clone cJSON repository"
        exit 1
    fi

    if [ -n "$CJSON_VERSION" ]; then
        echo "Checking out cJSON version: $CJSON_VERSION"
        cd "$cjson_dir"
        git fetch --tags --depth 1
        git checkout "$CJSON_VERSION" 2>/dev/null || {
            echo "WARNING: Version $CJSON_VERSION not found, using latest"
        }
        cd "${DIR}"
    fi

    echo "cJSON downloaded successfully."
}
# }}}

# {{{ verify_build
verify_build() {
    local raylib_lib="${DIR}/libs/raylib/src/libraylib.a"
    local raylib_header="${DIR}/libs/raylib/src/raylib.h"
    local cjson_header="${DIR}/libs/cjson/cJSON.h"
    local cjson_source="${DIR}/libs/cjson/cJSON.c"

    echo "Verifying build..."

    if [ ! -f "$raylib_lib" ]; then
        echo "ERROR: libraylib.a not found at: $raylib_lib"
        exit 1
    fi

    if [ ! -f "$raylib_header" ]; then
        echo "ERROR: raylib.h not found at: $raylib_header"
        exit 1
    fi

    if [ ! -f "$cjson_header" ]; then
        echo "ERROR: cJSON.h not found at: $cjson_header"
        exit 1
    fi

    if [ ! -f "$cjson_source" ]; then
        echo "ERROR: cJSON.c not found at: $cjson_source"
        exit 1
    fi

    echo "Build verification successful."
    echo ""
    echo "Raylib library: $raylib_lib"
    echo "Raylib headers: ${DIR}/libs/raylib/src/"
    echo "cJSON sources: ${DIR}/libs/cjson/"
    echo ""
    echo "To use local raylib, update your Makefile:"
    echo "  CFLAGS += -I\$(DIR)/libs/raylib/src -I\$(DIR)/libs/cjson"
    echo "  LDFLAGS = \$(DIR)/libs/raylib/src/libraylib.a -lm -lpthread -lGL -ldl -lrt -lX11"
}
# }}}

# {{{ main
main() {
    echo "========================================"
    echo "Physics-Sim Dependency Builder"
    echo "========================================"
    echo ""

    parse_arguments "$@"

    echo "Project directory: $DIR"
    echo ""

    check_requirements
    setup_directories

    if [ $CLEAN_BUILD -eq 1 ]; then
        clean_raylib
        clean_cjson
    fi

    download_raylib
    build_raylib
    download_cjson
    verify_build

    echo ""
    echo "========================================"
    echo "Dependencies built successfully!"
    echo "========================================"
}
# }}}

main "$@"
