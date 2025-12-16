# Issue 1-001: Setup Wine and .NET Framework

## Current Behavior

The `links-awakening` project appears to use Wine with .NET Framework for running Windows-based tools. Currently, a full Wine prefix with .NET is committed to the repository:

- `links-awakening/drive_c/` - Full Wine C: drive contents
- `links-awakening/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/` - .NET Framework files
- `links-awakening/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/SetupCache/Client/netfx_core.mzz` (174 MB)

### Current Issues
- Wine prefix contains large .NET runtime files (174+ MB)
- Platform-specific Wine configuration may not transfer correctly
- Registry and user-specific data in Wine prefix
- Repository bloated with system files

## Intended Behavior

A self-contained setup script in the project's `libs/` directory that:

1. **Creates Wine prefix**: Initializes a new Wine prefix for the project
2. **Installs .NET Framework**: Uses winetricks to install required .NET version
3. **Configures environment**: Sets up WINEPREFIX and related variables
4. **Validates installation**: Confirms .NET tools are accessible

## Suggested Implementation Steps

### 1. Create libs directory structure
```bash
mkdir -p links-awakening/libs
```

### 2. Create setup-wine-dotnet.sh
```bash
#!/bin/bash
# Setup Wine prefix with .NET Framework for links-awakening project
# Creates isolated Wine environment with required .NET components

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PROJECT_DIR="${DIR%/*}"
WINEPREFIX="${WINEPREFIX:-$PROJECT_DIR/wine-prefix}"
WINEARCH="${WINEARCH:-win64}"
DOTNET_VERSION="${DOTNET_VERSION:-dotnet48}"

# -- {{{ show_help
show_help() {
    echo "Usage: setup-wine-dotnet.sh [OPTIONS]"
    echo ""
    echo "Setup Wine prefix with .NET Framework."
    echo ""
    echo "Options:"
    echo "  --prefix PATH       Wine prefix path (default: ../wine-prefix)"
    echo "  --arch ARCH         Wine architecture: win32 or win64 (default: win64)"
    echo "  --dotnet VERSION    .NET version: dotnet40, dotnet45, dotnet48 (default: dotnet48)"
    echo "  --help              Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  WINEPREFIX  - Override prefix path"
    echo "  WINEARCH    - Override architecture"
}
# }}}

# -- {{{ check_dependencies
check_dependencies() {
    echo "Checking dependencies..."

    local missing=()

    if ! command -v wine &>/dev/null; then
        missing+=("wine")
    fi

    if ! command -v winetricks &>/dev/null; then
        missing+=("winetricks")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  Arch Linux: sudo pacman -S wine winetricks"
        echo "  Debian/Ubuntu: sudo apt install wine winetricks"
        echo "  Void Linux: sudo xbps-install wine winetricks"
        exit 1
    fi

    echo "✓ All dependencies found"
}
# }}}

# -- {{{ create_prefix
create_prefix() {
    echo ""
    echo "Creating Wine prefix at: $WINEPREFIX"
    echo "Architecture: $WINEARCH"

    export WINEPREFIX
    export WINEARCH

    if [[ -d "$WINEPREFIX" ]]; then
        echo "Wine prefix already exists."
        read -p "Recreate? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy] ]]; then
            rm -rf "$WINEPREFIX"
        else
            echo "Using existing prefix."
            return
        fi
    fi

    # Initialize prefix
    wineboot --init

    echo "Wine prefix created."
}
# }}}

# -- {{{ install_dotnet
install_dotnet() {
    echo ""
    echo "Installing .NET Framework ($DOTNET_VERSION)..."

    export WINEPREFIX

    winetricks -q "$DOTNET_VERSION" || {
        echo "ERROR: Failed to install $DOTNET_VERSION"
        echo ""
        echo "Try running manually:"
        echo "  WINEPREFIX=$WINEPREFIX winetricks $DOTNET_VERSION"
        exit 1
    }

    echo ".NET Framework installed."
}
# }}}

# -- {{{ validate_installation
validate_installation() {
    echo ""
    echo "Validating installation..."

    export WINEPREFIX

    local dotnet_dir="$WINEPREFIX/drive_c/windows/Microsoft.NET"

    if [[ -d "$dotnet_dir" ]]; then
        echo "✓ .NET Framework directory found"
        echo "  Installed frameworks:"
        ls -d "$dotnet_dir"/Framework*/* 2>/dev/null | while read -r dir; do
            echo "    - $(basename "$dir")"
        done
    else
        echo "✗ .NET Framework not found"
        exit 1
    fi
}
# }}}

# -- {{{ generate_env_script
generate_env_script() {
    local env_script="$DIR/wine-env.sh"

    cat > "$env_script" << EOF
# Source this file to configure Wine environment for links-awakening
# Usage: source libs/wine-env.sh

export WINEPREFIX="$WINEPREFIX"
export WINEARCH="$WINEARCH"

echo "Wine environment configured:"
echo "  WINEPREFIX=$WINEPREFIX"
echo "  WINEARCH=$WINEARCH"
EOF

    chmod +x "$env_script"
    echo ""
    echo "Environment script created: $env_script"
    echo "  source $env_script"
}
# }}}

# -- {{{ main
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                show_help
                exit 0
                ;;
            --prefix)
                WINEPREFIX="$2"
                shift 2
                ;;
            --arch)
                WINEARCH="$2"
                shift 2
                ;;
            --dotnet)
                DOTNET_VERSION="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    check_dependencies
    create_prefix
    install_dotnet
    validate_installation
    generate_env_script

    echo ""
    echo "Setup complete!"
    echo "Wine prefix: $WINEPREFIX"
}
# }}}

main "$@"
```

### 3. Update .gitignore
Ensure Wine prefixes are excluded:
```
wine-prefix/
drive_c/
.wine/
```

## Related Documents
- Project `.gitignore` - Wine prefix should be added
- Repository `.gitignore` - drive_c/ pattern already present

## Tools Required
- Wine (wine-stable or wine-staging)
- Winetricks (for .NET installation)
- Internet connection (for downloading .NET installer)

## Metadata
- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: None
- **Impact**: Reduces repository size by ~174+ MB, ensures reproducible setup

## Success Criteria
- `libs/setup-wine-dotnet.sh` exists and is executable
- Script creates functional Wine prefix
- .NET Framework is properly installed via winetricks
- `wine-env.sh` helper script is generated
- Wine prefix directories excluded from git via .gitignore
- Project tools work within the Wine environment
