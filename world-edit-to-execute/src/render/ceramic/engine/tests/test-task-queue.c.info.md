# test-task-queue.c

The kept engine copy's queue under load. Built and run by
`run-engine-tests.sh`; exits 0 when every check passes.

- **Default ring:** four outside threads hand in 800,000 tasks (single,
  `cera_pool_push_many`, open batches), and a quarter of them hand in a
  child from a worker. Every task must run exactly once, and the pool must
  stop by itself.
- **Seeded before release:** 1000 tasks all run once; the pool stops with
  no outside submitter.
- **A 16-slot ring:** the same load, with the ring full nearly all the time
  (outside threads wait for room, workers run tasks themselves). Still
  exactly once, still stops.

It also ran clean under ThreadSanitizer (clang), 2026-09-25.
