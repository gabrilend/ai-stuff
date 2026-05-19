---
name: Apple //gs Toolbox in ARM assembly (multi-year subproject)
phase: 11
status: pending
blockedBy: [1103]
---

# 1104 — Apple //gs Toolbox in ARM assembly

Port the entire Apple //gs Toolbox from 65C816 assembly (and ROM
binary, where source isn't available) to ARM assembly. **This is
the multi-year subproject** that gives bare-metal Apple IIds its
identity.

## current behavior

The Toolbox runs in emulation. Phase 6 ported some subsystems
natively as C-on-soramech; phase 9's reentrancy work made the
emulated Toolbox concurrent-safe. Phase 11 is the *bare-metal*
port — everything in ARM assembly with no C, no soramech-as-Linux-
library, just the native machine.

## intended behavior

- Every Toolbox manager has an ARM-assembly implementation.
  Managers: Window, Menu, Control, Event, Dialog, Memory, Resource,
  Print, QuickDraw II, Sound, Standard File, ListMgr, Scrap,
  Process, Loader, ...
- API surface is preserved exactly — IIds applications don't know
  the underlying implementation has changed (other than running
  faster).
- The Toolbox is the largest single component of the ported
  system. This issue describes the work in aggregate; the actual
  implementation lives in dozens of sub-issues (1104a, 1104b, ...,
  one per manager).
- Each manager's port:
  - is a faithful reimplementation of the API
  - uses the threading primitives from issue 1105
  - uses the HAL from issue 1102 for hardware interaction
  - replaces (not coexists with) the emulated version once
    complete

## suggested implementation steps

This issue's "implementation steps" is really a meta-plan because
the work is too large for any single issue:

1. After issue 1103 establishes the porting template, split this
   issue into per-manager sub-issues:
   - 1104a — Memory Manager
   - 1104b — Resource Manager
   - 1104c — Event Manager
   - 1104d — Window Manager
   - ... etc., one per manager
2. Prioritize by dependency: Memory Manager first (everything
   depends on it), then Resource Manager, then Event Manager,
   then the UI managers (Window, Menu, Control, Dialog), then the
   bigger ones (QuickDraw II, Sound, Print).
3. For each manager: port, test against the curated app library,
   integrate, move on.
4. Maintain a running progress document
   `docs/research/toolbox-port-progress.md` that tracks which
   managers are done.

## related documents

- `issues/1103-first-module-ported.md` — the proof of concept
- `issues/1105-threading-primitives-arm.md` — the threading layer
  this depends on
- `issues/604-quickdraw-ii-native.md` — the staging-ground native
  QuickDraw, which informs the ARM port

## known design questions

- ARM assembly for everything, or is C acceptable for some
  managers? **Pending soramech**'s guidance and gabrilend's
  preference: stick to assembly for the system. C is acceptable
  for application code that runs on top, but the OS itself is
  assembly.
- How exact does the port need to be? Pixel-exact and behavior-
  exact for graphics, byte-exact for file ops, exact-enough-to-
  not-break-software-mostly elsewhere. Specifically a comprehensive
  regression suite per manager.

## sub-issues

Split by Toolbox manager, in dependency order (foundational
managers first; UI managers depend on them; integration managers
depend on UI):

- `1104a-toolbox-arm-memory-manager.md` — heap, handles, pointers
- `1104b-toolbox-arm-resource-manager.md` — resource forks
- `1104c-toolbox-arm-loader.md` — OMF executable loading
- `1104d-toolbox-arm-event-manager.md` — event queue and dispatch
- `1104e-toolbox-arm-quickdraw-ii.md` — graphics (largest single
  sub-issue; itself may further split internally)
- `1104f-toolbox-arm-window-manager.md` — windows
- `1104g-toolbox-arm-menu-manager.md` — menu bars and items
- `1104h-toolbox-arm-control-manager.md` — buttons, scroll bars
- `1104i-toolbox-arm-dialog-manager.md` — modal / modeless dialogs
- `1104j-toolbox-arm-standard-file.md` — Open / Save dialogs
- `1104k-toolbox-arm-sound-manager.md` — sound + Ensoniq sim
- `1104l-toolbox-arm-scrap-manager.md` — clipboard
- `1104m-toolbox-arm-process-manager.md` — app launch / switch
- `1104n-toolbox-arm-print-manager.md` — print to virtual printer

This issue (1104) remains as the umbrella; the sub-issues are the
actual work units. Each may further split internally as
implementation reveals natural seams.

## notes

- Multi-year. Estimate: 18–36 months of focused work across all 14
  sub-issues, depending on team size (likely just gabrilend + me).
- This is the issue cluster where the project's identity locks in.
  After all 14 land, Apple IIds is a real OS, not a port project.
