---
name: phase 12 demo
phase: 12
status: pending
blockedBy: [1201, 1202, 1203, 1204]
---

# 1220 — phase 12 demo

The deliverable that closes phase 12 — and the deliverable that
closes the entire current roadmap. Demonstrates an Apple IIds
device that develops its own software, on its own metal, in its
own assembly language. **The destination is reached.**

## current behavior

No phase 12 demo exists.

## intended behavior

- A script `issues/completed/demos/phase-12/run.sh` builds the
  bare-metal image with the editor, toolchain, debugger, and the
  sample project pre-loaded.
- The phase 12 demo:
  - Power on. Both screens up, GS/OS Finder visible.
  - Open the soramech editor on screen A. Code visible.
  - Open the debugger on screen B (as a coordinated pair with
    the editor).
  - User edits code, saves, assembles, links, runs — entirely
    on-device. The audience sees the device performing its own
    development.
  - The sample project (issue 1204) runs. It's a real, fun
    program.
- The status strip shows "Self-hosting" mode and tracks: number
  of source files, total lines of code on the device, last build
  duration, current debug session state.

## suggested implementation steps

1. Confirm phase 12 issues 1201–1204 are completed and moved to
   `issues/completed/`.
2. Pre-load the editor, toolchain, debugger, and sample project.
3. Pre-record a "build a small program from scratch" sequence to
   include in the demo.
4. Capture the demo recording with narration.
5. Update `issues/phase-12-progress.md`.

## related documents

- All of phase 12 (1201–1204)
- `issues/1120-phase-11-demo.md` — the prior demo (bare metal)
- `notes/vision/000-vision.md` — the destination

## notes

- This is the closing demo of the project's currently-charted
  arc. After phase 12, the project is "done" in the sense that
  the destination from the vision is reached. New work (phase 13+
  applications, future hardware ports, ecosystem development)
  continues but is no longer roadmap work — it's regular
  ongoing development.
- The narration on this demo's recording should be reflective —
  this is the close of years of work. Worth telling the story:
  Mac Plus → IIgs → Apple IIds → bare metal → self-hosting.
