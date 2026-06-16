# 310 — RAM transcript ring

## Current behavior

Soramech proper writes a detailed JSONL transcript of every box
firing, every wire push, every task lifecycle event to disk for
debugging. On a handheld with battery-budgeted flash writes that
approach is exactly the wrong shape; the soramech runtime doc
calls it out in the deferred-work doc. But the panic handler
still needs *some* recent history to dump when something goes
wrong, and the developer attached to the CDC-ACM stream during
normal operation benefits from a live event feed.

## Intended behavior

A fixed-size in-RAM ring buffer records the last N runtime
events. The events match the soramech proper schema so
downstream tools that already eat that format work unchanged:

- `task_submit` — task id, box descriptor name, queue.
- `task_start` — task id, worker id.
- `task_end` — task id, duration in microseconds, output size.
- `push` — from_box, to_box, slot id, result string (`"ok"` or
  a short skip reason).
- `slot_alloc` — startup-time enumeration of slots.
- `run_start` / `run_end` — once per map run.

The ring is a flat array of `transcript_event_t` records, each
fixed-size (no variable-length payloads — long strings get
truncated with an ellipsis byte). A producer-claim counter
advances atomically per write; old entries are overwritten in
place when the ring wraps.

Two consumers read from the ring:

- **Live stream.** A background task picks events from the ring
  and writes them through the CDC-ACM stream as JSON-Lines text
  for any laptop terminal currently attached. The live stream
  is optional — a no-op when no CDC-ACM consumer is connected.
- **Panic dump.** The panic handler (105) walks the ring from
  the oldest still-resident entry to the newest and dumps each
  through CDC-ACM as part of its crash report. The dump fires
  even if the live stream wasn't running.

The ring is sized so that the live stream comfortably keeps up
with the runtime under normal load — a few thousand entries is
plenty for the launch system.

## Suggested implementation steps

1. `struct transcript_event_t` — fixed-size record.
2. `struct transcript_ring_t` — array + counter + size.
3. `transcript_emit(event)` — atomic increment, store.
4. `transcript_drain_to_serial()` — the live-stream task body.
5. `transcript_dump_to_serial()` — the panic-handler hook.

## Supersedes the phase 1 SD-card debug log

Phase 1 issue `110g-sd-card-debug-log.md` (and its implementation
in `src/017-debug-log.c`) is a phase 1 expedient that writes a
diagnostic log to a reserved region of the microSD card during
bring-up. That mechanism exists because phase 1 hardware tests
deliberately do not connect the device to anything with data
worth losing over USB-C, so CDC-ACM-only diagnostic output goes
nowhere when no host is attached.

The RAM transcript ring this issue builds subsumes that role for
the long-term: the same "last N events leading up to a panic,"
but kept in RAM with no SD wear and no fixed region of removable
media consumed for kernel logs. When this issue lands, 110g's
SD-card region and `src/017-debug-log.c` should both be removed.

## Related documents

- `docs/012-soramech-runtime.md` — RAM transcript ring section.
- `/home/ritz/programs/sora/soramech/docs/004-runtime.md` — the
  parent project's JSONL transcript schema.

## Blocked by

105, 108, 110.

## Blocks

311 (the demo watches the live stream to verify the run).
