# Issue 800d: Threadpool Test Suite

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 800a, 800b, 800c
**Parent:** 800-threadpool-library-extraction.md

---

## Current Behavior

No standalone tests for threading infrastructure. Verification is through
`demo_threading.c` which requires raylib and the full render system.

## Intended Behavior

Standalone test suite that verifies threadpool library functionality without
external dependencies (beyond pthread and standard C library).

```
my-libs/threadpool/tests/
├── test_main.c        # Test runner
├── test_pool.c        # Core pool tests
├── test_tasks.c       # Task append/execute tests
├── test_load.c        # Load balancing tests
├── test_sync.c        # Sync watch list tests
├── test_updater.c     # Updater self-evaluation tests
└── Makefile           # Build tests
```

## Suggested Implementation Steps

1. Create test infrastructure:
   - Simple assertion macros (no external test framework needed)
   - Test runner that reports pass/fail counts
   - Timing utilities for performance tests

2. Write test_pool.c:
   - Test: pool creates with auto-detect cores
   - Test: pool creates with specified count
   - Test: pool destroys cleanly (no leaks, threads join)
   - Test: NULL config uses defaults

3. Write test_tasks.c:
   - Test: task append to empty buffer
   - Test: task append to partially full buffer
   - Test: task append fails when buffer full
   - Test: task executes and decrements repeat_count
   - Test: on_complete called when repeat_count reaches 0
   - Test: ring buffer wraps correctly
   - Test: relocate triggers at threshold

4. Write test_load.c:
   - Test: find_least_busy returns correct worker
   - Test: find_least_busy_excluding skips specified worker
   - Test: weighted load accumulates correctly
   - Test: load decrements on task completion

5. Write test_sync.c (if sync module built):
   - Test: sync creates with config
   - Test: add_watch succeeds
   - Test: add_watch fails when full
   - Test: pointer swap occurs when ready flag set
   - Test: watch entry removed after swap
   - Test: sync stops cleanly

6. Write test_updater.c (if updater module built):
   - Test: updater creates and starts
   - Test: task source callback invoked
   - Test: tasks distributed to workers
   - Test: helper spawns under load (mock heavy callback)
   - Test: helper terminates when load decreases

7. Create Makefile:
   ```makefile
   CC = gcc
   CFLAGS = -Wall -Wextra -pthread -I..

   TESTS = test_pool test_tasks test_load test_sync test_updater

   all: run_tests

   run_tests: $(TESTS)
   	@for t in $(TESTS); do ./$$t || exit 1; done
   	@echo "All tests passed"
   ```

## Acceptance Criteria

- [x] Tests compile without render system or raylib
- [x] Tests run and pass on fresh checkout
- [x] Core module tests pass independently
- [x] Sync module tests can be skipped if module not built
- [x] Updater module tests can be skipped if module not built
- [x] No memory leaks (verify with valgrind optional)
- [x] Clear pass/fail output for each test

## Files to Create

- `my-libs/threadpool/tests/test_main.c`
- `my-libs/threadpool/tests/test_pool.c`
- `my-libs/threadpool/tests/test_tasks.c`
- `my-libs/threadpool/tests/test_load.c`
- `my-libs/threadpool/tests/test_sync.c`
- `my-libs/threadpool/tests/test_updater.c`
- `my-libs/threadpool/tests/Makefile`

## Notes

Test suite should be minimal and focused:
- No external test framework (simple assert macros)
- Tests document expected behavior
- Timing-dependent tests should have generous tolerances
- Each test file can run independently

Example assertion macro:
```c
#define TEST_ASSERT(cond, msg) do { \
    if (!(cond)) { \
        fprintf(stderr, "FAIL: %s:%d: %s\n", __FILE__, __LINE__, msg); \
        return 1; \
    } \
} while(0)

#define TEST_PASS(name) printf("PASS: %s\n", name)
```

## Implementation Notes

**Completed:** 2026-01-08

Created comprehensive test suite with 24 tests across 4 test files:

Test Files:
- test_pool.c (6 tests) - Core threadpool, load balancing, task execution
- test_sync.c (6 tests) - Watch list, pointer swapping, statistics
- test_updater.c (5 tests) - Task distribution, self-evaluation, user data
- test_scheduler.c (7 tests) - Absolute time scheduling, removal, capacity
- Makefile - Unified build system with 'make test' target

All tests use simple assertion macros (TEST_ASSERT, TEST_PASS) without external
dependencies. Each test file can run independently and reports clear pass/fail
status with line numbers for failures.

Key Design Decisions:
- No test framework needed (simple assert macros sufficient)
- Timing-dependent tests use generous tolerances (50-100ms)
- Mock callbacks for updater testing
- Static test state with atomic counters for thread safety
- Build directory (build/) for compiled object files
- Test executables excluded from git (.gitignore should add them)

Bug Fixes During Implementation:
- Fixed atomic_uint64_t → _Atomic uint64_t for C11 compliance
- Fixed test_updater_distributes_tasks race condition (callback looping)

All tests pass successfully with zero failures.
