---
name: preemptive task switching in Event Manager
phase: 9
status: pending (pending soramech)
blockedBy: [901, 905, 906]
---

# 907 — preemptive task switching in Event Manager *(pending soramech)*

The Event Manager — historically the cooperative scheduler of GS/OS
— now coexists with the preemptive scheduler from issue 901.
Cooperative IIds programs continue to work; preemption acts at the
scheduler tick.

## current behavior

GS/OS programs call `GetNextEvent` / `WaitNextEvent` to yield. The
Event Manager dispatches events to the current foreground
application. There is no preemption between calls.

## intended behavior

- Multiple tasks can be runnable simultaneously. The scheduler
  (issue 901) switches between them on tick.
- The Event Manager remains the central event-dispatch service. It
  serves multiple tasks: each task can have its own event mask
  and event queue (or share a single queue, with events tagged by
  task).
- Legacy single-threaded apps continue to work — they call
  `GetNextEvent` from their main task and never spawn additional
  tasks. They behave exactly as on stock GS/OS.
- Modern multithreaded apps can call `task_create` to spawn
  workers. Workers don't need to call the Event Manager (it's for
  UI tasks). Workers communicate with the UI task via channels
  (issue 903).
- Preemption: a long-running app no longer freezes the system. The
  Finder remains responsive even if a worker task is computing.

## suggested implementation steps

1. Wait for issues 901, 905, 906 (the prerequisites are big).
2. Patch the Event Manager: each `GetNextEvent` call may now
   return events for the calling task only. Per-task event masks.
3. Wire the scheduler tick to occur at a natural Event Manager
   safe-point (e.g., at the end of each event dispatch).
4. Test: launch a long-running computation app and the Finder
   simultaneously; verify the Finder stays responsive.

## related documents

- All of phase 9 predecessors

## notes

- This is the moment GS/OS becomes a real preemptive OS. After
  this, the user experience of "I clicked something and the whole
  system froze" is gone.
- Verify all the curated app library still works under
  preemption.
