# Issue 511b: Thread-Safe Recording

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** High
**Dependencies:** 511a (core timing)

---

## Current Behavior

No mechanism exists to collect timing samples from multiple worker threads safely.

---

## Intended Behavior

Thread-local storage for collecting samples without lock contention:

1. Each thread has its own sample buffer
2. Main thread merges all buffers at frame end
3. No locks during normal operation
4. Clean reset at frame boundaries

---

## Suggested Implementation Steps

1. Add to `profiler.c`:
   - Thread-local `tls_samples[]` buffer (16 samples per thread)
   - Thread-local `tls_sample_count` counter
   - `profile_record()` - add sample to thread-local buffer
   - `profile_flush()` - merge all thread samples into frame

2. Worker registration:
   - `profile_register_thread()` - call from each worker at startup
   - `profile_get_thread_samples()` - retrieve samples from specific thread

3. Frame boundary handling:
   - `profile_begin_frame()` - set frame start time, increment frame number
   - `profile_end_frame()` - collect all thread samples, finalize frame

---

## Acceptance Criteria

- [ ] Thread-local sample buffer (16 samples per thread)
- [ ] profile_record() adds samples without locks
- [ ] profile_flush() merges samples from all threads
- [ ] profile_begin_frame() and profile_end_frame() work correctly
- [ ] No data races with 4 worker threads

---

## Notes

Use `__thread` keyword for thread-local storage (GCC/Clang).
