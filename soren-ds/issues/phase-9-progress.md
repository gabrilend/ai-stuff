# Phase 9 progress — Memory protection and background lifecycle

Phase 9 closes the launch system. By the end of the phase, the
MMU is configured in protection-only mode so a buggy app cannot
scribble over the kernel or its neighbors; the per-app work
queues described in the background-app lifecycle doc carry tasks
on a per-app basis; the always-on-input-box suppression bit is
flipped on background and cleared on foreground; the asleep
state is reachable through an explicit user close; and the
capstone demo proves the whole story by editing a fifth app
on-device, watching it crash, repairing it, and watching it run
again while the other four apps keep running undisturbed.

This is the phase that makes Soren DS a platform rather than a
product. Before this phase, the user's app code shares an address
space with the kernel with nothing between them; after this
phase, the kernel survives buggy user code and the user can
recover from their mistakes in place.

## The story of the phase

1. `901-mmu-protection-mode.md` — turn the MMU on, configure it
   for protection only (no translation), define the page table
   shape.
2. `902-per-app-memory-region.md` — assign each app a region;
   teach the page allocator to allocate from the right region
   per app.
3. `903-mmu-fault-handler.md` — trap on a bad access, capture
   the faulting program counter and the offending address,
   dispatch to the recovery path.
4. `904-app-fault-recovery.md` — kill the misbehaving app
   cleanly, free its resources, report the fault to the user
   through the on-device transcript.
5. `905-per-app-work-queue.md` — split the global work queue
   from 204 into per-app queues; the round-robin draining
   pattern from `013`.
6. `906-always-on-input-suppression.md` — the one-bit
   suppression that turns foreground/background into a tag
   check rather than a state machine.
7. `907-background-state-transitions.md` — the foreground →
   background → asleep transitions and what triggers each.
8. `908-asleep-and-wake-signals.md` — what asleep means; how
   an inter-app link, an rmail receive, or a timer fires wakes
   an asleep app.
9. `909-explicit-app-close.md` — the drawer option that closes
   an app entirely, freeing its RAM.
10. `910-phase-9-demo-the-capstone.md` — the demo. A fifth app
    written on-device, crashes, gets fixed, runs again — while
    the four launch apps keep running in the background.

## Completed issues

None yet.

## Open issues

All of 901 through 910.

## Phase demo

`issues/completed/demos/phase-9/run.sh` will exist once the
phase closes. The script orchestrates the capstone: starts the
device with the four launch apps loaded as background, prompts
the user to author a fifth app in the on-device editor, runs it
through the programming environment, watches it crash, walks
the user through the on-device repair, watches it run cleanly
the second time. The script verifies that the four launch apps
report continuous heartbeat events through the transcript ring
throughout — none of them died or rebooted during the
demonstrate-and-fix loop.
