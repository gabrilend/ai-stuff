---
name: soramech thread pool report
status: research note (2026-05-19)
based-on: soramech phase 3 issues 301–317 (in progress as of 2026-05-19)
---

# soramech thread pool report

A snapshot of the soramech threading work as of 2026-05-19, written from
the perspective of Apple IIds: **what's there, what we'd lift, and what
we'd leave behind.** Apple IIds's phase 9 (threading-by-default in
65C816 assembly) and phase 11 (threading primitives in ARM assembly,
issue 1105) both build on this foundation.

Sources read for this report: soramech `docs/004-ipc-and-threading.md`
and `issues/301-...md` through `issues/317-...md`, plus the
`phase-3-progress.md` status table.

## what soramech is doing

Soramech is a dataflow editor: a user wires boxes together in a graph;
each box is a function in a chosen language (Lua, C, Bash, more on
request); values flow along the wires. Phase 3 replaces the
single-threaded Lua interpreter that walks the graph with a **C-language
thread pool** that runs box functions in parallel across worker
threads, pulling tasks from a queue and feeding values through per-port
ring buffers.

The pool is **SoraMech-owned**, written from scratch under
`libs/task-pool/`, with the 3d-rts pool at
`games/3d-rts/libs/900-task-pool.h` cited as the design reference (not
a dependency). Soramech wants full control over the spawn primitive,
the worker context, the init barrier, and iterator-pinning extensions.

Phase 3 implementation began **2026-05-12**. As of writing, the pool
skeleton + per-worker init/teardown + slot store (with large-value
heap) + spec registry + dispatch layer + priority queue + Lua/C/Bash
specs + cell-tagged ordering across parallel iterators are all
shipped. The remaining work is integration tests and retiring the
phase 2 synchronous runner.

## the architecture, top to bottom

```
   ┌──────────────────────────────────────────────────────────┐
   │  main thread (src/008-pool-runner.c)                     │
   │    1. parse map                                          │
   │    2. load+validate graph (C loader)                     │
   │    3. allocate slots for every input port                │
   │    4. pool_create(n_workers)                             │
   │    5. spec_registry_init_worker for each worker          │
   │    6. pool_init_barrier  ← blocks until workers ready    │
   │    7. push literals into input slots                     │
   │    8. spawn entry-box tasks                              │
   │    9. pool_wait_quiescent                                │
   │   10. last-run.jsonl                                     │
   │   11. pool_destroy                                       │
   └────────────────┬─────────────────────────────────────────┘
                    │
   ┌────────────────┴─────────────────────────────────────────┐
   │  pool (libs/task-pool/pool.c)                            │
   │    - N pthreads, default = sysconf(_SC_NPROCESSORS_ONLN) │
   │    - singly-linked FIFO queue, one mutex                 │
   │    - atomic active-task counter + cv for quiescence      │
   │    - one-shot init barrier (3-stage handshake)           │
   │    - TLS __thread pointer to worker_ctx_t                │
   │    - per-worker init / teardown callbacks                │
   │    - pool_spawn(pool, action_fn, arg, priority)          │
   └────────────────┬─────────────────────────────────────────┘
                    │
   ┌────────────────┴─────────────────────────────────────────┐
   │  dispatch action (src/012-dispatch.c)                    │
   │    1. read inputs via slot_peek or slot_pop              │
   │    2. resolve worker's spec handle                       │
   │    3. spec->invoke(handle, fn, in[], sizes, out_buf, ...)│
   │    4. push output to downstream slots per routing.kind   │
   │    5. spawn-on-input-ready check for each consumer       │
   └────────────────┬─────────────────────────────────────────┘
                    │
   ┌────────────────┴─────────────────────────────────────────┐
   │  slot store (src/009-slot-store.c +                      │
   │              src/015-large-value-heap.c)                 │
   │    - one ring buffer per input port (1-cell peek or      │
   │      N-cell pop, decided at compile time)                │
   │    - atomic-counter slots for iterator routing           │
   │    - per-slot atomic_flag spinlock for header mutation   │
   │    - cell tags for cross-iterator ordering               │
   │    - chunked arena allocator for variable-size payloads  │
   └──────────────────────────────────────────────────────────┘
```

## the pieces, in detail

### the pool itself (issue 301)

**File:** `libs/task-pool/pool.{c,h}`.

**Shape:**

```c
pool_t *pool_create(int n_workers);
void    pool_destroy(pool_t *p);
task_id_t pool_spawn(pool_t *p, action_fn_t *actions,
                     void **action_args, int n_actions, int priority);
void    pool_wait_quiescent(pool_t *p);
int     pool_init_barrier(pool_t *p);
void    pool_set_worker_init(pool_t *p, init_cb_t cb, void *user);
void    pool_set_worker_teardown(pool_t *p, teardown_cb_t cb, void *user);
```

**Key design choices:**

- **N workers, one queue.** All workers pull from a single
  singly-linked FIFO queue under one mutex. Cache-line contention is
  acceptable at this scale. Linear-scan insertion for priority
  ordering (strict less-than) — small queue, O(n) walk is fine.
- **Atomic active-task counter.** Each spawn increments; each task
  completion decrements; quiescence waits for it to reach zero. This
  is the only synchronization primitive needed for run termination —
  no separate "blocked tasks" structure.
- **TLS `__thread worker_ctx_t *pool_current_worker`.** Set at thread
  startup. Actions inside the pool look up their worker index and the
  back-pointer to the pool without a `pthread_self()` call.
- **One-shot init barrier.** Three-stage handshake (park workers until
  authorized, run callbacks, release all simultaneously) so workers
  cannot race with the runner before the init callbacks land.
- **Recursive `pool_spawn` from inside an action works.** The queue
  mutex re-enters cleanly. Tasks can spawn child tasks without
  deadlock.

**Tested:** 8 unit tests in `tests/301-pool-test.c`. Including
1000-task spawn-and-quiesce, 8 concurrent producer threads pushing
500 tasks each while 4 workers drain (4000 total), TLS observability,
recursive spawn (depth 10 → 11 invocations).

### tasks (issue 304)

Tasks are **ephemeral** — one invocation of one box. The task struct
is just:

```c
typedef struct {
    int  box_id;          // index into the graph's box array
} dispatch_task_t;
```

That's it. No per-task counter, no per-task input/output arrays, no
state machine. The dispatch action looks up everything it needs from
`box_runtime_state[box_id]` and from per-worker spec handles.

**This is the central design simplification.** Tasks are spawned
dynamically by the dispatch layer's "spawn on input ready" rule:
whenever a producer push completes the input set of some consumer
box, a fresh `dispatch_task_t` is allocated and queued. Tasks never
block on slots; they're spawned only when ready, run to completion,
and disappear.

There is no "blocked" state in the pool's queue. Blocked-and-waiting
isn't a concept — a not-yet-ready consumer simply hasn't had a task
spawned for it yet.

### slot store (issue 302)

**File:** `src/009-slot-store.{c,h}`, with the variable-size payload
layer in `src/015-large-value-heap.{c,h}`.

Each box input port owns one ring buffer (slot), allocated at graph
load and durable for the run. Slots come in three flavors:

1. **1-cell peek.** Used for single-push wires (literals, or wires
   from producers whose invocation count is exactly 1). The cell
   never empties; consumers `slot_peek` to read without draining.
2. **N-cell pop.** Used for multi-push wires. Producers `slot_push`;
   consumers `slot_pop` to drain one cell. Tagged slots (used
   downstream of parallel iterators) pop the lowest-tag cell first,
   preserving iteration order regardless of producer race.
3. **Atomic counter.** Used for iterator routing. The slot's cell is
   just an `atomic_uint32_t`; reads via `slot_read_inc(slot, mod)`
   atomically increment, returning the value mod the branch count.
   Parallel iterator tasks each get a unique routing index without
   coordination.

**Synchronization:** per-slot `atomic_flag` spinlock for header
mutation. No allocator-wide mutex. Pushes complete with a memory
barrier before advancing `tail` so readers that observe `head < tail`
are guaranteed to see the complete value.

**Variable-size payloads:** when a box's output size isn't known at
compile time (long LLM responses, dynamic arrays), the slot holds a
small `{size, pointer}` handle pointing into the large-value heap — a
chunked arena allocator with pointer stability across growth (a
load-bearing property: consumers can hold a pointer through many
subsequent producer allocations).

### dispatch action (issue 304)

**File:** `src/012-dispatch.c`.

One C function per task — `dispatch_action(task_ctx_t *ctx, void
*arg)`. Phases in order:

1. **Read inputs** — `slot_peek` or `slot_pop` per port, into heap
   buffers.
2. **Resolve spec handle** — `pool_current_worker->handles[spec_idx]`.
3. **Invoke** — `spec->invoke(handle, file_path, fn_name, inputs[],
   sizes[], n_inputs, out_buf, out_cap, &out_size)`.
4. **Branch-pick + push** — per `routing.kind`: plain (fan to all),
   comparator (compare to comparand → lt/eq/gt), iterator
   (`slot_read_inc(counter, N)` picks the branch), randomizer /
   weighted / distributor (kind-specific rule).
5. **Spawn-on-input-ready check** — each consumer that received a
   push gets its input set re-checked; if complete, a fresh task is
   queued.

The action returns `ACT_DONE`. The pool decrements the active-task
counter; quiescence eventually fires.

**Iterator self-re-spawn:** when an iterator's input slot still has
queued values after a task completes, the action calls
`dispatch_spawn` on itself before returning. A single push wakes the
entire chain.

### language specs (issue 303)

**File:** `langs/<name>/spec.c` per language; registry in
`src/011-spec-registry.c`.

Each language is a `.so` exporting a `lang_spec_t` symbol with
`name`, `file_ext`, `init`, `teardown`, optional `compile`, and
`invoke`. The pool runner `dlopen`s every `langs/*/spec.so` at
startup. Each worker calls each spec's `init(worker_idx)` and stashes
the opaque handle (e.g. a `lua_State`) in
`worker_ctx_t.handles[lang_idx]`.

Boxes go through `lang_spec_t::invoke`. The dispatch layer doesn't
know how to "run a Lua function" — it knows how to call
`lang->invoke(...)`.

**Three reference implementations shipped:**

- **Lua** — `lua_State` per worker. `luaL_loadfile` cached;
  `lua_pcall` per invocation.
- **C** — `dlopen` handle cache. `compile` runs
  `gcc -shared -fPIC`. `invoke` does `dlsym` + direct call.
- **Bash** — Unix domain socket to a persistent `bash-server.sh`
  subprocess per worker. Framed line protocol.

### priority queue (issue 310)

Wired through every `pool_spawn` callsite as `SM_PRIORITY_DEFAULT`
(= 1) with `SM_MAX_PRIORITY` also 1. Behaviorally identical to a
single-priority pool. Soramech ships this so future hooks land as
config changes, not refactors.

Future schema (speculative):

| use case                                  | priority |
|-------------------------------------------|----------|
| user-marked urgent boxes                  | 3        |
| iterator continuation when queue non-empty | 2        |
| default dispatch task                     | 1        |
| allocator cleanup (deferred coalescing)   | 0        |

## what blocking looks like

Soramech is explicit about this: **the worker thread is occupied for
the full duration of any blocking call in a box function.** No
delayed-spawn, no timer thread, no polling loop, no scheduler that
parks a task and wakes it at time T. The runtime deliberately has no
second concurrency model.

- 16-worker pool, 1 box sleeping 10 s → other 15 workers continue.
- 16-worker pool, 16 boxes sleeping → all workers parked.

For users who need many concurrent waits, the documented graph-level
pattern is cooperative: split into "kick off the thing" + "check
whether the thing is done," wire through an iterator with a queued
input that polls. No individual box blocks for long.

**This is a constraint, not a bug.** Apple IIds inherits it (more
below).

## the modification surfaces for Apple IIds

The soramech project is a **dataflow runtime** atop a thread pool.
Apple IIds is a **modernized GS/OS** atop a thread pool. The pool
layer is shared; the dataflow runtime above it is not.

Mapping soramech components to what Apple IIds takes:

| soramech component                | Apple IIds takes? | notes                                                          |
|-----------------------------------|-------------------|----------------------------------------------------------------|
| pool (`libs/task-pool/`)          | **yes, wholesale** | Workers, queue, init barrier, quiescence, TLS, priority. This is the lift.                                                          |
| `worker_ctx_t` + `__thread` TLS   | **yes, adapted** | Each Apple IIds worker is a CPU core (phase 11) or a 65C816 task (phase 9). TLS becomes per-task storage.                                                          |
| dispatch action (`012-dispatch`)  | **no**            | Apple IIds task semantics are different. Apple IIds tasks are GS/OS processes/threads, not graph-node invocations. No box graph, no routing kinds, no spawn-on-input-ready.        |
| slot store (`009-slot-store`)     | **no**            | Apple IIds has Toolbox state and Memory Manager handles. The "wire value" abstraction doesn't apply.                                                                       |
| large-value heap (`015-...`)      | **maybe**         | Useful if Apple IIds wants a separate variable-size pool for things like clipboard payloads. Not load-bearing.                                                                       |
| language spec system (303)        | **no**            | Apple IIds has one language: ARM assembly (per the bare-metal-core memory). No registry, no `dlopen`, no spec abstraction.                                                            |
| priority queue (310)              | **yes, used for real** | Apple IIds *does* have natural priorities: interrupt-driven audio at top, user-input handling next, default tasks, then allocator/cleanup. Phase 9 / 11 should wire actual priorities.                                                          |
| init barrier                      | **yes**           | Apple IIds wants a barrier before user tasks run, so all CPU cores have set up their per-task TLS, FPU state, etc.                                                                       |

## the translation to 65C816 (phase 9)

Soramech runs on Linux/ARM with pthreads, atomics, mutexes, and
condvars. The phase-9 staging port lands on emulated 65C816 — a
1986 CPU with **no atomics, no MMU, no preemption hardware**. The
translation:

- **Workers → 65C816 cooperative tasks.** A "worker" is a stack +
  saved-register context. The scheduler switches by saving / restoring
  registers (A, X, Y, DBR, PBR, D, S, P) on a timer interrupt.
- **Atomics → interrupt-disable critical sections.** Brief
  `SEI`/`CLI` brackets around the few-instruction critical regions.
  Cap at 50 μs to keep interrupt latency tolerable.
- **Mutexes → ticket locks via interrupt-disable.** Same shape;
  protect the queue head/tail pointers and the worker_ctx tables.
- **TLS via `__thread` → per-task storage in the task control block.**
  Each task carries a pointer to its locals; the scheduler swaps the
  current-task pointer on switch.
- **Memory barriers → no-op.** The 65C816 has no out-of-order
  execution worth worrying about; ordering is by program order.

The pool's *shape* is preserved. Apple IIds programs that call
`task_create` / `lock_acquire` / `channel_send` get the same API the
ARM port will eventually offer, just implemented behind a slower
substrate.

## the translation to ARM bare-metal (phase 11)

Phase 11's threading is more direct because we're already on ARM —
we just don't have Linux's pthreads underneath:

- **Workers → ARM cores.** The RK3568 has 4 A55 cores; each becomes
  a worker. True parallelism.
- **Atomics → LDXR/STXR + DMB.** Real hardware atomics with proper
  memory barriers.
- **Mutexes → spin-then-park.** Spin briefly (microseconds) using
  WFE/SEV; if contention persists, park the task via the scheduler.
- **TLS via `__thread` → per-CPU MSR (`tpidr_el1`) or per-task
  storage.** Standard ARM convention.
- **Init barrier:** identical shape. Each core does its bring-up
  (HAL init, MMU table install, FPU enable), increments a counter,
  spins on the release flag.

After phase 11, the pool API is **identical** to soramech's; the
implementation is in ARM assembly instead of C. The phase 9 65C816
port is the staging dialect.

## what's open and undecided

Things this report can't pin down because soramech itself hasn't
pinned them:

1. **When is the integration-tests checklist item done?** Phase 3's
   progress checklist still has unchecked items: "All 11 integration
   test maps pass," "Phase 3 demo map runs," "Phase 2 synchronous
   runner retired." Apple IIds phase 9 should wait for the
   retirement of the phase-2 runner, since that's when soramech
   declares its threading model stable.
2. **Per-allocation free in the large-value heap.** Soramech's heap
   currently grows monotonically per run. Apple IIds's runs are
   open-ended (the device runs for days), so we need real
   reclamation. Either we wait for soramech to add eager coalesce,
   or we write our own.
3. **Whether soramech's pool spawns tasks recursively in a way
   that nests deeply.** The current test goes to depth 10. Apple
   IIds workloads (UI event handlers calling Toolbox routines
   calling File Manager routines calling broker peripherals)
   may go deeper. Confirm before phase 9.
4. **Priority schema.** Soramech defaults to one priority. Apple
   IIds wants real priorities (audio interrupts, UI events,
   background compute). Need to specify the schema before phase
   9's scheduler issue 901.
5. **Cache-line alignment of `worker_ctx_t`.** Soramech doesn't
   specifically align worker contexts to cache-line boundaries.
   On 4-core ARM with shared L2, false sharing of worker contexts
   could hurt. Worth pinning in our phase 11 port even if
   soramech leaves it.

## files in soramech worth re-reading before any Apple IIds threading work

- `docs/004-ipc-and-threading.md` — the threading roadmap (Stage 1
  synchronous → Stage 2 coroutine → Stage 3 pool) and the three
  IPC options (FFI, shared memory, Unix sockets). Apple IIds doesn't
  need IPC at the worker level — but the stage progression mirrors
  our phases 4 (broker-side coordination), 6 (per-Toolbox-subsystem
  native rewrite), 9 (true threading), so it's worth understanding
  how soramech evolved.
- `issues/301-pool-lifecycle-and-worker-init.md` — the pool API
  surface and the init barrier protocol. Our 1105 inherits this
  shape directly.
- `issues/302-wire-value-slot-store.md` — even though we don't lift
  the slot store, the per-slot spinlock and the chunked arena are
  patterns worth borrowing for any Apple IIds per-port structure.
- `issues/304-task-dispatch-layer.md` — the spawn-on-input-ready
  rule and the iterator counter-tagged ordering. Apple IIds's
  Event Manager (`1104d` ported) and Window Manager (`1104f` ported)
  have analogous "dispatch when input is ready" semantics for
  event handlers.
- `issues/310-priority-queue.md` — the rationale for wiring the
  knob without using it yet. Apple IIds should *use* it, but the
  pattern of wiring future hooks is reusable.

## what to update when soramech changes

This report is a snapshot. When soramech advances:

- If phase 3 ships and the synchronous runner is retired, mark
  this report as "based-on" the next phase number and re-read.
- If a new threading primitive is added (channels, condvars,
  signal-handling), update the mapping table above and consider
  whether Apple IIds wants to lift it.
- If soramech adds a second concurrency model (timer thread,
  delayed-spawn), the "blocking" section above changes. Apple
  IIds inherits whatever soramech does here.

The memory entry `feedback_apple_iids_bare_metal_core.md`
documents the lift policy; this report is the technical companion
that says *what* gets lifted.
