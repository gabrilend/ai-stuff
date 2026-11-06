# Issue A03: Unified Test Runner

**Phase:** A - Infrastructure Tools (Shared)
**Type:** Tool
**Priority:** Medium
**Dependencies:** None

---

## Current Behavior

Built (2026-01-08) as `src/cli/run-tests.sh`: it finds every
`src/tests/test_*.lua`, runs each with LuaJIT, reads each file's own summary
line in any of the formats the tests print, and reports passed files,
passed and failed assertions, and timing; a pattern argument filters files,
and the exit code is non-zero if any file failed.

Phase A later moved to the shared scripts project (commit 8e50999a9), where
a project-independent runner (`scripts/test-runner.sh`) is tracked by its
own copy of this issue. This copy records the runner that lives here.

Rechecked 2026-09-26: 112 of 112 test files pass with no warnings. (The
first recheck printed a bash warning, "ignored null byte in input": the
map-info test printed a map's weather code raw, and a map with no weather
holds four zero bytes there. The test now prints it escaped.)

---

## Intended Behavior

A unified test runner script that:
- Discovers all `test_*.lua` files in `src/tests/`
- Runs each with luajit and captures output
- Tracks pass/fail counts per file and aggregate
- Supports filtering by pattern
- Reports summary statistics
- Exits with non-zero if any test failed

---

## Usage

```bash
# Run all tests
./src/cli/run-tests.sh

# Run tests matching pattern
./src/cli/run-tests.sh ecs
./src/cli/run-tests.sh parser

# Verbose mode (show all output)
./src/cli/run-tests.sh -v

# Quiet mode (only summary)
./src/cli/run-tests.sh -q

# Stop on first failure
./src/cli/run-tests.sh -x

# List tests without running
./src/cli/run-tests.sh -l

# Show timing for each test
./src/cli/run-tests.sh -t

# Specify project directory
./src/cli/run-tests.sh -d /path/to/project
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

- `src/cli/run-tests.sh` - Unified test runner script

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

---

## Note (2026-11-06): the runner tests the project it sits in

**Found:** run without a `DIR`, most tests fall back to the fixed path
`/mnt/mtwo/programming/ai-stuff/world-edit-to-execute`, and the runner
gave them none. Where that path holds an older copy of the project (as it
does in the container this was found in), the runner tested the old copy:
traced through the runner, 107 of the 144 test files that load project code
loaded it from the fixed path, not from the project the runner was run in.
The runner's own default was the same fixed path.

**Decision (2026-11-06):** follow the newer idiom, not the older one.
The tests from 2026-09 take the project as `arg[1]` with the fixed path as
the fallback (`local DIR = arg[1] or "..."`), and `run-net-tests.sh`
(2026-09-25) passes `DIR` to each; the self-locating
`debug.getinfo` tests are from December 2025. So:

- `run-tests.sh` passes `$DIR` to every test, and its default `DIR` is the
  project it sits in (`$(dirname "$0")/../..`, as `run_phase9.sh` does);
  `-d` still names another.
- The 38 tests that ignored `arg[1]` take it now (the one-word change to
  `arg[1] or`), and `test_frames.lua` builds its path from `DIR`.
- The aggregating tests that start other tests pass `DIR` on to them
  (`test_309b` to `309f`, `test_triggers`).

No test's expectations changed. With the fix, every test that loads
project code loads it from the project being tested.

**What newly fails** (it now reads this project's own `assets/`, which
gained three maps on 2026-11-02 that the old copy lacks): `test_309a`,
`test_wct`, `test_unitsdoo`, `test_map_save`, `test_phase2_integration`
(the units, triggers and trigger-comments files of Conquest-v8-fix and
Master-Crafters-Final-Conquest), `test_j` (two of the new maps hold
`war3map.j`), `test_new_map` (Conquest-v8-fix's `war3map.w3i` doesn't write
back byte for byte), `test_anim` (an imported model in
War-in-the-Plaguelands). `test_net_hosted` fails as before (it needs effil).
These are left failing for the parser issues; the runner now reports them.
