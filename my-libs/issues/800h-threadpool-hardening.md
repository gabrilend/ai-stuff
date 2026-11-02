# Issue 800h: Threadpool Hardening (Races, Lifecycle, Sanitizer-Clean Tests)

**Phase:** 8 (Infrastructure Libraries)
**Type:** Bug Fix / Implementation
**Priority:** High
**Dependencies:** 800a, 800b, 800c, 800d, 800g
**Parent:** 800-threadpool-library-extraction.md

---

## Current Behavior

The library builds and its 24 tests pass, but run under ThreadSanitizer the
tests report 46 data races, and reading the code turns up these faults:

- **Core ring buffer:** `start_ptr`/`end_ptr` are plain `size_t` shared by the
  worker and every producer with no lock and no atomics. Two threads appending
  to one worker at once (the main thread and an updater, say) can write the
  same slot or lose a task. The worker also runs a task in place through a
  pointer into the ring, so anything that rewrites the slot under it corrupts
  the running task.
- **Auto-relocation:** `tp_task_append` inserts a relocate task when the ring
  is nearly full. It never adds that task's weight to `num_tasks` but the
  worker subtracts it when done, so the unsigned load counter can wrap to ~4
  billion. The relocate copies tasks to index 0, which can overwrite the slot
  the worker is still running and then "advance" past the wrong task. In a
  modulo ring the relocation is not needed at all: the ring wraps by itself.
- **Done tasks:** a task appended with `repeat_count <= 0` is skipped without
  releasing its weight, so the load never returns to zero.
- **Pool creation:** if a `pthread_create` fails the pool is returned anyway and
  `tp_pool_destroy` later joins a thread that never existed. A
  `task_list_size` of 0 or 1 builds a ring that can hold nothing.
- **Idle workers** poll with `usleep(100)`: ten thousand wakeups a second per
  idle worker, in every program that links the library.
- **Sync module:** prints to stdout from the sync thread whether or not a
  `log_fn` is set (the config's `log_fn` is not even stored), its statistics
  are plain integers read across threads, and `tp_sync_create(NULL)` fails
  where the core treats NULL as "defaults". `%lu` is used for `uint64_t`.
- **Updater module:** a primary that decides to terminate `free()`s the
  caller's context, so the caller's `tp_updater_destroy()` is a double free;
  the "spawn replacement" branch re-queues the same context but still
  decrements the active count, so the count drifts low; there is no way to
  stop an updater short of destroying the pool; `last_tick_duration_us` is
  read across threads without atomics.
- **Scheduler module:** the condition variable waits on the wall clock but the
  timeout is computed on the monotonic clock, so `tp_scheduler_sleep_ticks`
  returns at once instead of sleeping; there is no loop for spurious wakeups;
  a task added between the caller's "earliest" check and the sleep is slept
  past; `ticks * 16ms` can overflow; the tick length is hard-coded; and the
  ready buffer is one static global shared by every scheduler, so two
  schedulers overwrite each other's results.
- **Tests:** timing-based (`usleep` then assert), with races of their own,
  GCC-only nested functions, the updater tests leak or leave contexts
  dangling, and four compiled test binaries are committed to git.

## Intended Behavior

The same API and the same design (rings, weights, self-evaluating updaters,
absolute-tick scheduler), but correct under concurrency and with clear
ownership, proven by a test suite that is clean under ThreadSanitizer and
AddressSanitizer + UBSan with gcc and clang.

## Suggested Implementation Steps

1. Core: guard each worker's ring with a mutex; the worker copies the task out
   under the lock and runs the copy, keeping its slot reserved until done;
   idle workers sleep on a condition variable signalled by append and
   shutdown; remove auto-relocation and make `tp_relocate_task` a safe,
   optional compaction; release the load of skipped tasks; fail
   `tp_pool_create` cleanly; add `tp_worker_queued()`.
2. Sync: store `log_fn`, log only through it, atomic statistics, NULL config
   means defaults, document the handoff rule (read the target after the flag
   clears).
3. Updater: the caller owns the primary context; add `tp_updater_stop()` that
   waits for the primary and its helpers; fix the active count; atomic timing.
4. Scheduler: monotonic condition variable, generation counter for wakeups,
   clamp sleeps to the earliest task, configurable `tick_us`, per-scheduler
   ready buffer, NULL config means defaults.
5. Tests: shared `test_common.h` with `WAIT_UNTIL`, new tests for every fault
   above, `make tsan` / `make asan` / `make sanitize`, binaries in `build/`.
6. Top-level `make` builds `build/libthreadpool.a`; `make test` runs the suite.

## Acceptance Criteria

- [x] `make test` passes with gcc and clang
- [x] `make tsan` reports no data races; `make asan` reports no leaks or errors
- [x] Many threads appending to one worker lose and repeat no task
- [x] Load returns to exactly zero after every test's work drains
- [x] A small ring wraps thousands of times with no relocation
- [x] `tp_updater_stop()` ends the primary and its helpers; the caller's
      context is never freed by the library
- [x] `tp_scheduler_sleep_ticks()` sleeps for its ticks and wakes on add
- [x] No compiled binaries in git

---

## What Happened

**Date:** 2026-11-02

Built as described above. Every public function keeps its name and arguments;
`tp_updater_start` now returns `bool` (callers that ignore it still compile).
New: `tp_worker_queued()`, `tp_updater_stop()`, `TpSchedulerConfig.tick_us`.

### Decisions

- **Mutex per worker, not a lock-free ring.** Producers are many (main thread,
  updaters on other workers, a task's own on_complete), so a single-producer
  ring is not enough, and a correct multi-producer lock-free ring that also
  lets a task stay in place across repeats is a lot of subtle code for a
  critical section a few instructions long. The worker never holds the lock
  while a task runs, so a task can append to its own worker.
- **Relocation removed from append.** A modulo ring never runs off its end, so
  the only thing relocation still did was drop `tp_sleep_task` placeholders.
  `tp_relocate_task` keeps that job as an explicit, safe call (it skips the
  running slot), and append no longer inserts it. This replaces 800a's
  "relocation triggers at threshold" criterion: nothing needs to trigger.
- **Idle workers sleep on a condition variable.** Same latency or better than
  the 100us poll, and no CPU burned while idle.
- **Shutdown checks between repeats.** A task with `repeat_count = INT16_MAX`
  no longer holds `tp_pool_destroy` for 32767 runs; a task cut short gets no
  `on_complete` (documented).
- **The caller owns the primary updater context.** The old test comment said
  "the updater task owns it and will free it", but the task only freed it on
  one branch, so whether a caller could free it depended on timing. Now the
  library never frees what it did not allocate; helpers, which it allocates,
  free themselves.
- **Scheduler stays single-consumer.** `tp_scheduler_get_ready()` keeps its
  signature (it is the updater's task-source callback), so its buffer still
  lives until the next call. It is now per scheduler and sized at creation,
  and the header says one thread should take from a scheduler.
- **`g_current_tick` stays an extern the application defines**, as 800g
  designed. The new static archive means programs that never call the
  scheduler do not have to define it.
- **Sync swap stays a plain pointer write**, with the handoff rule documented
  and the tests following it; changing `void**` to an atomic pointer type
  would break every caller for no gain when the flag already orders it.

### Test Results

43 tests (core 14, sync 8, updater 8, scheduler 13), up from 24. All pass with
gcc and clang, under `make tsan` (no races, was 46) and `make asan` (no leaks
or errors), and 40 repeated plain runs and 8 repeated TSan runs had no
failures. Run against the old core, the new core tests fail three ways
(tiny ring accepted, load never released, lost or repeated tasks with many
producers); the new scheduler sleep test shows the old sleep returning in
38us instead of 80ms.
