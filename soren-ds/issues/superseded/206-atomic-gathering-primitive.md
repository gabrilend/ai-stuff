# 206 — Atomic gathering primitive

## Current behavior

The slot store (205) holds values in flight. The queue (204) is
the path tasks take to workers. Nothing yet connects the two — no
code decides "the box's inputs are ready, build a task." The
gathering primitive is that decision.

## Intended behavior

Per box descriptor, there is one *gathering atomic* — a single
small atomic flag. Only one thread at a time may hold it. While
holding it, the thread runs the *gathering function*:

1. Looks at every input slot of the box.
2. If every slot reports `has_value`, pops one value from each
   into the task's input array. The pops happen while the atomic
   is held, so no other thread can grab the same values for a
   parallel fire decision.
3. Reserves a unique return slot for the task (from 203's
   allocator). The return-slot reservation is also done while
   the atomic is held.
4. Releases the gathering atomic.
5. Queues the task on 204's work queue.

Step 4 releases the lock before step 5 happens, because step 5
does not depend on the lock for safety. The hot loop is steps
1–4. Step 5 is paid by the thread that already won the gathering
race, on its own time, with no other thread waiting.

The atomic is held only across steps 1–3. The actual decide-and-
pop. Construction of the task struct after the pop is unlocked.

Because every box is multi-spawn (see `012-soramech-runtime.md`),
the gathering function can be run for the same box again
immediately after the previous fire is queued — if the slots
*still* have values to pop, a second fire is queued, and so on
until the slots no longer all have values. Two fires of the same
box can be in flight on different workers simultaneously; the
unique return slots guarantee they do not conflict.

## Suggested implementation steps

1. `struct gathering` — per-box atomic, pointer to box descriptor.
2. `try_gather(box_descriptor *)` — attempt CAS on atomic; if
   won, run gathering function and queue task.
3. `gathering_function()` — the decide-and-pop loop, called
   while the atomic is held.
4. The slot-push from 205 calls `try_gather` on every downstream
   box that consumes the pushed value, after the push.

## Related documents

- `docs/003-threading-model.md` — the gathering function section.
- `docs/012-soramech-runtime.md` — what gets built on top.

## Blocked by

203, 204, 205, 207.

## Blocks

209, 211.
