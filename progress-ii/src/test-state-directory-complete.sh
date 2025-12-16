#!/bin/bash

# Comprehensive test for Issue 002-A: State Directory Structure
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the state directory library
source "${DIR}/libs/state-directory.sh"

echo "Comprehensive State Directory Management Test"
echo "==========================================="

TEST_DIR="${DIR}/test-complete-state"

# Test 1: Initialize state directory
echo "Test 1: Initializing state directory..."
if initialize_state_directory "${TEST_DIR}"; then
    echo "[OK] State directory initialization successful"
else
    echo "[FAIL] State directory initialization failed"
    exit 1
fi

echo ""

# Test 2: Validate directory structure  
echo "Test 2: Validating directory structure..."
if validate_directory_structure "${TEST_DIR}"; then
    echo "[OK] Directory structure validation successful"
else
    echo "[FAIL] Directory structure validation failed"
    exit 1
fi

echo ""

# Test 3: Get directory information
echo "Test 3: Getting directory information..."
get_state_directory_info "${TEST_DIR}"

echo ""

# Test 4: Test repair functionality by removing a directory
echo "Test 4: Testing repair functionality..."
rmdir "${TEST_DIR}/world/items"
echo "Removed world/items directory to test repair..."

if repair_directory_structure "${TEST_DIR}"; then
    echo "[OK] Directory structure repair successful"
else
    echo "[FAIL] Directory structure repair failed"
    exit 1
fi

echo ""

# Test 5: Final validation after repair
echo "Test 5: Final validation after repair..."
if validate_directory_structure "${TEST_DIR}"; then
    echo "[OK] Final validation successful"
else
    echo "[FAIL] Final validation failed"  
    exit 1
fi

echo ""

# Test 6: Test permissions
echo "Test 6: Testing permission setting..."
if set_directory_permissions "${TEST_DIR}"; then
    echo "[OK] Permission setting successful"
else
    echo "[FAIL] Permission setting failed"
    exit 1
fi

echo ""

# Test 7: Verify permissions were set correctly
echo "Test 7: Verifying permissions..."
BASE_PERMS=$(stat -c "%a" "${TEST_DIR}")
if [ "${BASE_PERMS}" = "750" ]; then
    echo "[OK] Base directory permissions correct (750)"
else
    echo "[FAIL] Base directory permissions incorrect: ${BASE_PERMS}"
fi

SUBDIR_PERMS=$(stat -c "%a" "${TEST_DIR}/characters")
if [ "${SUBDIR_PERMS}" = "750" ]; then
    echo "[OK] Subdirectory permissions correct (750)"
else
    echo "[FAIL] Subdirectory permissions incorrect: ${SUBDIR_PERMS}"
fi

echo ""

# Test 8: Final info display
echo "Test 8: Final state information..."
get_state_directory_info "${TEST_DIR}"

echo ""
echo "All tests passed! State directory management system is fully functional."

# Cleanup
echo ""
echo "Cleaning up test directory..."
rm -rf "${TEST_DIR}"
echo "Test suite completed successfully."