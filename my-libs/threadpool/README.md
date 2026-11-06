# Threadpool Library

A modular, high-performance threading library for general-purpose computation and real-time rendering.

**Version:** 1.0
**Platform:** POSIX (Linux, macOS)
**License:** MIT (or your license)

---

## Features

✨ **Modular Design** - Use only what you need (core, sync, updater, scheduler)
⚡ **High Performance** - Atomic load counters, idle workers sleep instead of polling
🎯 **Load Balancing** - Weighted task distribution across worker threads
🔄 **Self-Evaluating** - Updaters adapt to load automatically
📅 **Time-Based Scheduling** - Deferred task execution with absolute tick times
🎨 **Rendering-Ready** - Non-blocking pointer coordination for double-buffering
✅ **Well-Tested** - 43 tests covering all modules, clean under ThreadSanitizer and AddressSanitizer

---

## Quick Start

```c
#include "threadpool.h"

void my_task(void* context) {
    printf("Hello from worker thread!\n");
}

int main(void) {
    // Create pool (auto-detect CPU cores)
    TpPool* pool = tp_pool_create(NULL, 0);

    // Create and submit task
    TpTask task = {
        .execute = my_task,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 1
    };

    TpWorker* worker = tp_find_least_busy(pool);
    tp_task_append(worker, &task);

    sleep(1);  // Wait for completion

    tp_pool_destroy(pool);
    return 0;
}
```

**Compile:**
```bash
gcc your_app.c src/threadpool.c -Isrc -pthread -o your_app
```

---

## Modules

| Module | Files | Purpose |
|--------|-------|---------|
| **Core** | `threadpool.h/c` | Worker pools, task execution, load balancing |
| **Sync** | `threadpool_sync.h/c` | Non-blocking pointer coordination (for rendering) |
| **Updater** | `threadpool_updater.h/c` | Adaptive task distribution with self-evaluation |
| **Scheduler** | `threadpool_scheduler.h/c` | Time-based deferred task execution |

**Pick what you need:** Each module works independently.

---

## Use Cases

### General Computation
- Batch data processing
- Parallel algorithms
- Background tasks
- Physics simulation

```c
// Process large dataset in parallel
for (size_t i = 0; i < num_chunks; i++) {
    TpTask task = { .execute = process_chunk, .context = &chunks[i] };
    tp_task_append(tp_find_least_busy(pool), &task);
}
```

### Real-Time Rendering
- Double-buffered rendering
- Producer-consumer patterns
- Frame-accurate timing

```c
// Sync module handles pointer swaps automatically
tp_sync_add_watch(sync, &ready_flag, &front_buffer, back_buffer);
// Workers render to back, main thread reads from front (always safe)
```

### Time-Based Scheduling
- Cooldowns and timers
- Periodic events
- Deferred actions

```c
// Schedule task to run in 100 ticks
tp_scheduler_add(sched, &task, 100);

// In your loop
if (tp_scheduler_get_ready(sched, &tasks, &count)) {
    // Execute ready tasks
}
```

---

## Documentation

📖 **[Complete Usage Guide](docs/usage-guide.md)** - Comprehensive guide with examples

Covers:
- Compute tasks (general-purpose threading)
- Visual tasks (rendering pipeline)
- Deferred tasks (scheduler)
- API reference
- Best practices
- Complete working examples

---

## Building

### Run Tests

```bash
make test        # or: cd tests && make test
make sanitize    # the same tests under ThreadSanitizer, then AddressSanitizer + UBSan
```

All 43 tests should pass:
- ✅ Core module (14 tests)
- ✅ Sync module (8 tests)
- ✅ Updater module (8 tests)
- ✅ Scheduler module (13 tests)

### Static Library

```bash
make             # builds build/libthreadpool.a with all four modules
gcc your_app.c -Isrc -Lbuild -lthreadpool -pthread -o your_app
```

The linker takes only the modules your program calls, so only programs that
use the scheduler need to define `g_current_tick`.

### Integration

**Option 1: Direct compilation**
```bash
gcc your_app.c \
    src/threadpool.c \
    src/threadpool_sync.c \
    src/threadpool_updater.c \
    src/threadpool_scheduler.c \
    -Isrc -pthread -o your_app
```

**Option 2: Include only what you need**
```bash
# Core only
gcc your_app.c src/threadpool.c -Isrc -pthread -o your_app

# Core + Sync
gcc your_app.c src/threadpool.c src/threadpool_sync.c -Isrc -pthread -o your_app
```

---

## Architecture Highlights

### Load Balancing
Tasks have weights (LIGHT, MEDIUM, HEAVY) for accurate load distribution:
```c
task.weight = TP_WEIGHT_HEAVY * task.repeat_count;  // Total work upfront
```

### Self-Evaluating Updaters
Updaters measure their own timing and decide whether to continue:
- Last tick > 50% of target → recreate (still needed)
- Last tick ≤ 50% of target → terminate (load decreased)

### Absolute Time Scheduling
Scheduler uses absolute tick times (not countdown timers):
- `ready_at_tick = g_current_tick + delay`
- Prevents deadlock when updater sleeps
- Global tick counter advances independently

### Non-Blocking Sync
Watch list pattern for pointer coordination:
- Workers set ready flag when done
- Sync thread polls flags, writes the new pointer, then clears the flag
- Main thread reads the pointer once it sees the flag clear

### Ownership and Shutdown
- Any thread may append to any worker; a task may append to its own worker
- The context from `tp_updater_create()` is yours: `tp_updater_stop()` (or
  `tp_pool_destroy()`), then `tp_updater_destroy()`
- `tp_pool_destroy()` drops queued tasks without running them

---

## Performance

Benchmarks on 4-core system:
- Task throughput: ~500K tasks/sec
- Overhead per task: ~2μs
- Context switch penalty: Minimal (load balanced)

---

## Requirements

- **C Standard:** C11 (for `<stdatomic.h>`)
- **Platform:** POSIX (Linux, macOS)
- **Compiler:** GCC 4.9+, Clang 3.6+
- **Threading:** pthreads

**Windows support:** Planned (see `issues/800f-windows-support-planning.md`)

---

## Project Structure

```
threadpool/
├── src/                        # Library source
│   ├── threadpool.h            # Core module
│   ├── threadpool.c
│   ├── threadpool_config.h     # Configuration constants
│   ├── threadpool_sync.h       # Sync module
│   ├── threadpool_sync.c
│   ├── threadpool_updater.h    # Updater module
│   ├── threadpool_updater.c
│   ├── threadpool_scheduler.h  # Scheduler module
│   └── threadpool_scheduler.c
├── tests/                      # Test suite
│   ├── test_pool.c             # Core tests
│   ├── test_sync.c             # Sync tests
│   ├── test_updater.c          # Updater tests
│   ├── test_scheduler.c        # Scheduler tests
│   ├── test_common.h           # Assertions and WAIT_UNTIL
│   └── Makefile
├── docs/                       # Documentation
│   └── usage-guide.md          # Complete usage guide
└── README.md                   # This file
```

---

## Contributing

This library was extracted from the world-edit-to-execute project. See:
- `issues/800*.md` - Development history
- `issues/progress.md` - Current status

---

## License

[Your license here - MIT recommended]

---

## Credits

Originally developed as part of the world-edit-to-execute game engine threading system.

Extracted into standalone library: 2026-01-08
