# Issue A03: Unified Test Runner

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** High
**Dependencies:** None

---

## Current Behavior

`scripts/test-runner.sh` runs every test a project keeps, all at once, and
exits 0 (all passed), 1 (something failed) or 2 (nothing to run, or it
could not start). See "Design as built" at the end for what it finds, and
for the parts of the original plan it deliberately does not do.

Before this, a first version of the script existed but could not have run:
it was not executable, it doubled the project path onto the test folder,
its counters stopped the script on the first test under exit-on-error, and
it only knew `src/tests/test_*.lua`, so none of this repository's own tests
(`tests/`, `test-refusal-gates`, `check-transcripts-are-filed-right`) were
ever run by anything.

---

## Intended Behavior

A project-abstract test runner that:
- Discovers and runs all test files matching patterns
- Filters tests by phase, module, or custom tags
- Aggregates pass/fail statistics
- Outputs results in multiple formats (terminal, JUnit XML, JSON)
- Works across any project following standard test conventions

---

## Suggested Implementation Steps

1. **Create shared script**
   ```
   /home/ritz/programming/ai-stuff/scripts/test-runner.sh
   ```
   Symlinked into projects as `src/cli/test-runner.sh`

2. **Define configuration interface**
   ```bash
   # Project-specific config
   PROJECT_DIR=""
   TEST_DIR="src/tests"
   TEST_PATTERN="test_*.lua"
   LUA_CMD="lua5.4"              # Or luajit
   LUA_PATH_EXTRA=""            # Additional require paths

   # Test discovery
   PHASE_PATTERN='test_([0-9]+)'  # Extract phase from filename
   ```

3. **Implement test discovery**
   ```bash
   # {{{ discover_tests
   discover_tests() {
       local test_dir="$1"
       local pattern="$2"
       local phase_filter="$3"

       find "$test_dir" -name "$pattern" -type f | while read -r test_file; do
           # Extract phase if present
           local phase=$(echo "$test_file" | grep -oP "$PHASE_PATTERN" | head -1)

           # Apply phase filter
           if [[ -z "$phase_filter" ]] || [[ "$phase" == "$phase_filter" ]]; then
               echo "$test_file"
           fi
       done
   }
   # }}}
   ```

4. **Implement test execution**
   ```bash
   # {{{ run_test
   run_test() {
       local test_file="$1"
       local timeout="${2:-60}"

       local start_time=$(date +%s.%N)
       local output
       local exit_code

       # Run with timeout
       output=$(timeout "$timeout" $LUA_CMD "$test_file" 2>&1)
       exit_code=$?

       local end_time=$(date +%s.%N)
       local duration=$(echo "$end_time - $start_time" | bc)

       echo "$exit_code|$duration|$output"
   }
   # }}}
   ```

5. **Implement result aggregation**
   ```bash
   # {{{ aggregate_results
   # Results stored in associative arrays
   declare -A TEST_RESULTS      # test_file -> pass|fail|error|skip
   declare -A TEST_DURATIONS    # test_file -> seconds
   declare -A TEST_OUTPUTS      # test_file -> stdout/stderr

   aggregate_results() {
       local passed=0
       local failed=0
       local errors=0
       local skipped=0
       local total_duration=0

       for test in "${!TEST_RESULTS[@]}"; do
           case "${TEST_RESULTS[$test]}" in
               pass) ((passed++)) ;;
               fail) ((failed++)) ;;
               error) ((errors++)) ;;
               skip) ((skipped++)) ;;
           esac
           total_duration=$(echo "$total_duration + ${TEST_DURATIONS[$test]}" | bc)
       done

       echo "$passed|$failed|$errors|$skipped|$total_duration"
   }
   # }}}
   ```

6. **Implement terminal output**
   ```bash
   # {{{ render_terminal
   render_terminal() {
       echo "═══════════════════════════════════════════════════════════"
       echo "                    TEST RESULTS                           "
       echo "═══════════════════════════════════════════════════════════"

       for test in "${!TEST_RESULTS[@]}"; do
           local status="${TEST_RESULTS[$test]}"
           local duration="${TEST_DURATIONS[$test]}"
           local name=$(basename "$test" .lua)

           case "$status" in
               pass)  printf "  ✓ %-40s %6.2fs\n" "$name" "$duration" ;;
               fail)  printf "  ✗ %-40s %6.2fs\n" "$name" "$duration" ;;
               error) printf "  ! %-40s %6.2fs\n" "$name" "$duration" ;;
               skip)  printf "  ○ %-40s skipped\n" "$name" ;;
           esac
       done

       echo "───────────────────────────────────────────────────────────"
       local stats=$(aggregate_results)
       IFS='|' read -r passed failed errors skipped duration <<< "$stats"
       echo "  Passed: $passed | Failed: $failed | Errors: $errors | Skipped: $skipped"
       echo "  Total time: ${duration}s"
       echo "═══════════════════════════════════════════════════════════"
   }
   # }}}
   ```

7. **Implement JUnit XML output**
   ```bash
   # {{{ render_junit
   render_junit() {
       local output_file="$1"
       local stats=$(aggregate_results)
       IFS='|' read -r passed failed errors skipped duration <<< "$stats"
       local total=$((passed + failed + errors + skipped))

       cat > "$output_file" << EOF
   <?xml version="1.0" encoding="UTF-8"?>
   <testsuites tests="$total" failures="$failed" errors="$errors" time="$duration">
     <testsuite name="$(basename $PROJECT_DIR)" tests="$total">
   EOF

       for test in "${!TEST_RESULTS[@]}"; do
           local name=$(basename "$test" .lua)
           local status="${TEST_RESULTS[$test]}"
           local time="${TEST_DURATIONS[$test]}"

           echo "    <testcase name=\"$name\" time=\"$time\">" >> "$output_file"
           if [[ "$status" == "fail" ]]; then
               echo "      <failure>${TEST_OUTPUTS[$test]}</failure>" >> "$output_file"
           elif [[ "$status" == "error" ]]; then
               echo "      <error>${TEST_OUTPUTS[$test]}</error>" >> "$output_file"
           fi
           echo "    </testcase>" >> "$output_file"
       done

       echo "  </testsuite>" >> "$output_file"
       echo "</testsuites>" >> "$output_file"
   }
   # }}}
   ```

8. **Add CLI interface**
   ```bash
   # Modes:
   # -a, --all            Run all tests
   # -p, --phase X        Run tests for specific phase
   # -f, --filter PATTERN Filter test files by pattern
   # -t, --timeout N      Test timeout in seconds
   # -v, --verbose        Show test output
   # -q, --quiet          Only show summary
   # --junit FILE         Output JUnit XML
   # --json FILE          Output JSON
   # -I, --interactive    TUI mode for selecting tests
   # --parallel N         Run N tests in parallel
   ```

9. **Implement TUI mode**
   ```bash
   # Interactive mode:
   # - Show list of discovered tests with checkboxes
   # - Allow selecting individual tests or phases
   # - Show live progress during execution
   # - Display results with expandable details
   ```

---

## Library Design

```bash
# As CLI
./test-runner.sh -a -v

# As library
source /path/to/scripts/test-runner.sh
test_runner_init "$PROJECT_DIR"
tests=$(test_runner_discover "$TEST_DIR" "$PATTERN")
test_runner_run_all "$tests"
test_runner_render_terminal
```

### Exported Functions

| Function | Description |
|----------|-------------|
| `test_runner_init` | Initialize with project directory |
| `test_runner_discover` | Find test files matching criteria |
| `test_runner_run` | Run a single test file |
| `test_runner_run_all` | Run multiple tests |
| `test_runner_aggregate` | Get aggregated statistics |
| `test_runner_render_terminal` | Display terminal results |
| `test_runner_render_junit` | Generate JUnit XML |
| `test_runner_render_json` | Generate JSON report |

---

## Output Example

```
═══════════════════════════════════════════════════════════
                    TEST RESULTS
═══════════════════════════════════════════════════════════
  ✓ test_mpq                                    0.45s
  ✓ test_w3i                                    0.32s
  ✓ test_wts                                    0.18s
  ✓ test_w3e                                    0.67s
  ✓ test_w3r                                    0.21s
  ✓ test_w3c                                    0.19s
  ✓ test_data                                   0.55s
  ✓ phase1_test                                 2.34s
───────────────────────────────────────────────────────────
  Passed: 8 | Failed: 0 | Errors: 0 | Skipped: 0
  Total time: 4.91s
═══════════════════════════════════════════════════════════
```

---

## Related Documents

- src/tests/ (test location)
- /home/ritz/programming/ai-stuff/scripts/ (shared scripts)
- issues/completed/demos/ (phase demos)

---

## Acceptance Criteria

- [x] Script lives in shared scripts directory
- [—] Symlink created in project src/cli/ (not needed: project folder is an argument; see Design as built)
- [x] Discovers test files by pattern
- [—] Filters by phase (replaced by -f; see Design as built)
- [x] Runs tests with timeout
- [x] Aggregates pass/fail statistics
- [x] Terminal output with colors/symbols
- [—] JUnit XML output for CI (dropped; see Design as built)
- [x] JSON output
- [x] Verbose mode shows test output
- [—] Interactive TUI mode (dropped; see Design as built)
- [—] Works as both CLI and library (CLI only; see Design as built)
- [x] Project-abstract configuration

---

## Notes

This tool is essential for development workflow. Should integrate with
CI/CD systems via JUnit output.

Consider supporting parallel test execution for faster runs on large
test suites, with proper output interleaving handling.

LuaJIT and Lua 5.4 may need different invocation - make LUA_CMD configurable.

---

## Design as built

**What counts as a test** (found by place and name, no configuration):
- `test_*.lua` / `test-*.lua` in `src/tests/` or `tests/` -- run with luajit.
- `test-*` / `test_*` in the project root, `tests/` or `src/tests/` that is
  executable or ends in `.sh` -- run as a program.
- `check-*` executables in the project root -- the house writes verifiers as
  read-only reporters that exit 1 on a fault, and they are tests too.
- Anything ending `-done` (the retired-file marker) is skipped, and the
  runner never runs itself.

**How it runs them:** every test is a background job, as many at once as
there are cores (`-j` to change), each under a timeout (`-t`, default 120s).
Each test's full output goes to `<project>/tmp/shared-memory/test-runner/
<run>/`, the RAM artifact tier, which `libs/ensure-ram-tiers` builds first.
Results print in discovery order so two runs read the same; a failure shows
its last 15 lines. `--json <file>` writes a machine-readable copy; `-l`
lists without running; `-f` filters by path text.

**Deliberately not done** (decisions, not deferred work):
- *Lua 5.4 fallback* -- the house language is LuaJIT and 5.4 syntax is not
  allowed, so a missing luajit stops the run instead of quietly using 5.4.
- *Per-project `src/cli/` symlink* -- the project folder is the first
  argument, so one shared copy serves every project without a link.
- *Phase filter* -- test files are not named by phase in any project;
  `-f <text>` covers selecting a subset.
- *JUnit XML, TUI mode, sourcing as a library* -- nothing consumes JUnit,
  the bash TUI libraries it would have used are being retired, and no other
  tool needs the runner's internals. JSON covers the machine-readable need.

**Acceptance, re-read against that design:** discovers tests by pattern ✓,
runs with timeout ✓, aggregates pass/fail ✓, terminal output with colour
(only when a person is watching) ✓, JSON output ✓, verbose mode ✓,
project-abstract (any folder, no configuration) ✓. Verified on this
repository: 11 tests found and run in parallel; 10 passed, and
`check-transcripts-are-filed-right` failed on a real misfiled transcript
(`filesystem-tapestry/llm-transcripts/jul-15-26.md`, recorded under a
different working directory) -- the runner reporting a true fault.
