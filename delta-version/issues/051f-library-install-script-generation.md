# Issue 051f: Library Install Script Generation

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: Medium
**Created**: 2026-02-12
**Parent**: Issue 051 (Git Repository Documentation Generator)
**Dependencies**: Issue 051a

---

## Current Behavior

No automated method exists to generate dependency installation scripts from project analysis. Developers must manually:

1. Read through import/require statements
2. Identify external dependencies
3. Determine package managers (apt, npm, luarocks, pip, etc.)
4. Write installation scripts by hand
5. Test on multiple platforms

---

## Intended Behavior

Create a module that:

1. **Scans project files** for import/require statements
2. **Identifies external dependencies** vs local modules
3. **Detects package managers** appropriate for each dependency
4. **Generates install scripts** that are idempotent and cross-platform
5. **Creates version pinning** where possible

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  Install Script Generation                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────┐                      │
│  │ Input: Project files                 │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Dependency Detection:                │                      │
│  │                                       │                      │
│  │  ┌─────────────────────────────────┐ │                      │
│  │  │ Lua:                            │ │                      │
│  │  │   require("module")             │ │                      │
│  │  │   local m = require("m")        │ │                      │
│  │  └─────────────────────────────────┘ │                      │
│  │                                       │                      │
│  │  ┌─────────────────────────────────┐ │                      │
│  │  │ Python:                         │ │                      │
│  │  │   import module                 │ │                      │
│  │  │   from module import x          │ │                      │
│  │  └─────────────────────────────────┘ │                      │
│  │                                       │                      │
│  │  ┌─────────────────────────────────┐ │                      │
│  │  │ JavaScript:                     │ │                      │
│  │  │   require('module')             │ │                      │
│  │  │   import x from 'module'        │ │                      │
│  │  └─────────────────────────────────┘ │                      │
│  │                                       │                      │
│  │  ┌─────────────────────────────────┐ │                      │
│  │  │ Bash:                           │ │                      │
│  │  │   source script.sh              │ │                      │
│  │  │   command --version             │ │                      │
│  │  └─────────────────────────────────┘ │                      │
│  │                                       │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Local vs External Classification:    │                      │
│  │ - Check if module exists locally     │                      │
│  │ - Check against known stdlib         │                      │
│  │ - Identify package manager           │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Script Generation:                   │                      │
│  │ - Group by package manager           │                      │
│  │ - Add version constraints            │                      │
│  │ - Include platform detection         │                      │
│  │ - Make idempotent                    │                      │
│  └───────────────┬──────────────────────┘                      │
│                  │                                              │
│  ┌───────────────▼──────────────────────┐                      │
│  │ Output: scripts/install-deps.sh      │                      │
│  └──────────────────────────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Dependency Detection

```bash
# -- {{{ detect_lua_dependencies
# Extracts Lua require statements
detect_lua_dependencies() {
    local project_dir="$1"

    cd "$project_dir" || return 1

    # Find all require statements
    grep -rh "require[[:space:]]*(['\"]" --include="*.lua" . 2>/dev/null | \
        grep -oE "require[[:space:]]*\(['\"][^'\"]+['\"]" | \
        sed "s/require[[:space:]]*(['\"]//;s/['\"].*//" | \
        sort -u
}
# }}}

# -- {{{ detect_python_dependencies
# Extracts Python import statements
detect_python_dependencies() {
    local project_dir="$1"

    cd "$project_dir" || return 1

    {
        # import statements
        grep -rh "^import " --include="*.py" . 2>/dev/null | \
            sed 's/^import //' | cut -d'.' -f1 | cut -d' ' -f1

        # from X import statements
        grep -rh "^from " --include="*.py" . 2>/dev/null | \
            sed 's/^from //' | cut -d' ' -f1 | cut -d'.' -f1
    } | sort -u
}
# }}}

# -- {{{ detect_js_dependencies
# Extracts JavaScript/Node dependencies
detect_js_dependencies() {
    local project_dir="$1"

    cd "$project_dir" || return 1

    # Check package.json first
    if [[ -f package.json ]]; then
        jq -r '.dependencies // {} | keys[]' package.json 2>/dev/null
        jq -r '.devDependencies // {} | keys[]' package.json 2>/dev/null
    fi

    # Also scan for require/import
    {
        grep -rh "require(['\"]" --include="*.js" . 2>/dev/null | \
            grep -oE "require\(['\"][^'\"]+['\"]" | \
            sed "s/require(['\"]//;s/['\"].*//"

        grep -rh "from ['\"]" --include="*.js" --include="*.ts" . 2>/dev/null | \
            grep -oE "from ['\"][^'\"]+['\"]" | \
            sed "s/from ['\"]//;s/['\"].*//"
    } | grep -v '^\.' | grep -v '^/' | sort -u
}
# }}}

# -- {{{ detect_bash_dependencies
# Extracts bash command dependencies
detect_bash_dependencies() {
    local project_dir="$1"

    cd "$project_dir" || return 1

    # Look for commands with version checks or common patterns
    grep -rh "command -v\|which\|--version" --include="*.sh" . 2>/dev/null | \
        grep -oE "(command -v|which) [a-z0-9_-]+" | \
        sed 's/command -v //;s/which //' | \
        sort -u
}
# }}}
```

### 2. Classify Dependencies

```bash
# -- {{{ Lua Standard Library
LUA_STDLIB="string table math io os debug coroutine package utf8"
# }}}

# -- {{{ Python Standard Library (partial)
PYTHON_STDLIB="os sys re json datetime time collections itertools functools pathlib typing argparse logging subprocess threading multiprocessing socket http urllib email xml html csv sqlite3 hashlib hmac secrets random math statistics copy pprint"
# }}}

# -- {{{ classify_lua_dependency
# Determines if a Lua module is local, stdlib, or external
classify_lua_dependency() {
    local module="$1"
    local project_dir="$2"

    # Check if in stdlib
    if echo "$LUA_STDLIB" | grep -qw "$module"; then
        echo "stdlib"
        return
    fi

    # Check if local file exists
    local module_path="${module//\./\/}"
    if [[ -f "$project_dir/$module_path.lua" ]] || \
       [[ -f "$project_dir/$module_path/init.lua" ]] || \
       [[ -f "$project_dir/libs/$module_path.lua" ]]; then
        echo "local"
        return
    fi

    # Otherwise, external
    echo "external"
}
# }}}

# -- {{{ classify_python_dependency
classify_python_dependency() {
    local module="$1"
    local project_dir="$2"

    # Check if in stdlib
    if echo "$PYTHON_STDLIB" | grep -qw "$module"; then
        echo "stdlib"
        return
    fi

    # Check if local file exists
    if [[ -f "$project_dir/$module.py" ]] || \
       [[ -d "$project_dir/$module" && -f "$project_dir/$module/__init__.py" ]]; then
        echo "local"
        return
    fi

    echo "external"
}
# }}}
```

### 3. Package Manager Mapping

```bash
# -- {{{ Known Luarocks packages
declare -A LUAROCKS_PACKAGES=(
    ["lfs"]="luafilesystem"
    ["socket"]="luasocket"
    ["ssl"]="luasec"
    ["cjson"]="lua-cjson"
    ["lpeg"]="lpeg"
    ["ltn12"]="luasocket"
    ["mime"]="luasocket"
    ["argparse"]="argparse"
    ["inspect"]="inspect"
    ["penlight"]="penlight"
    ["pl"]="penlight"
)
# }}}

# -- {{{ map_lua_to_luarocks
map_lua_to_luarocks() {
    local module="$1"

    if [[ -n "${LUAROCKS_PACKAGES[$module]:-}" ]]; then
        echo "${LUAROCKS_PACKAGES[$module]}"
    else
        # Guess: module name might be the rock name
        echo "$module"
    fi
}
# }}}

# -- {{{ Known apt packages for commands
declare -A APT_PACKAGES=(
    ["git"]="git"
    ["curl"]="curl"
    ["wget"]="wget"
    ["jq"]="jq"
    ["lua"]="lua5.3"
    ["luajit"]="luajit"
    ["python3"]="python3"
    ["node"]="nodejs"
    ["npm"]="npm"
    ["ffmpeg"]="ffmpeg"
    ["imagemagick"]="imagemagick"
    ["sqlite3"]="sqlite3"
)
# }}}
```

### 4. Generate Install Script

```bash
# -- {{{ generate_install_script
# Generates the main install-deps.sh script
generate_install_script() {
    local project_dir="$1"
    local output_file="$2"

    # Collect all dependencies
    local lua_deps python_deps js_deps bash_deps

    lua_deps=$(detect_lua_dependencies "$project_dir")
    python_deps=$(detect_python_dependencies "$project_dir")
    js_deps=$(detect_js_dependencies "$project_dir")
    bash_deps=$(detect_bash_dependencies "$project_dir")

    # Classify and filter
    local lua_external=() python_external=() js_external=() apt_deps=()

    for dep in $lua_deps; do
        local class
        class=$(classify_lua_dependency "$dep" "$project_dir")
        if [[ "$class" == "external" ]]; then
            lua_external+=("$(map_lua_to_luarocks "$dep")")
        fi
    done

    for dep in $python_deps; do
        local class
        class=$(classify_python_dependency "$dep" "$project_dir")
        if [[ "$class" == "external" ]]; then
            python_external+=("$dep")
        fi
    done

    for dep in $bash_deps; do
        if [[ -n "${APT_PACKAGES[$dep]:-}" ]]; then
            apt_deps+=("${APT_PACKAGES[$dep]}")
        fi
    done

    # Generate script
    cat << 'HEADER' > "$output_file"
#!/bin/bash
# =============================================================================
# Dependency Installation Script
# Auto-generated by Issue 051 (Git Documentation Generator)
#
# This script installs all external dependencies required by the project.
# It is idempotent - safe to run multiple times.
#
# Usage: ./install-deps.sh [--dry-run] [--skip-optional]
# =============================================================================

set -euo pipefail

DRY_RUN=${DRY_RUN:-false}
SKIP_OPTIONAL=${SKIP_OPTIONAL:-false}
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
[[ "${1:-}" == "--skip-optional" ]] && SKIP_OPTIONAL=true

# -- {{{ Helper Functions
log() { echo "[install-deps] $*"; }
warn() { echo "[install-deps] WARNING: $*" >&2; }
error() { echo "[install-deps] ERROR: $*" >&2; exit 1; }

run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

command_exists() {
    command -v "$1" &>/dev/null
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}
# }}}

OS=$(detect_os)
log "Detected OS: $OS"
HEADER

    # Add apt section if needed
    if [[ ${#apt_deps[@]} -gt 0 ]]; then
        cat << EOF >> "$output_file"

# -- {{{ System Packages (apt)
install_apt_packages() {
    log "Installing system packages via apt..."

    local packages=(
$(printf '        "%s"\n' "${apt_deps[@]}" | sort -u)
    )

    case "\$OS" in
        ubuntu|debian)
            run sudo apt-get update
            run sudo apt-get install -y "\${packages[@]}"
            ;;
        macos)
            if command_exists brew; then
                run brew install "\${packages[@]}"
            else
                warn "Homebrew not found. Please install packages manually: \${packages[*]}"
            fi
            ;;
        *)
            warn "Unknown OS. Please install these packages manually: \${packages[*]}"
            ;;
    esac
}
# }}}
EOF
    fi

    # Add Luarocks section if needed
    if [[ ${#lua_external[@]} -gt 0 ]]; then
        cat << EOF >> "$output_file"

# -- {{{ Lua Packages (luarocks)
install_lua_packages() {
    if ! command_exists luarocks; then
        warn "luarocks not found. Skipping Lua package installation."
        return
    fi

    log "Installing Lua packages via luarocks..."

    local packages=(
$(printf '        "%s"\n' "${lua_external[@]}" | sort -u)
    )

    for pkg in "\${packages[@]}"; do
        log "Installing: \$pkg"
        run luarocks install "\$pkg" --local || warn "Failed to install \$pkg"
    done
}
# }}}
EOF
    fi

    # Add pip section if needed
    if [[ ${#python_external[@]} -gt 0 ]]; then
        cat << EOF >> "$output_file"

# -- {{{ Python Packages (pip)
install_python_packages() {
    if ! command_exists pip3 && ! command_exists pip; then
        warn "pip not found. Skipping Python package installation."
        return
    fi

    log "Installing Python packages via pip..."

    local pip_cmd="pip3"
    command_exists pip3 || pip_cmd="pip"

    local packages=(
$(printf '        "%s"\n' "${python_external[@]}" | sort -u)
    )

    run \$pip_cmd install --user "\${packages[@]}"
}
# }}}
EOF
    fi

    # Add npm section if needed
    if [[ ${#js_external[@]} -gt 0 ]] || [[ -f "$project_dir/package.json" ]]; then
        cat << 'EOF' >> "$output_file"

# -- {{{ Node.js Packages (npm)
install_node_packages() {
    if ! command_exists npm; then
        warn "npm not found. Skipping Node.js package installation."
        return
    fi

    if [[ -f package.json ]]; then
        log "Installing Node.js packages via npm..."
        run npm install
    fi
}
# }}}
EOF
    fi

    # Add main function
    cat << 'EOF' >> "$output_file"

# -- {{{ Main
main() {
    log "Starting dependency installation..."
    echo ""
EOF

    [[ ${#apt_deps[@]} -gt 0 ]] && echo "    install_apt_packages" >> "$output_file"
    [[ ${#lua_external[@]} -gt 0 ]] && echo "    install_lua_packages" >> "$output_file"
    [[ ${#python_external[@]} -gt 0 ]] && echo "    install_python_packages" >> "$output_file"
    [[ ${#js_external[@]} -gt 0 || -f "$project_dir/package.json" ]] && echo "    install_node_packages" >> "$output_file"

    cat << 'EOF' >> "$output_file"

    echo ""
    log "Dependency installation complete!"
}
# }}}

main "$@"
EOF

    chmod +x "$output_file"
    log "Generated: $output_file"
}
# }}}
```

---

## Output Example

### scripts/install-deps.sh

```bash
#!/bin/bash
# =============================================================================
# Dependency Installation Script
# Auto-generated by Issue 051 (Git Documentation Generator)
# =============================================================================

set -euo pipefail

# ... helper functions ...

# -- {{{ System Packages (apt)
install_apt_packages() {
    local packages=(
        "git"
        "jq"
        "lua5.3"
    )
    # ...
}
# }}}

# -- {{{ Lua Packages (luarocks)
install_lua_packages() {
    local packages=(
        "argparse"
        "luafilesystem"
        "inspect"
    )
    # ...
}
# }}}

main() {
    install_apt_packages
    install_lua_packages
    log "Dependency installation complete!"
}

main "$@"
```

---

## Acceptance Criteria

- [ ] Detects Lua require statements
- [ ] Detects Python import statements
- [ ] Detects JavaScript/Node dependencies
- [ ] Detects bash command dependencies
- [ ] Classifies local vs external dependencies
- [ ] Maps module names to package manager names
- [ ] Generates idempotent install script
- [ ] Supports dry-run mode
- [ ] Handles multiple package managers
- [ ] Includes platform detection (Linux/macOS)

---

## Metadata

- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: Issue 051a (uses project analysis)
- **Blocks**: None (install scripts are optional but valuable)
