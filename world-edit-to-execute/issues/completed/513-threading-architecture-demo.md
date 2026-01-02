# Issue 513: Threading Architecture Demo

**Phase:** 5 - Rendering
**Type:** Demo / Visualization
**Priority:** Medium
**Dependencies:** 512f (v2 threading migration complete)

---

## Current Behavior

The phase demos do not include a dedicated threading visualization. The v2 threading
architecture is exercised by the render demo but its internals are invisible to the user.

## Intended Behavior

A standalone demo section that visualizes the v2 threading architecture in real-time:

1. **Thread visualization** - Show each worker thread's ring buffer state
2. **Task flow** - Visualize tasks being appended, executed, and completed
3. **Load balancing** - Display weighted task counts per worker
4. **Sync watch list** - Show entries being added and swapped
5. **Updater behavior** - Demonstrate self-hosted updater and helper spawning
6. **Interactive controls** - Allow user to inject tasks, adjust worker count, etc.

## Suggested Implementation Steps

### Step 1: Create demo framework

Create `src/render/demo_threading.c` with:
- Dedicated window or panel for threading visualization
- Text-based display (no complex graphics needed)
- Real-time updates at ~10Hz refresh

### Step 2: Worker ring buffer visualization

For each worker, display:
```
Worker 0 [load: 15] [████░░░░░░░░░░░░] start=3 end=7
  [3] render_task (weight=5, repeat=1)
  [4] compute_task (weight=10, repeat=3)  <-- executing
  [5] sleep_task (weight=0)
  [6] (empty)

Worker 1 [load: 5] [██░░░░░░░░░░░░░░] start=0 end=2
  [0] render_task (weight=5, repeat=1)  <-- executing
  [1] (empty)
```

### Step 3: Sync watch list visualization

Display watch list entries:
```
Sync Watch List (3 entries, 47 swaps performed)
  [0] ready=false  target=0x7f2a...  source=0x7f3b...
  [1] ready=TRUE   target=0x7f4c...  source=0x7f5d...  <-- swapping
  [2] ready=false  target=0x7f6e...  source=0x7f7f...
```

### Step 4: Updater visualization

Show updater state:
```
Primary Updater (on worker 0)
  Last tick: 1523 us (target: 10000 us)
  Tasks distributed this tick: 12
  Helpers active: 0

  [If overloaded:]
  OVERLOAD DETECTED: 12500 us > 10000 us
  Spawning helper for partition [50, 100)
```

### Step 5: Interactive controls

Implement controls (keyboard or on-screen):

| Control | Action |
|---------|--------|
| `+` / `-` | Add/remove worker threads (if supported) |
| `T` | Inject test task to least-busy worker |
| `H` | Inject heavy task (weight=20, repeat=10) |
| `S` | Inject sleep task |
| `U` | Toggle updater active/paused |
| `1-9` | Set task injection rate (tasks/sec) |
| `R` | Reset statistics |

### Step 6: Statistics panel

Display aggregate stats:
```
Threading Statistics
--------------------
Workers: 4 (auto-detected 16 cores)
Total load: 45
Tasks executed: 12,847
Tasks/sec: 892.3
Avg task duration: 0.34 ms

Sync Statistics
---------------
Watch entries: 3 / 2048
Swaps performed: 8,421
Idle cycles: 1,203
```

### Step 7: Demonstrate v2-specific features

Explicitly demonstrate (with visual feedback):

1. **Ring buffer wrap-around** - Show relocate_task compacting the buffer
2. **Load balancing** - Inject tasks and watch them route to least-busy worker
3. **Repeat count** - Show task executing multiple times before completion
4. **on_complete callback** - Visual indicator when callback fires
5. **Self-hosted updater** - Show updater task in worker's ring buffer
6. **Helper spawning** - Artificially trigger overload to spawn helpers
7. **Watch list parallel scan** - Show multiple entries resolving simultaneously

### Step 8: Integration with phase demo

Add to `run-demo.sh` or create `issues/completed/demos/run_threading_demo.sh`:
- Option to run standalone
- Option to integrate as overlay in render demo (F4 key?)

---

## v2 Features to Demonstrate (NOT v1)

| Feature | Description | How to Visualize |
|---------|-------------|------------------|
| Ring buffer tasks | Function pointers in circular buffer | Show buffer with start/end pointers |
| Weight-based load | Tasks have weight for balancing | Display per-worker weighted sum |
| Least-busy selection | O(N) scan for task routing | Highlight selected worker on inject |
| repeat_count | Tasks can run multiple times | Show countdown as task executes |
| on_complete callback | Called when repeat_count reaches 0 | Flash indicator on completion |
| Updater as task | Runs on worker, not separate thread | Show updater in worker's task list |
| Helper spawning | Auto-spawn when overloaded | Trigger overload, show helper appear |
| Watch list sync | Parallel pointer swaps | Show entries resolving independently |
| Relocate task | Compacts ring buffer | Trigger wrap-around, show compaction |

---

## Acceptance Criteria

- [x] Demo window displays all worker ring buffers
- [x] Watch list visualization updates in real-time
- [x] Updater state and timing displayed
- [x] User can inject tasks via keyboard
- [x] Statistics panel shows throughput metrics
- [x] At least 5 v2 features demonstrated visually
- [x] Demo runs standalone without render demo
- [x] Demo can overlay on render demo (F5 key)

---

## Files to Create

| File | Purpose |
|------|---------|
| `src/render/demo_threading.c` | Main demo implementation |
| `src/render/demo_threading.h` | Public API for integration |
| `issues/completed/demos/run_threading_demo.sh` | Standalone runner |

---

## Notes

The goal is educational - users should understand HOW v2 threading works by watching it.
Text visualization is preferred over graphics for clarity and simplicity.

Key insight: The v2 architecture is fundamentally different from v1:
- v1: Workers are "slot processors" with fixed ranges
- v2: Workers are "task executors" running any function pointer

This demo should make that distinction viscerally clear.

---

## Implementation Notes

### Completed (2026-01-02)

Implemented threading architecture demo with comprehensive v2 visualization:

**Files created:**
- `src/render/demo_threading.h` - Public API with 12 functions
- `src/render/demo_threading.c` - 540 lines of visualization code
- `issues/completed/demos/run_phase5.sh` - Standalone runner script

**Visualization panels implemented:**
1. **Worker ring buffers** - Shows load, start/end pointers, task names with weights
2. **Updater panel** - Primary/helper type, last tick duration, overload detection
3. **Sync watch list** - Entry count, ready flags, swap counter
4. **Statistics panel** - Worker count, load, executed tasks, throughput
5. **Throughput graph** - 60-sample rolling history with color gradient
6. **Controls panel** - Key hints for all interactive features

**v2 features demonstrated:**
- Ring buffer task lists with start/end pointer visualization
- Weight-based load balancing (tasks routed to least-busy worker)
- Task repeat_count displayed in worker panel
- Self-hosted updater shown as "PRIMARY" with timing info
- Helper spawning indicator on overload (> 5000us)
- Watch list parallel scan with ready flag states
- Task identification by function pointer (updater, helper, test, heavy, sleep)

**Interactive controls:**
- F5: Toggle demo overlay (integrated with render demo)
- T/H/S: Inject test/heavy/sleep tasks
- 1-9: Set auto-injection rate (x10 tasks/sec)
- R: Reset statistics
- Up/Down: Select worker for highlighting

**Integration:**
- Updated run-demo.sh with Phase 5 selection
- Updated COMPLETED_PHASES to 5
- Demo overlays on render demo when F5 pressed
