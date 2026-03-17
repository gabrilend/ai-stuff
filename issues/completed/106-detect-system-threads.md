# Issue 507: Detect System Thread Count

## Current Behavior

Thread pool is hardcoded to 4 worker threads:
```c
ThreadPool* pool = threadpool_create(4, 64);
```

This doesn't utilize all available cores on systems with more CPUs,
and may oversubscribe on systems with fewer cores.

## Intended Behavior

Automatically detect the number of CPU cores/threads available on the
system and create an appropriate number of worker threads.

Considerations:
- Leave 1 core for main thread
- Cap at reasonable maximum (e.g., 16 threads)
- Minimum of 2 threads for any parallelism benefit

## Suggested Implementation Steps

1. Research portable thread detection:
   - Linux: sysconf(_SC_NPROCESSORS_ONLN)
   - Fallback: default to 4 threads

2. Create helper function:
   ```c
   int get_optimal_thread_count(void);
   ```

3. Place function in src/003-threadpool.c (or new utility file)

4. Update main.c to use detected count:
   ```c
   int thread_count = get_optimal_thread_count();
   ThreadPool* pool = threadpool_create(thread_count, 64);
   ```

5. Log the detected/used thread count at startup

6. Test on different systems if possible

7. Test compilation with no warnings

## Design Notes

sysconf(_SC_NPROCESSORS_ONLN) is POSIX and works on Linux.
Returns the number of processors currently online.

Formula for worker threads:
- detected_cores - 1 (leave one for main thread)
- Minimum: 2 (need at least 2 for parallelism)
- Maximum: 16 (diminishing returns beyond this)

## Success Criteria

- Thread count detected automatically
- Reasonable thread count used (2-16 range)
- Logged at startup
- Works on Linux
- Compiles with no warnings

## Related Documents

- [001-main.c](../src/001-main.c)
- [003-threadpool.h](../src/003-threadpool.h)

## Dependencies

- None (independent fix)

## Implementation Notes

Implemented automatic thread count detection using POSIX sysconf:

1. Added get_optimal_thread_count() to src/002-threadpool.c:201
   - Uses sysconf(_SC_NPROCESSORS_ONLN) to detect online processors
   - Calculates optimal count: cores - 1 (leave one for main thread)
   - Clamps result to range [2, 16]
   - Falls back to 4 if detection fails

2. Added function declaration to src/003-threadpool.h:94

3. Updated main.c to use detected count:
   - Calls get_optimal_thread_count() instead of hardcoding 4
   - Logs detected thread count at startup

Formula:
- detected_cores - 1 (reserve one for main thread)
- Minimum 2 (need parallelism benefit)
- Maximum 16 (diminishing returns)

Compilation tested: No warnings.

## Status

- [x] Complete
