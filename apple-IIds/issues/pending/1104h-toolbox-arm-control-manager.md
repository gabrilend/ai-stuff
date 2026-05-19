---
name: Toolbox in ARM — Control Manager
phase: 11
status: pending
blockedBy: [1104e, 1104f]
parent: 1104
---

# 1104h — Toolbox in ARM: Control Manager

ARM-assembly port of the IIds Control Manager. Manages buttons,
scroll bars, checkboxes, radio buttons, and other interactive
controls in windows.

## current behavior

The Control Manager runs in emulation.

## intended behavior

- Native ARM implementation of: `NewControl`, `DisposeControl`,
  `SetControlValue`, `GetControlValue`, `SetControlRange`,
  `HiliteControl`, `TrackControl`, `FindControl`, plus the
  control definition functions (CDEFs) for each standard control
  type.
- Control-record data structures preserved byte-for-byte.
- CDEF dispatch — standard CDEFs ported natively; custom CDEFs in
  applications still get called via emulation if necessary.

## suggested implementation steps

1. Study GS/OS Control Manager source.
2. Port the control-record allocation.
3. Port the standard CDEFs: button, scroll bar, checkbox, radio
   button.
4. Port `TrackControl` (the click-and-drag loop for scroll bars).
5. Port `FindControl`.
6. Test: scroll bars in the Finder, buttons in dialogs.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104e-toolbox-arm-quickdraw-ii.md`,
  `issues/1104f-toolbox-arm-window-manager.md` — dependencies

## notes

- Custom CDEFs in third-party software are 65C816 code. The
  port has to interoperate with emulated CDEFs cleanly (the
  emulator runs them; the Control Manager calls them through the
  emulation boundary).
