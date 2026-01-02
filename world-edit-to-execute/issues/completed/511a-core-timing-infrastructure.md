# Issue 511a: Core Timing Infrastructure

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** High
**Dependencies:** 512 (threading architecture)

---

## Current Behavior

The threading system has `get_timestamp_us()` for basic timing but no structured profiling infrastructure. There are no types for storing timing samples or frames.

---

## Intended Behavior

Create the foundational types and timer functions for profiling:

1. `ProfileSample` - One named timing measurement
2. `ProfileFrame` - All samples for one frame
3. `ProfileRingBuffer` - Rolling history
4. High-resolution timer function with microsecond precision

---

## Suggested Implementation Steps

1. Create `src/render/profiler.h` with:
   - `ProfileSample` struct (name, start_us, end_us, duration_us)
   - `ProfileFrame` struct (frame_number, samples[], sample_count)
   - `ProfileRingBuffer` struct (frames[], head, count)
   - `profile_time_us()` function declaration
   - `PROFILE_BEGIN`/`PROFILE_END` macros

2. Create `src/render/profiler.c` with:
   - `profile_time_us()` implementation using CLOCK_MONOTONIC
   - Ring buffer initialization and management
   - Frame begin/end functions

---

## Acceptance Criteria

- [ ] ProfileSample, ProfileFrame, ProfileRingBuffer types defined
- [ ] profile_time_us() returns microseconds with high precision
- [ ] PROFILE_BEGIN/PROFILE_END macros work correctly
- [ ] Ring buffer stores 120 frames (2 seconds at 60 FPS)
- [ ] Frame number tracking

---

## Notes

Reuse `get_timestamp_us()` from threading.c or replace with a common implementation.
