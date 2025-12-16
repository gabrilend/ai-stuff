# Issue 1-001: Install Emscripten SDK

## Current Behavior

The `games/gameboy-color-rpg` project requires the Emscripten SDK (emsdk) for WebAssembly compilation. Currently, the emsdk directory is committed to the repository, containing:

- `emsdk/node/22.16.0_64bit/bin/node` (116 MB)
- `emsdk/upstream/bin/clang-22` (134 MB)
- `emsdk/upstream/bin/lld` (~50+ MB)
- `emsdk/upstream/bin/clang-scan-deps` (~50+ MB)
- `emsdk/upstream/emscripten/node_modules/` (large)

### Current Issues
- Large binary files exceed GitHub's 100MB limit
- SDK version is hardcoded in the repository
- No standardized way to install dependencies
- Repository size is unnecessarily bloated (~500+ MB for emsdk alone)

## Intended Behavior

A self-contained install script in the project's `libs/` directory that:

1. **Downloads emsdk**: Clones the official Emscripten SDK repository
2. **Installs specified version**: Configures and activates the required SDK version
3. **Validates installation**: Confirms emcc/em++ are accessible
4. **Documents requirements**: Clear instructions for prerequisites

## Suggested Implementation Steps

### 1. Create libs directory structure
```bash
mkdir -p games/gameboy-color-rpg/libs
```

### 2. Create install-emsdk.sh
```bash
#!/bin/bash
# Install Emscripten SDK for gameboy-color-rpg project
# Downloads and configures emsdk for WebAssembly compilation

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
EMSDK_VERSION="${EMSDK_VERSION:-latest}"

# -- {{{ show_help
show_help() {
    echo "Usage: install-emsdk.sh [OPTIONS]"
    echo ""
    echo "Install Emscripten SDK for WebAssembly compilation."
    echo ""
    echo "Options:"
    echo "  --version VERSION  Specify emsdk version (default: latest)"
    echo "  --help             Show this help message"
}
# }}}

# -- {{{ install_emsdk
install_emsdk() {
    echo "Installing Emscripten SDK..."

    cd "$DIR" || exit 1

    if [[ -d "emsdk" ]]; then
        echo "emsdk directory exists, updating..."
        cd emsdk && git pull
    else
        echo "Cloning emsdk..."
        git clone https://github.com/emscripten-core/emsdk.git
        cd emsdk
    fi

    echo "Installing emsdk version: $EMSDK_VERSION"
    ./emsdk install "$EMSDK_VERSION"
    ./emsdk activate "$EMSDK_VERSION"

    echo ""
    echo "To use emsdk in your shell, run:"
    echo "  source $DIR/emsdk/emsdk_env.sh"
}
# }}}

# -- {{{ validate_installation
validate_installation() {
    echo ""
    echo "Validating installation..."

    source "$DIR/emsdk/emsdk_env.sh" 2>/dev/null

    if command -v emcc &>/dev/null; then
        echo "✓ emcc found: $(emcc --version | head -1)"
    else
        echo "✗ emcc not found in PATH"
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
            EMSDK_VERSION="${2:-latest}"
            install_emsdk
            validate_installation
            ;;
        *)
            install_emsdk
            validate_installation
            ;;
    esac
}
# }}}

main "$@"
```

### 3. Add README in libs directory
Document usage and prerequisites (Python 3, Git, etc.)

## Related Documents
- Project `.gitignore` - emsdk/ pattern should be added
- Repository `.gitignore` - emsdk/ pattern already present

## Tools Required
- Git (for cloning emsdk)
- Python 3.6+ (emsdk requirement)
- CMake (optional, for building projects)

## Metadata
- **Priority**: Medium
- **Complexity**: Low
- **Dependencies**: None
- **Impact**: Reduces repository size by ~500+ MB, enables clean cloning

## Success Criteria
- `libs/install-emsdk.sh` exists and is executable
- Running the script successfully installs emsdk
- `emcc --version` works after installation
- emsdk directory is excluded from git via .gitignore
- README documents prerequisites and usage
