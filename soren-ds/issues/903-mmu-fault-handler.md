# 903 — MMU fault handler

## Current behavior

The MMU (901) and per-app regions (902) are in place but a bad
access produces an exception the kernel doesn't yet handle. The
exception goes to 105's general panic stub, which halts the
device. We want a smaller-scope response: kill the app, leave
the kernel and the other apps running.

## Intended behavior

A specialised handler for MMU data and prefetch aborts. The
handler:

1. Captures the faulting program counter and the offending
   address from the MMU's fault registers.
2. Reads the current worker's `current_app` field (902) to
   identify which app the fault belongs to.
3. Captures the most recent transcript ring entries (310) for
   the app — what task was running, what box was being fired,
   what values were in flight.
4. Calls into 904's app fault recovery path with all of that
   context.

If the fault is in kernel code rather than app code (the
`current_app` field is null), the handler still escalates to
the general panic stub — the kernel itself misbehaving is not
the kind of fault we recover from in this phase.

The handler runs in a special exception context with its own
small stack. The stack is sized for one handler's worth of work
— the recovery path itself runs in the normal worker context
once dispatched.

## Suggested implementation steps

1. `mmu_fault_handler()` — the exception entry stub plus the
   handler body.
2. Hook the exception vector from 105 to call this handler for
   data abort and prefetch abort exceptions.
3. The fault-context capture struct and helper.
4. The dispatch into 904.

## Related documents

- `docs/007-memory-model.md`.
- `notes/safety/000-bricking-and-recovery.md`.

## Blocked by

105, 901, 902.

## Blocks

904.
