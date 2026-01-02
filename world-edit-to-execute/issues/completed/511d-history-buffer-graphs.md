# Issue 511d: History Buffer and Graphs

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 511c (overlay rendering)

---

## Current Behavior

Only the latest frame's timing is available. No history or trend visualization.

---

## Intended Behavior

Rolling history with optional graph visualization:

1. Ring buffer of last 120 frames
2. Rolling average calculation
3. Min/max/spike detection
4. Optional timeline graph in overlay

---

## Suggested Implementation Steps

1. Enhance ProfileRingBuffer:
   - `profile_get_average()` - average of last N frames
   - `profile_get_min_max()` - min/max over history
   - `profile_detect_spikes()` - frames >2x average

2. Add graph rendering:
   - Small timeline at bottom of overlay
   - One pixel per frame
   - Color-coded by frame time (green/yellow/red)

3. Statistics panel:
   - "Avg: 16.2ms  Min: 15.1ms  Max: 18.4ms"
   - "Spikes: 3 in last 2s"

---

## Acceptance Criteria

- [ ] Rolling average calculated correctly
- [ ] Min/max tracking over 120 frames
- [ ] Spike detection (>2x average)
- [ ] Optional timeline graph in overlay
- [ ] Statistics text displayed

---

## Notes

Keep graph simple - just a horizontal line of colored pixels showing frame times.
