#!/bin/bash

# Test script for state directory management
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source the state directory library
source "$DIR/libs/state-directory.sh"

echo "Testing State Directory Management System"
echo "========================================"

# Test 1: Initialize state directory
echo "Test 1: Initializing state directory..."
if initialize_state_directory "$DIR/test-game-state"; then
    echo "[OK] State directory initialization successful"
else
    echo "[FAIL] State directory initialization failed"
    exit 1
fi

echo ""

# Test 2: Validate directory structure
echo "Test 2: Validating directory structure..."
if validate_directory_structure "$DIR/test-game-state"; then
    echo "[OK] Directory structure validation successful"
else
    echo "[FAIL] Directory structure validation failed"
    exit 1
fi

echo ""

# Test 3: Get directory information
echo "Test 3: Getting directory information..."
get_state_directory_info "$DIR/test-game-state"

echo ""

# Test 4: Test repair functionality by removing a directory
echo "Test 4: Testing repair functionality..."
rmdir "$DIR/test-game-state/world/items"
echo "Removed world/items directory to test repair..."

if repair_directory_structure "$DIR/test-game-state"; then
    echo "[OK] Directory structure repair successful"
else
    echo "[FAIL] Directory structure repair failed"
    exit 1
fi

echo ""

# Test 5: Final validation
echo "Test 5: Final validation after repair..."
if validate_directory_structure "$DIR/test-game-state"; then
    echo "[OK] Final validation successful"
else
    echo "[FAIL] Final validation failed"
    exit 1
fi

echo ""
echo "All tests passed! State directory management system is working correctly."

# Cleanup test directory
echo "Cleaning up test directory..."
rm -rf "$DIR/test-game-state"
echo "Test complete."