---
name: Toolbox in ARM — Resource Manager
phase: 11
status: pending
blockedBy: [1104a]
parent: 1104
---

# 1104b — Toolbox in ARM: Resource Manager

ARM-assembly port of the IIds Resource Manager. Provides
resource-fork access for files: icons, strings, dialog templates,
code segments, and the many other resource types.

## current behavior

The Resource Manager runs in 65C816 emulation or staging-ground
phase 6/9 state.

## intended behavior

- Native ARM implementation of: `OpenResourceFile`,
  `CloseResourceFile`, `GetResource`, `LoadResource`,
  `ReleaseResource`, `AddResource`, `RemoveResource`,
  `WriteResource`, `UpdateResFile`, plus resource map walking.
- Resource map data structure preserved byte-for-byte.
- Reads / writes the resource fork via the File Manager
  (1104j? — actually Standard File uses Resource Manager;
  Resource Manager talks to lower-level File Manager calls; ports
  carefully).

## suggested implementation steps

1. Study GS/OS Resource Manager source. Map the resource fork
   format and the in-memory resource map.
2. Implement resource-fork open / close.
3. Implement resource lookup and load.
4. Implement resource write / update.
5. Test: open an existing IIds app's resource fork, enumerate
   resources, load specific ones. Compare to emulated output.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104a-toolbox-arm-memory-manager.md` — dependency

## notes

- The Resource Manager is medium complexity. The resource fork
  format is well-documented; the in-memory map management is
  where the subtlety lives.
