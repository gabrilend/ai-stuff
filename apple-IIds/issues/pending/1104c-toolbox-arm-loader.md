---
name: Toolbox in ARM — Loader
phase: 11
status: pending
blockedBy: [1104a, 1104b]
parent: 1104
---

# 1104c — Toolbox in ARM: Loader

ARM-assembly port of the IIds Loader. Loads and unloads OMF
(Object Module Format) executables from disk into memory.

## current behavior

The Loader runs in 65C816 emulation.

## intended behavior

- Native ARM implementation of: `InitialLoad`, `Restart`,
  `LoadSegName`, `UnloadSegName`, segment loading and relocation,
  the OMF parser and the in-memory segment table.
- Preserves OMF semantics — IIds applications load and run
  unchanged.
- The Loader is what gives Apple IIds the ability to launch
  programs at all; without it, the device is a fixed
  ROM-like system.

## suggested implementation steps

1. Study GS/OS Loader source. Document the OMF format and
   relocation strategies.
2. Implement OMF parsing.
3. Implement segment allocation via the Memory Manager (1104a).
4. Implement relocation: fixing up segment references.
5. Implement segment unload.
6. Test: load several known IIds apps. Run them. Verify they
   behave identically to emulated execution.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104a-toolbox-arm-memory-manager.md`,
  `issues/1104b-toolbox-arm-resource-manager.md` — dependencies

## notes

- The Loader is what makes the device feel like an OS rather than
  a single-program runtime.
