---
name: self-hosting sample project
phase: 12
status: pending
blockedBy: [1201, 1202, 1203]
---

# 1204 — self-hosting sample project

A small program written **entirely on the device**: edited in the
soramech editor, assembled by the on-device toolchain, debugged
with the on-device debugger, run as a native Apple IIds
application. Proves the development loop works end to end.

## current behavior

The pieces exist (editor in 1201, toolchain in 1202, debugger in
1203) but their integration isn't validated against a real project.

## intended behavior

- A small but real program is written from scratch on the device.
  Suggestion: a small game or utility — something that exercises
  the Toolbox, the radial keyboard, the threading primitives, and
  the dual-screen architecture (as a coordinated pair).
- The development process is recorded as a tutorial:
  - Open the editor.
  - Create a new file.
  - Type code via the radial keyboard.
  - Save to the shared filesystem.
  - Assemble + link with the on-device toolchain.
  - Run the resulting binary.
  - Debug a deliberate bug; fix it.
  - Iterate.
- The recorded session becomes the canonical "you can develop on
  the device" demonstration.

## suggested implementation steps

1. Wait for issues 1201–1203.
2. Pick the sample project. Candidate: a coordinated-pair tic-tac-
   toe game (board on one screen, status / chat on the other).
3. Write it on the device. Record the process.
4. Document any friction. File follow-up issues for tooling
   improvements that the experience reveals.

## related documents

- `issues/1201-soramech-editor-port.md`,
  `issues/1202-on-device-assembly-toolchain.md`,
  `issues/1203-on-device-debugger.md` — the prerequisites
- `notes/vision/000-vision.md` — in-device programming

## known design questions

- How "real" should the sample be? Real enough to exercise every
  major tool path; small enough to be developed in a recordable
  session.
- Should the sample be released as one of the curated apps? Sure,
  if it's good. The library refresh tool (issue 502) can include
  it.

## notes

- This is the issue that *proves* phase 12 worked. Without the
  end-to-end exercise, the editor / toolchain / debugger are just
  hopeful infrastructure.
