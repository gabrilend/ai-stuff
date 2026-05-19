---
name: phase 1 demo
phase: 1
status: pending
blockedBy: [101, 102, 103, 104, 105, 106]
---

# 120 — phase 1 demo

The deliverable that closes phase 1. Demonstrates every piece of phase 1
in combination, ideally as a thing you can watch.

## current behavior

No demo exists. Phase 1 has no closing artifact.

## intended behavior

- A script `issues/completed/demos/phase-1/run.sh` lives under the
  project.
- The top-level `run-demo.sh` (also created in this issue) accepts a
  phase number from the user and launches the matching demo. For phase
  1 it launches `phase-1/run.sh`.
- The phase 1 demo:
  - Boots the RG DS into the broker.
  - Shows screen A running GS/OS to the Finder.
  - Permits the user to mouse around with touch and stylus.
  - Permits the user to insert a second disk image and open something
    off it. Recommended pick: **Cogito**, **Task Force**, or one of the
    canonical IIgs demos — pick something whose Super Hi-Res output is
    visually striking, so the color story sells itself.
  - Boots from a **GS/OS image we built ourselves from Apple's source
    release** (the deliverable of issue 106), not a stock disk image —
    proving the OS-level modification surface works end-to-end.
  - Displays a small overlay on the bottom panel reporting datapoints:
    - emulator frame rate
    - host CPU usage
    - free memory
    - currently mounted disk images
    - which GS/OS version (and a marker confirming "built from source")
- A short README in the demo directory explains what the viewer is
  seeing and which phase-1 issues each visible feature corresponds to.

## suggested implementation steps

1. Confirm all phase 1 issues (101–106) are completed and their issue
   files moved to `issues/completed/`.
2. Write the demo script. It must launch the actual build artifact, not
   a special "demo mode" — the demo is the product on its first day.
3. Write the statistics overlay. Reads `/proc/meminfo`, `/proc/stat`,
   the broker's own frame timer, and the GSplus instance's exposed
   counters. Renders to the bottom panel.
4. Capture a screen-recording of the demo for the eventual documentation
   site at `docs/HTML/`.
5. Update `issues/phase-1-progress.md` to mark phase 1 complete and link
   to the demo.
6. Update `docs/000-table-of-contents.md` to reference the demo.

## related documents

- All of phase 1 (101–106)
- global convention: "phase demos are part of the deliverable product"
- `docs/004-roadmap.md`

## notes

- The demo is updated as the project advances; later phases' demos will
  invoke phase 1's functionality and extend it. The demo for phase N is
  not frozen at the moment phase N completes — it evolves as a living
  showcase.
- Booting from a self-built GS/OS image (issue 106) is what makes this
  demo more than "we got an emulator running." It proves the full
  modification stack works.
