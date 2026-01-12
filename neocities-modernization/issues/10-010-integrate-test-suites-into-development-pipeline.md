# Issue 10-010: Integrate Test Suites into Development Pipeline

**Phase**: 10 (Developer Tooling)
**Priority**: Low
**Status**: Open
**Created**: 2026-01-12

## Current Behavior

Test suites exist for various modules but are run manually:
- `libs/hope-card-formatter-test.lua` - Tests formatting functionality
- Other test files scattered throughout the codebase
- No automated validation during development
- Tests must be explicitly invoked by developers

This means:
- Edge cases can slip through undetected
- Data integrity issues may only be caught in production
- Regression testing is inconsistent
- No continuous validation of module contracts

## Intended Behavior

Test suites should be integrated into the development workflow to automatically validate:
- **Module functionality** - All libs/ modules pass their test suites
- **Data format compliance** - Generated data meets specifications
- **Edge case handling** - Boundary conditions are tested
- **Regression prevention** - Changes don't break existing functionality

Test execution should happen:
- Before major operations (optional pre-flight checks)
- After code changes (on-demand validation)
- As part of CI/CD (if automated deployment exists)
- **NOT on critical path** - Tests run in background or as optional validation

## Suggested Implementation Steps

### Step 1: Create Test Runner Script

Create `scripts/run-tests` that discovers and runs all test suites:

```bash
#!/bin/bash
# Test runner for neocities-modernization project
# Discovers and runs all *-test.lua files

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Suite Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find all test files
TEST_FILES=$(find "$DIR" -name "*-test.lua" -type f | sort)

if [ -z "$TEST_FILES" ]; then
    echo "⚠️  No test files found"
    exit 0
fi

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Run each test file
for test_file in $TEST_FILES; do
    rel_path="${test_file#$DIR/}"
    echo "Running: $rel_path"

    if luajit "$test_file" 2>&1; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "❌ FAILED: $rel_path"
    fi

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Suites: $TOTAL_TESTS"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "✅ All test suites passed!"
    exit 0
else
    echo "❌ Some test suites failed"
    exit 1
fi
```

### Step 2: Standardize Test Suite Format

Create guidelines for test file structure:

```lua
#!/usr/bin/env luajit
-- Test suite for <module-name>

-- Standard test infrastructure
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

local function assert_equal(actual, expected, test_name)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        print(string.format("✅ PASS: %s", test_name))
        return true
    else
        tests_failed = tests_failed + 1
        print(string.format("❌ FAIL: %s", test_name))
        return false
    end
end

-- Tests here...

-- Summary (required format for test runner)
if tests_failed == 0 then
    print("✅ All tests passed!")
    os.exit(0)
else
    print("❌ Some tests failed")
    os.exit(1)
end
```

### Step 3: Optional Pre-Flight Checks

Add optional test validation to critical scripts:

```lua
-- At the start of major operations:
if os.getenv("RUN_TESTS") == "1" then
    print("Running pre-flight tests...")
    local result = os.execute("./scripts/run-tests")
    if result ~= 0 then
        print("❌ Tests failed - aborting operation")
        os.exit(1)
    end
end
```

### Step 4: Add Test Discovery to run.sh

Integrate test runner as an optional step:

```bash
# In run.sh, add:
if [ "${RUN_TESTS:-0}" = "1" ]; then
    echo "Running test suites..."
    ./scripts/run-tests || {
        echo "❌ Tests failed - see above for details"
        exit 1
    }
fi
```

### Step 5: Create Data Validation Tests

Add test suites for data format validation:

- `libs/poems-format-test.lua` - Validates poems.json structure
- `libs/similarity-matrix-test.lua` - Validates similarity data format
- `libs/embedding-format-test.lua` - Validates embedding data

### Step 6: Documentation

Document testing system in:
- `docs/testing-guide.md` - How to write and run tests
- `README.md` - Mention test suite availability
- Issue files - Reference relevant test suites

## Usage Examples

### Run all tests manually
```bash
./scripts/run-tests
```

### Run tests before major operation
```bash
RUN_TESTS=1 ./run.sh
```

### Run single test suite
```bash
luajit libs/hope-card-formatter-test.lua
```

### Add test to development workflow
```bash
# In your dev script:
if ! luajit libs/my-module-test.lua; then
    echo "Tests failed - fix before committing"
    exit 1
fi
```

## Benefits

**Catches Edge Cases Early:**
- Invalid data formats detected before production
- Boundary conditions validated automatically
- Regression bugs caught immediately

**Improves Code Quality:**
- Developers write tests alongside code
- Module contracts are clearly defined
- Refactoring becomes safer

**Reduces Debugging Time:**
- Failures pinpoint exact module/function
- Expected vs actual output shown clearly
- Don't waste time tracking down data format bugs

**Low Overhead:**
- Tests run in background (not on critical path)
- Optional pre-flight validation
- Fast feedback loop for developers

## Success Criteria

- [ ] `scripts/run-tests` discovers and runs all test suites
- [ ] Standard test format documented and followed
- [ ] At least 3 modules have comprehensive test suites
- [ ] Optional pre-flight validation integrated into run.sh
- [ ] Testing guide documentation created
- [ ] Zero test failures in clean environment

## Related Issues

- **6-012**: hope-card-formatter already has comprehensive test suite
- **10-009**: Centroid unwinding will need extensive testing
- **Phase 9**: GPU operations should have validation tests

## Notes

This is a **low priority** issue because:
- Test infrastructure already exists (hope-card-formatter-test.lua)
- Main benefit is convenience and consistency
- Not blocking any critical functionality
- Can be implemented incrementally

However, it provides significant value for:
- Long-term maintainability
- Preventing regressions
- Developer confidence
- Catching edge cases early

---

*"validate the data, test the edge,*
*catch the bugs before they hedge."*
