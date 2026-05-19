---
name: phase 9 demo
phase: 9
status: pending (pending soramech)
blockedBy: [901, 902, 903, 904, 905, 906, 907]
---

# 920 — phase 9 demo *(pending soramech)*

The deliverable that closes phase 9. Demonstrates preemptive
multithreading inside GS/OS by exhibiting concurrent execution that
was impossible before.

## current behavior

No phase 9 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-9/run.sh` extends the
  phase 8 demo.
- The phase 9 demo demonstrates:
  - **Concurrent UI:** Open the Finder and run a long computation
    in a worker task (e.g., compute the first 10000 primes,
    rendering progress to a window). The Finder remains
    responsive: you can move windows, open menus, and interact
    normally while the computation runs in the background.
  - **Two foreground apps actually run simultaneously:** Music
    playing in one window, a paint program drawing in another;
    no audio dropouts, no drawing stutter.
  - **Cross-task channels:** A producer task generates data, a
    consumer task displays it. Side-by-side timing of items
    produced and consumed.
  - **Legacy compatibility:** All the apps from the curated
    library still work normally under preemption.
- The status strip shows: number of active tasks per instance,
  scheduler tick rate, channel send/recv rates.

## suggested implementation steps

1. Confirm phase 9 issues 901–907 are completed and moved to
   `issues/completed/`.
2. Write the concurrent-UI sample program (the prime computation
   with progress).
3. Build the cross-task channel demo.
4. Verify the curated app library against the preemptive system.
5. Capture screen recording.
6. Update `issues/phase-9-progress.md`.

## related documents

- All of phase 9 (901–907)
- `docs/004-roadmap.md` — phase 9 entry

## notes

- After phase 9, GS/OS is *modern*. The original 1986 OS only ever
  did one thing at a time; the modernized version does many. This
  is one of the project's identity-defining demos.
- Pending soramech: this demo is months/years away depending on
  soramech's release schedule. Plan accordingly.
