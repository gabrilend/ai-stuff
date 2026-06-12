# 904 — App fault recovery

## Current behavior

The MMU fault handler (903) captures the fault context but
nothing yet cleanly kills the offending app or reports the
fault to the user. The current escalation path goes straight to
the panic stub, which halts the device — exactly the failure
mode this phase is designed to avoid.

## Intended behavior

The recovery path receives the fault context from 903 and
performs an orderly app teardown:

1. Mark the app's per-app work queue (905) as asleep so no
   further tasks fire for it.
2. Free the app's memory region (902) back to the kernel.
3. Reset the app's page table entries to kernel-only via 901.
4. Emit a `app-faulted` event into the transcript ring (310)
   carrying the faulting program counter, the faulting
   address, the box name that was running, and a short reason
   string.
5. If the app was a screen's foreground, swap the screen back
   to the last known healthy foreground. If no such foreground
   exists, fall back to the first-boot default (editor on
   bottom, messenger on top).
6. If the user is on the affected screen, show a small banner
   in place of the app's surface: "[App name] stopped. Open the
   programming environment to debug." The banner stays until
   the user dismisses it or follows a link out.
7. Hand the fault context (with line numbers and a stack-like
   trace synthesized from the transcript ring's recent fires)
   to the programming environment so a follow-up debug session
   has somewhere to start.

The kernel keeps running. The other apps keep running. The MMU
re-enable (already done) holds. The user notices that one app
died and can take action.

## Suggested implementation steps

1. `app_fault_recovery(fault_context)` — the orderly teardown.
2. The banner-replacement rendering — a small system-owned
   surface.
3. The transcript-to-trace synthesis.
4. The hand-off shape into the programming environment's
   `entries.json`.

## Related documents

- `docs/007-memory-model.md`.
- `docs/008-apps-overview.md`.

## Blocked by

604, 605, 903, 904 — i.e. 902, 904 (the recovery uses queue
sleep from 905).

## Blocks

910.
