# Issue 1-001: Install Boost Library

## Current Behavior

The `games/city-of-chat` project requires the Boost C++ libraries. Currently, a large archive is stored in the repository:

- `games/city-of-chat/downloads/boost_1_84_0.tar.gz` (133 MB)

### Current Issues
- Large archive file exceeds GitHub's 100MB limit
- Boost version is frozen as a binary blob
- No automated build/install process documented
- Repository bloated with downloadable content

## Intended Behavior

A self-contained install script in the project's `libs/` directory that:

1. **Downloads Boost**: Fetches the specified Boost version from official sources
2. **Extracts and builds**: Configures Boost with required components
3. **Installs locally**: Places headers/libraries in project-local directory
4. **Validates installation**: Confirms Boost is usable

## Suggested Implementation Steps

### 1. Create libs directory structure
```bash
mkdir -p games/city-of-chat/libs
```

### 2. Create install-boost.sh
```bash
#!/bin/bash
# Install Boost C++ Libraries for city-of-chat project
# Downloads, builds, and installs Boost locally

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BOOST_VERSION="${BOOST_VERSION:-1.84.0}"
BOOST_VERSION_UNDERSCORE="${BOOST_VERSION//./_}"

# -- {{{ show_help
show_help() {
    echo "Usage: install-boost.sh [OPTIONS]"
    echo ""
    echo "Install Boost C++ libraries for city-of-chat."
    echo ""
    echo "Options:"
    echo "  --version VERSION  Specify Boost version (default: 1.84.0)"
    echo "  --components LIST  Comma-separated list of components to build"
    echo "  --help             Show this help message"
}
# }}}

# -- {{{ download_boost
download_boost() {
    local archive="boost_${BOOST_VERSION_UNDERSCORE}.tar.gz"
    local url="https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/${archive}"

    echo "Downloading Boost ${BOOST_VERSION}..."

    if [[ -f "$DIR/$archive" ]]; then
        echo "Archive already exists, skipping download"
    else
        curl -L -o "$DIR/$archive" "$url" || {
            echo "ERROR: Failed to download Boost"
            exit 1
        }
    fi

    echo "Extracting..."
    tar -xzf "$DIR/$archive" -C "$DIR"
}
# }}}

# -- {{{ build_boost
build_boost() {
    local boost_dir="$DIR/boost_${BOOST_VERSION_UNDERSCORE}"

    echo "Building Boost..."
    cd "$boost_dir" || exit 1

    # Bootstrap
    ./bootstrap.sh --prefix="$DIR/boost-install"

    # Build (header-only by default, or specify components)
    if [[ -n "${BOOST_COMPONENTS:-}" ]]; then
        ./b2 --with-${BOOST_COMPONENTS//,/ --with-} install
    else
        # Header-only install
        ./b2 headers
        mkdir -p "$DIR/boost-install/include"
        cp -r boost "$DIR/boost-install/include/"
    fi

    echo "Boost installed to: $DIR/boost-install"
}
# }}}

# -- {{{ validate_installation
validate_installation() {
    echo ""
    echo "Validating installation..."

    if [[ -d "$DIR/boost-install/include/boost" ]]; then
        echo "✓ Boost headers found"
        local version_file="$DIR/boost-install/include/boost/version.hpp"
        if [[ -f "$version_file" ]]; then
            grep -o 'BOOST_LIB_VERSION "[^"]*"' "$version_file" | head -1
        fi
    else
        echo "✗ Boost headers not found"
        exit 1
    fi
}
# }}}

# -- {{{ main
main() {
    case "${1:-}" in
        --help)
            show_help
            ;;
        --version)
            BOOST_VERSION="${2:-1.84.0}"
            BOOST_VERSION_UNDERSCORE="${BOOST_VERSION//./_}"
            download_boost
            build_boost
            validate_installation
            ;;
        --components)
            BOOST_COMPONENTS="${2:-}"
            download_boost
            build_boost
            validate_installation
            ;;
        *)
            download_boost
            build_boost
            validate_installation
            ;;
    esac
}
# }}}

main "$@"
```

### 3. Update project CMakeLists.txt
Add hints for finding the locally installed Boost:
```cmake
set(BOOST_ROOT "${CMAKE_SOURCE_DIR}/libs/boost-install")
find_package(Boost REQUIRED)
```

## Related Documents
- Project `.gitignore` - downloads/ pattern should be added
- Repository `.gitignore` - downloads/ and *.tar.gz patterns already present

## Tools Required
- curl or wget (for downloading)
- tar (for extraction)
- C++ compiler (g++/clang++)
- Build tools (make)

## Metadata
- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: None
- **Impact**: Reduces repository size by ~133 MB, enables version flexibility

## Success Criteria
- `libs/install-boost.sh` exists and is executable
- Running the script downloads and installs Boost
- Boost headers are accessible in `libs/boost-install/include/`
- downloads/ directory is excluded from git via .gitignore
- Project builds successfully with locally installed Boost
