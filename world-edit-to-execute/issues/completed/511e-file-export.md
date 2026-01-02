# Issue 511e: File Export

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Low
**Dependencies:** 511a (core timing)

---

## Current Behavior

No way to save profiling data for offline analysis.

---

## Intended Behavior

Export profile data to a text file:

1. F4 key triggers dump
2. Human-readable format
3. All samples from ring buffer
4. Timestamp and summary statistics

---

## Suggested Implementation Steps

1. Add `profile_dump_to_file()`:
   - Write to "profile_dump.txt" (or timestamped)
   - Format: one line per sample with frame#, name, start, end, duration

2. File format:
   ```
   # Profile Dump - 2025-12-31 12:34:56
   # Frames: 120, Avg: 16.2ms, Min: 15.1ms, Max: 18.4ms

   FRAME 3847
     Updater   0.00  0.12  0.12ms
     Worker0   0.12  2.46  2.34ms
     Worker1   0.15  2.33  2.18ms
     Sync      2.48  2.56  0.08ms
     Draw      2.56  6.77  4.21ms
     Lua       6.77  8.22  1.45ms

   FRAME 3848
     ...
   ```

3. Integration:
   - F4 key in main.c calls profile_dump_to_file()
   - Print confirmation message to console

---

## Acceptance Criteria

- [ ] F4 triggers file export
- [ ] File contains all frames in ring buffer
- [ ] Human-readable format with timestamps
- [ ] Summary statistics at top
- [ ] Confirmation printed to console

---

## Notes

Future extension: Chrome tracing JSON format for flame graphs.
