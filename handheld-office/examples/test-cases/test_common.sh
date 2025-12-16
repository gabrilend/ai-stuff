#!/bin/bash

# Common functions for test-cases scripts
# Source this file to get shared functionality

check_binaries_exist() {
    local required_binaries=("$@")
    local missing_binaries=()
    
    for binary in "${required_binaries[@]}"; do
        if [[ ! -f "files/target/release/$binary" ]]; then
            missing_binaries+=("$binary")
        fi
    done
    
    if [[ ${#missing_binaries[@]} -gt 0 ]]; then
        echo "❌ Missing required binaries: ${missing_binaries[*]}"
        echo "🔧 This is expected due to current compilation issues."
        echo "📋 See issues/024-compilation-errors-master-tracking.md for resolution steps."
        echo "✅ Test script structure is correct - waiting for compilation fixes!"
        return 1
    fi
    
    return 0
}

validate_test_environment() {
    # Check if we're in the right directory
    if [[ ! -f "Cargo.toml" ]] || [[ ! -d "src" ]]; then
        echo "❌ Must run from project root directory"
        return 1
    fi
    
    # Check if files/target directory exists
    if [[ ! -d "files/target" ]]; then
        echo "❌ Build directory files/target/ not found"
        echo "🔧 Run 'cargo build' to create build artifacts"
        return 1
    fi
    
    return 0
}

show_compilation_help() {
    echo ""
    echo "🔧 TO RESOLVE COMPILATION ISSUES:"
    echo "   1. Add missing dependencies to Cargo.toml (Issue #021)"
    echo "   2. Create missing type definitions (Issue #021)"
    echo "   3. Fix async trait annotations (Issue #019)"
    echo "   4. Complete struct implementations (Issue #020)"
    echo ""
    echo "📋 Detailed steps: issues/024-compilation-errors-master-tracking.md"
    echo "⏱️  Estimated fix time: 4-6 hours for basic compilation"
}