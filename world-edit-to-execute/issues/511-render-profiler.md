# Issue 511: Render System Profiler

**Phase:** 5 - Rendering
**Type:** Implementation (Developer Tool)
**Priority:** Medium
**Dependencies:** 508a (threading infrastructure)

---

## Current Behavior

The threading system has basic statistics (`swaps_performed`, `idle_cycles`) but no
timing data. There's no way to:

- Measure per-frame timing breakdown
- Identify bottlenecks between threads
- Track worker utilization
- Visualize pipeline stalls
- Detect lock contention

Debugging performance issues requires manual printf timing, which is imprecise and
invasive.

---

## Intended Behavior

A built-in profiler that provides:

1. **Per-thread timing** - How long each stage takes per frame
2. **Pipeline visualization** - When threads are active/idle/blocked
3. **Statistics dashboard** - Live overlay showing performance metrics
4. **History/graphs** - Rolling averages and spike detection
5. **Export capability** - Dump profile data for offline analysis

### Example Output (Overlay)

```
┌─ Render Profiler ─────────────────────────────┐
│ Frame: 3847      FPS: 60.1      dt: 16.6ms    │
├───────────────────────────────────────────────┤
│ Updater:    0.12ms  ████░░░░░░░░░░░░░░░  1%   │
│ Worker 0:   2.34ms  ████████████░░░░░░░ 14%   │
│ Worker 1:   2.18ms  ███████████░░░░░░░░ 13%   │
│ Sync:       0.08ms  ███░░░░░░░░░░░░░░░░  0%   │
│ Draw:       4.21ms  █████████████████░░ 25%   │
│ Lua:        1.45ms  ████████░░░░░░░░░░░  9%   │
├───────────────────────────────────────────────┤
│ Slots: 4095/4096   Swaps: 2/frame             │
│ Lock waits: 0      Stalls: 0                  │
└───────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Timing Infrastructure

```c
/* {{{ ProfileSample - one timing measurement */
typedef struct profile_sample {
    const char* name;       /* "Worker 0", "Sync", etc. */
    double start_us;        /* Microseconds since program start */
    double end_us;
    double duration_us;
} ProfileSample;
/* }}} */

/* {{{ ProfileFrame - all samples for one frame */
typedef struct profile_frame {
    unsigned int frame_number;
    double frame_start_us;
    double frame_end_us;
    ProfileSample samples[32];  /* Up to 32 named regions per frame */
    int sample_count;
} ProfileFrame;
/* }}} */

/* {{{ ProfileRingBuffer - rolling history */
typedef struct profile_ring {
    ProfileFrame frames[120];   /* 2 seconds at 60 FPS */
    int head;
    int count;
} ProfileRingBuffer;
/* }}} */
```

### 2. High-Resolution Timer

```c
#include <time.h>

/* {{{ profile_time_us - microseconds since epoch */
static inline double profile_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000000.0 + ts.tv_nsec / 1000.0;
}
/* }}} */

/* {{{ Convenience macros */
#define PROFILE_BEGIN(name) \
    double _prof_start_##name = profile_time_us()

#define PROFILE_END(name) \
    profile_record(#name, _prof_start_##name, profile_time_us())
/* }}} */
```

### 3. Thread-Safe Recording

```c
/* {{{ Thread-local sample buffer */
static __thread ProfileSample tls_samples[16];
static __thread int tls_sample_count = 0;

/* {{{ profile_record - add sample to thread-local buffer */
void profile_record(const char* name, double start, double end) {
    if (tls_sample_count >= 16) return;
    ProfileSample* s = &tls_samples[tls_sample_count++];
    s->name = name;
    s->start_us = start;
    s->end_us = end;
    s->duration_us = end - start;
}
/* }}} */

/* {{{ profile_flush - merge thread samples into frame */
void profile_flush(ProfileFrame* frame) {
    /* Called once per frame by main thread */
    /* Merges all thread-local buffers into frame */
}
/* }}} */
```

### 4. Overlay Rendering

```c
/* {{{ profile_draw_overlay */
void profile_draw_overlay(void) {
    if (!g_profile_visible) return;

    ProfileFrame* frame = profile_get_latest();
    if (!frame) return;

    int x = 10, y = GetScreenHeight() - 200;
    int w = 350, h = 180;

    /* Background */
    DrawRectangle(x, y, w, h, (Color){0, 0, 0, 200});

    /* Header */
    DrawText(TextFormat("Frame: %u  FPS: %.1f  dt: %.1fms",
             frame->frame_number,
             1000000.0 / (frame->frame_end_us - frame->frame_start_us),
             (frame->frame_end_us - frame->frame_start_us) / 1000.0),
             x + 5, y + 5, 12, WHITE);

    /* Per-thread bars */
    int bar_y = y + 25;
    for (int i = 0; i < frame->sample_count; i++) {
        ProfileSample* s = &frame->samples[i];
        float pct = s->duration_us / 16666.0f;  /* % of 60 FPS frame */
        int bar_w = (int)(pct * 200);

        DrawText(s->name, x + 5, bar_y, 10, LIGHTGRAY);
        DrawRectangle(x + 80, bar_y, bar_w, 12, GREEN);
        DrawText(TextFormat("%.2fms", s->duration_us / 1000.0),
                 x + 290, bar_y, 10, WHITE);

        bar_y += 16;
    }
}
/* }}} */
```

### 5. Integration Points

Add profiling calls to existing code:

```c
/* In worker_loop() */
PROFILE_BEGIN(worker);
pool->process_fn(ctx, &input_copy, &buf->output);
PROFILE_END(worker);

/* In sync_loop() */
PROFILE_BEGIN(sync);
/* ... swap logic ... */
PROFILE_END(sync);

/* In main loop */
PROFILE_BEGIN(lua);
lua_pcall(g_lua, ...);
PROFILE_END(lua);

PROFILE_BEGIN(draw);
BeginDrawing();
/* ... */
EndDrawing();
PROFILE_END(draw);
```

### 6. Toggle and Controls

```c
/* F3 to toggle profiler overlay */
if (IsKeyPressed(KEY_F3)) {
    g_profile_visible = !g_profile_visible;
}

/* F4 to dump current frame to file */
if (IsKeyPressed(KEY_F4)) {
    profile_dump_to_file("profile_dump.txt");
}
```

---

## Files to Create/Modify

- `src/render/profiler.h` - Types and API
- `src/render/profiler.c` - Implementation
- `src/render/main.c` - Integration and overlay
- `src/render/threading.c` - Add timing calls
- `src/render/run` - Add profiler.c to SOURCES

---

## Acceptance Criteria

- [ ] High-resolution timer (microsecond precision)
- [ ] Per-thread timing for Updater, Workers, Sync, Draw, Lua
- [ ] Thread-safe sample recording
- [ ] Rolling 2-second history buffer
- [ ] Overlay rendering with bar graphs
- [ ] F3 toggles overlay visibility
- [ ] F4 dumps profile to file
- [ ] No performance impact when profiler disabled
- [ ] Works correctly with 2-4 workers

---

## Sub-Issues (if needed)

| ID | Description | Priority |
|----|-------------|----------|
| 511a | Core timing infrastructure | High |
| 511b | Thread-safe recording | High |
| 511c | Overlay rendering | Medium |
| 511d | History buffer and graphs | Medium |
| 511e | File export | Low |

---

## Notes

### Performance Considerations

- Profiling should have <1% overhead when enabled
- When disabled, should compile to no-ops if possible
- Use thread-local storage to avoid lock contention
- Ring buffer avoids allocations during runtime

### Future Extensions

- GPU timing (requires OpenGL queries)
- Network/packet timing
- Memory allocation tracking
- Flame graph export (Chrome tracing format)
- Remote profiling (send data over network)

---

## Related Documents

- `docs/render-architecture.md` - Threading model being profiled
- `issues/508a-threading-infrastructure.md` - What we're measuring
- `src/render/threading.h` - Current statistics tracking
