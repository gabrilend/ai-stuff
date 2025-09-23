#!/bin/bash

# Build script for handheld office project
# Follows the vision of multiple steps with validation

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_FILE="files/build/build.log"
mkdir -p files/build

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

save_build_state() {
    local component="$1"
    local state="$2"
    echo "{\"component\":\"$component\",\"state\":\"$state\",\"timestamp\":$(date +%s)}" > "files/build/${component}_state.json"
}

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v rustc &> /dev/null; then
        log "ERROR: Rust not found. Please install Rust toolchain."
        exit 1
    fi
    
    if ! command -v cargo &> /dev/null; then
        log "ERROR: Cargo not found. Please install Rust toolchain."
        exit 1
    fi
    
    if ! command -v lua &> /dev/null; then
        log "WARNING: Lua not found. Orchestrator may not work."
    fi
    
    log "Dependencies check passed"
}

build_component() {
    local component="$1"
    log "Building $component..."
    
    if cargo build --release --bin "$component" 2>&1 | tee -a "$LOG_FILE"; then
        save_build_state "$component" "success"
        log "$component build successful"
        return 0
    else
        save_build_state "$component" "failed"
        log "ERROR: $component build failed"
        return 1
    fi
}

validate_binary() {
    local component="$1"
    local binary_path="target/release/$component"
    
    if [[ -f "$binary_path" ]]; then
        log "$component binary validated at $binary_path"
        return 0
    else
        log "ERROR: $component binary not found at $binary_path"
        return 1
    fi
}

main() {
    log "=== Handheld Office Build Process Started ==="
    
    check_dependencies
    
    # Build each component with validation
    components=("daemon" "handheld" "desktop-llm")
    
    for component in "${components[@]}"; do
        if build_component "$component"; then
            validate_binary "$component"
        else
            log "Build failed for $component, stopping build process"
            exit 1
        fi
    done
    
    # Copy orchestration scripts to build directory for easy access
    cp scripts/orchestrator.lua files/build/
    chmod +x scripts/build.sh
    
    log "=== Build Process Completed Successfully ==="
    log "Use 'lua scripts/orchestrator.lua run' to start the system"
}

main "$@"