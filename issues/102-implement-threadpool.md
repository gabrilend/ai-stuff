# Issue 102: Implement Threadpool

## Current Behavior

No threading infrastructure exists.

## Intended Behavior

A threadpool system that:
- Creates N worker threads at startup
- Maintains a thread-safe task queue
- Accepts tasks via function pointer + data pointer
- Provides wait_all synchronization primitive
- Shuts down cleanly without deadlock

## Suggested Implementation Steps

1. Create src/002-threadpool.c and src/003-threadpool.h
2. Define Task struct with function pointer and data pointer
3. Define TaskQueue struct with mutex and condition variables
4. Define ThreadPool struct containing threads and queue
5. Implement threadpool_create():
   - Allocate thread array
   - Initialize queue with mutex/condvars
   - Spawn worker threads
6. Implement worker_thread() loop:
   - Lock queue
   - Wait on condition if empty
   - Dequeue task
   - Unlock queue
   - Execute task function
7. Implement threadpool_submit():
   - Lock queue
   - Wait on condition if full
   - Enqueue task
   - Signal not_empty condition
   - Unlock queue
8. Implement threadpool_wait_all():
   - Block until all submitted tasks complete
   - Use atomic counter or completion flags
9. Implement threadpool_destroy():
   - Set shutdown flag
   - Broadcast to wake all workers
   - Join all threads
   - Free resources
10. Write simple unit test

## Related Documents

- [002-threadpool-design.md](../docs/002-threadpool-design.md)

## Technical Notes

The wait_all implementation needs careful design. Options:
1. Atomic pending task counter
2. Separate completion queue
3. Barrier synchronization

Option 1 (atomic counter) is simplest for our use case.

## Status

- [ ] Not started
