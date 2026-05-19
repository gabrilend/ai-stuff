---
name: phase 10 demo
phase: 10
status: pending
blockedBy: [1001, 1002]
---

# 1020 — phase 10 demo

The deliverable that closes phase 10. Demonstrates a Toolbox ROM
modification working end-to-end.

## current behavior

No phase 10 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-10/run.sh` extends the
  phase 9 demo.
- The phase 10 demo:
  - Boots the device with the patched ROM.
  - Demonstrates the specific patches from issue 1002 — whatever
    they end up being.
  - The status strip indicates "ROM: patched (N patches applied)"
    so the viewer knows the difference.
- The demo also shows the disassembly tooling: from a developer
  terminal, run `disassemble-rom.sh` and produce the commented
  assembly of a specific routine.

## suggested implementation steps

1. Confirm phase 10 issues 1001–1002 are completed and moved to
   `issues/completed/`.
2. For each patch applied, document the before/after observable
   behavior in the demo's README.
3. Capture screen recording.
4. Update `issues/phase-10-progress.md`.

## related documents

- `issues/1001-toolbox-disassembly-infra.md`,
  `issues/1002-toolbox-rom-patches.md` — the prerequisites
- `docs/004-roadmap.md` — phase 10 entry

## notes

- This demo is intentionally modest. If we needed many ROM patches,
  we'd have done something wrong upstream. The success criterion
  for phase 10 is: the infrastructure works and the few patches
  needed are documented and applied cleanly.
