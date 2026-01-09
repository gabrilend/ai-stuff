# Issue A03: Unified Test Runner

**Phase:** A - Infrastructure Tools (Shared)
**Type:** Tool
**Priority:** Medium
**Dependencies:** None
**Project:** delta-version (meta-project infrastructure)
**Location:** `/home/ritz/programming/ai-stuff/scripts/run-tests.sh`

---

## Current Behavior

Tests must be run individually via `luajit src/tests/test_*.lua`. No way to:
- Run all tests at once
- Filter tests by pattern
- Get aggregate pass/fail statistics
- Identify which tests are failing across the project

---

## Intended Behavior

A unified test runner script that:
- Discovers all `test_*.lua` files in `src/tests/`
- Runs each with luajit and captures output
- Tracks pass/fail counts per file and aggregate
- Supports filtering by pattern
- Reports summary statistics
- Exits with non-zero if any test failed
- **Project-abstract**: Works on any project with Lua tests

---

## Installation

The script lives in the shared scripts directory and can be symlinked into projects:

```bash
# In a project directory
ln -s /home/ritz/programming/ai-stuff/scripts/run-tests.sh src/cli/run-tests.sh
```

---

## Usage

```bash
# Run all tests
./scripts/run-tests.sh

# Or via symlink in project
./src/cli/run-tests.sh

# Run tests matching pattern
./scripts/run-tests.sh ecs
./scripts/run-tests.sh parser

# Verbose mode (show all output)
./scripts/run-tests.sh -v

# Quiet mode (only summary)
./scripts/run-tests.sh -q

# Stop on first failure
./scripts/run-tests.sh -x

# List tests without running
./scripts/run-tests.sh -l

# Show timing for each test
./scripts/run-tests.sh -t

# Specify project directory
./scripts/run-tests.sh -d /path/to/project
```

---

## Output Format

```
=== Running 95 tests ===

[PASS] test_ecs_entity.lua (64 passed, 0 failed)
[PASS] test_ecs_component.lua (106 passed, 0 failed)
[FAIL] test_broken.lua (15 passed, 2 failed)
  └─ FAIL: test_something: expected 5, got 6
  └─ FAIL: test_other: nil value
[PASS] test_timers.lua (100 passed, 0 failed)
...

════════════════════════════════════════════════
SUMMARY: 93/95 test files passed
         4521 assertions passed, 2 failed

FAILED TESTS:
  - test_broken.lua
════════════════════════════════════════════════
```

---

## Test Detection

Tests are identified by:
- Location: `src/tests/` directory
- Naming: `test_*.lua` pattern
- Output: Supports multiple summary formats (see implementation notes)
- Exit code: 0 = pass, non-zero = fail

---

## Suggested Implementation Steps

1. Create script skeleton with DIR and argument handling
2. Implement test file discovery
3. Implement single test runner with output capture
4. Implement result parsing (extract pass/fail counts)
5. Add filtering support
6. Add verbose/quiet modes
7. Add summary statistics
8. Add color output
9. Test on actual test suite

---

## Acceptance Criteria

- [x] Discovers all test files automatically
- [x] Runs each test and reports pass/fail
- [x] Parses test output for assertion counts
- [x] Supports pattern filtering
- [x] Verbose mode shows all test output
- [x] Quiet mode shows only summary
- [x] Exit code reflects overall pass/fail
- [x] Works from any directory (uses $DIR)
- [x] Handles test crashes gracefully
- [x] Reports timing information

---

## Notes

This tool should be project-agnostic and live in the shared scripts directory,
symlinked into projects that need it. The test format (luajit + summary line)
is consistent across this project.

---

## Implementation Notes

*Implemented 2026-01-07*

### Files Created

- `world-edit-to-execute/src/cli/run-tests.sh` - Initial prototype
- **TODO:** Move to `/home/ritz/programming/ai-stuff/scripts/run-tests.sh` (shared location)
- **TODO:** Create symlinks in projects that use Lua tests

### Features Implemented

| Feature | Description |
|---------|-------------|
| Test discovery | Finds all `test_*.lua` files in `src/tests/` |
| Pattern filtering | Case-insensitive substring match on filename |
| Multiple output modes | Verbose (`-v`), Quiet (`-q`), Default |
| Timing support | Per-test and total timing with `-t` flag |
| Stop on failure | `-x` flag stops on first failure |
| List mode | `-l` lists tests without running |
| Color output | Green for pass, red for fail (disabled when piped) |

### Supported Test Output Formats

The runner parses multiple summary line formats:

| Format | Example |
|--------|---------|
| Format 1a | `Tests: 21 passed, 0 failed, 21 total` |
| Format 1b | `Tests: 50 passed / 50 total` |
| Format 2a | `Tests passed: 57/57` |
| Format 2b | `Passed: 19 / 19` |
| Format 3 | `N tests passed` |
| Format 4 | Multiline `Passed: N` / `Failed: M` |

### Test Results

Initial run on full test suite (104 test files):
- 101/104 test files passed
- 72,663 assertions detected
- 3 tests fail due to Lua syntax/compatibility issues (not runner issues)

### CLI Flags

| Flag | Description |
|------|-------------|
| `-v, --verbose` | Show all test output |
| `-q, --quiet` | Show only summary |
| `-x, --stop` | Stop on first failure |
| `-l, --list` | List tests without running |
| `-t, --timing` | Show timing for each test |
| `-d, --dir DIR` | Project directory |
| `-h, --help` | Show help |

### Exit Codes

- 0: All tests passed
- 1: One or more tests failed
- 2: No tests found
