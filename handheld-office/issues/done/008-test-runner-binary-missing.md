# Issue #008: Test Runner Binary Configuration Missing

## Description

The test runner implementation exists in tests/test_runner.rs but is not configured as a binary in Cargo.toml, making it unusable as documented.

## Documentation States

**In TESTING.md lines 129-168:**
- Extensive documentation for using `cargo run --bin test_runner`
- Multiple command examples with --quick, --critical, --ci flags
- Pre-commit hook configuration using the binary

## Actual Implementation

**File exists:** tests/test_runner.rs (comprehensive test runner implementation)
- Complete TestRunner struct with test execution logic
- TestSuite struct for organizing tests
- Support for parallel execution, timeouts, critical tests
- Detailed error reporting and colored output

**Missing:** Binary configuration in Cargo.toml

## Issue Details

The test runner is implemented as a library in tests/ but needs to be:
1. **Moved to src/test_runner.rs** and configured as a binary, OR
2. **Used as integration test** with different command syntax

Currently users get:
```
error: no bin target named `test_runner`
```

## Code Analysis

**In tests/test_runner.rs:**
- Uses `colored::Colorize` (dependency not in Cargo.toml)
- Has proper CLI-style interface 
- Implements the exact functionality documented in TESTING.md

## Suggested Fixes

**Option A: Configure as Binary**
1. Move tests/test_runner.rs to src/test_runner.rs
2. Add to Cargo.toml:
   ```toml
   [[bin]]
   name = "test_runner"
   path = "src/test_runner.rs"
   ```
3. Add missing dependencies:
   ```toml
   colored = "2.0"
   ```

**Option B: Update Documentation**
- Change all references from `cargo run --bin test_runner` to `cargo test --test test_runner`
- Update command syntax examples

## Line Numbers

- Missing: Cargo.toml binary configuration
- tests/test_runner.rs: Complete implementation exists
- TESTING.md: Lines 129-168 (incorrect usage examples)

## Priority

High - Makes documented testing workflow completely unusable despite implementation existing