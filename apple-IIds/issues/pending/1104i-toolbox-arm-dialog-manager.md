---
name: Toolbox in ARM — Dialog Manager
phase: 11
status: pending
blockedBy: [1104f, 1104g, 1104h]
parent: 1104
---

# 1104i — Toolbox in ARM: Dialog Manager

ARM-assembly port of the IIds Dialog Manager. Manages modal and
modeless dialogs, alert templates, and the standard alert types.

## current behavior

The Dialog Manager runs in emulation.

## intended behavior

- Native ARM implementation of: `NewModalDialog`,
  `NewModelessDialog`, `DisposeDialog`, `ModalDialog`,
  `IsDialogEvent`, `DialogSelect`, `DrawDialog`, plus the alert
  routines (`Alert`, `StopAlert`, `NoteAlert`, `CautionAlert`).
- Dialog-record data structures preserved byte-for-byte.
- Integrates with Window Manager (1104f), Control Manager (1104h),
  and Menu Manager (1104g) — the Dialog Manager sits atop them.

## suggested implementation steps

1. Study GS/OS Dialog Manager source.
2. Port dialog allocation and disposal.
3. Port `ModalDialog` (the modal event loop).
4. Port the alert routines.
5. Port dialog item dispatch (each item type goes to its CDEF or
   custom drawing).
6. Test: dialogs from the curated app library.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- Window / Control / Menu Manager sub-issues — dependencies

## notes

- Dialogs are common — every "Open file" picker, every error
  alert. After this port, dialogs feel snappy.
