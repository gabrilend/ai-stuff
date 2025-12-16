# Issue 1-001: Install GBA ARM Toolchain

## Current Behavior

The `console-demakes` project requires an ARM GCC toolchain for Game Boy Advance development. Currently, a toolchain archive is stored in the repository:

- `console-demakes/tools/gba-toolchain/gcc-arm.tar.bz2` (150 MB)

### Current Issues
- Large archive file exceeds GitHub's 100MB limit
- Toolchain version is frozen as a binary blob
- Platform-specific (may not work on all systems)
- No automated installation process

## Intended Behavior

A self-contained install script in the project's `libs/` directory that:

1. **Downloads ARM toolchain**: Fetches appropriate ARM GCC toolchain
2. **Extracts to local directory**: Sets up toolchain in project directory
3. **Configures environment**: Sets up PATH and tool variables
4. **Validates installation**: Confirms arm-none-eabi-gcc is accessible

## Suggested Implementation Steps

### 1. Create libs directory structure
```bash
mkdir -p console-demakes/libs
```

### 2. Create install-gba-toolchain.sh
```bash
#!/bin/bash
# Install ARM GCC Toolchain for GBA Development
# Downloads and configures devkitARM or ARM GNU toolchain

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
TOOLCHAIN_TYPE="${TOOLCHAIN_TYPE:-devkitarm}"

# -- {{{ show_help
show_help() {
    echo "Usage: install-gba-toolchain.sh [OPTIONS]"
    echo ""
    echo "Install ARM GCC toolchain for GBA development."
    echo ""
    echo "Options:"
    echo "  --type TYPE   Toolchain type: devkitarm or arm-gnu (default: devkitarm)"
    echo "  --help        Show this help message"
    echo ""
    echo "Toolchain types:"
    echo "  devkitarm  - devkitPro's devkitARM (recommended for GBA)"
    echo "  arm-gnu    - ARM GNU Toolchain from ARM Developer"
}
# }}}

# -- {{{ install_devkitarm
install_devkitarm() {
    echo "Installing devkitARM via devkitPro pacman..."

    # Check if devkitPro pacman is available
    if command -v dkp-pacman &>/dev/null; then
        echo "devkitPro pacman found, installing devkitARM..."
        dkp-pacman -S gba-dev
    else
        echo "devkitPro pacman not found."
        echo ""
        echo "To install devkitPro, follow instructions at:"
        echo "  https://devkitpro.org/wiki/Getting_Started"
        echo ""
        echo "Quick install (Arch Linux):"
        echo "  Follow AUR: devkitpro-pacman"
        echo ""
        echo "Quick install (Debian/Ubuntu):"
        echo "  wget https://apt.devkitpro.org/install-devkitpro-pacman"
        echo "  chmod +x install-devkitpro-pacman"
        echo "  sudo ./install-devkitpro-pacman"
        echo "  sudo dkp-pacman -S gba-dev"
        exit 1
    fi
}
# }}}

# -- {{{ install_arm_gnu
install_arm_gnu() {
    echo "Installing ARM GNU Toolchain..."

    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    local version="13.2.rel1"
    local archive_name="arm-gnu-toolchain-${version}-${arch}-arm-none-eabi"
    local url="https://developer.arm.com/-/media/Files/downloads/gnu/${version}/binrel/${archive_name}.tar.xz"

    echo "Downloading ARM GNU Toolchain ${version}..."

    mkdir -p "$DIR/arm-gnu-toolchain"
    cd "$DIR/arm-gnu-toolchain" || exit 1

    if [[ ! -f "${archive_name}.tar.xz" ]]; then
        curl -L -o "${archive_name}.tar.xz" "$url" || {
            echo "ERROR: Failed to download toolchain"
            exit 1
        }
    fi

    echo "Extracting..."
    tar -xf "${archive_name}.tar.xz"

    echo ""
    echo "Add to PATH:"
    echo "  export PATH=\"$DIR/arm-gnu-toolchain/${archive_name}/bin:\$PATH\""
}
# }}}

# -- {{{ validate_installation
validate_installation() {
    echo ""
    echo "Validating installation..."

    if command -v arm-none-eabi-gcc &>/dev/null; then
        echo "✓ arm-none-eabi-gcc found: $(arm-none-eabi-gcc --version | head -1)"
    else
        echo "✗ arm-none-eabi-gcc not found in PATH"
        echo ""
        echo "You may need to add the toolchain to your PATH or source environment."
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
        --type)
            TOOLCHAIN_TYPE="${2:-devkitarm}"
            case "$TOOLCHAIN_TYPE" in
                devkitarm)
                    install_devkitarm
                    ;;
                arm-gnu)
                    install_arm_gnu
                    ;;
                *)
                    echo "Unknown toolchain type: $TOOLCHAIN_TYPE"
                    show_help
                    exit 1
                    ;;
            esac
            validate_installation
            ;;
        *)
            install_devkitarm
            validate_installation
            ;;
    esac
}
# }}}

main "$@"
```

## Related Documents
- Project `.gitignore` - toolchain archives should be added
- Repository `.gitignore` - gba-toolchain/*.tar.bz2 pattern already present

## Tools Required
- curl or wget (for downloading)
- tar with xz support (for extraction)
- devkitPro pacman (optional, for devkitARM method)

## Metadata
- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: None
- **Impact**: Reduces repository size by ~150 MB, provides platform flexibility

## Success Criteria
- `libs/install-gba-toolchain.sh` exists and is executable
- Script provides clear instructions for installing devkitARM
- Alternative ARM GNU toolchain option available
- `arm-none-eabi-gcc --version` works after installation
- Toolchain archives excluded from git via .gitignore
