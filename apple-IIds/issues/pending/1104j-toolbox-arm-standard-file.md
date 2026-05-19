---
name: Toolbox in ARM — Standard File
phase: 11
status: pending
blockedBy: [1104i]
parent: 1104
---

# 1104j — Toolbox in ARM: Standard File

ARM-assembly port of the IIds Standard File package. The "Open
File" and "Save File" dialog mechanisms that most IIds applications
use for file selection.

## current behavior

Standard File runs in emulation.

## intended behavior

- Native ARM implementation of: `SFGetFile`, `SFPutFile`,
  `SFPGetFile`, `SFPPutFile`, plus the file-type filter mechanism
  and the navigation through directories.
- Dialog appearance matches GS/OS standard.
- Integrates with the File Manager (via the broker filesystem
  device 703, or its bare-metal successor) for actual file
  enumeration.

## suggested implementation steps

1. Study GS/OS Standard File source.
2. Port the dialog construction (uses Dialog Manager 1104i).
3. Port the file-list construction (uses File Manager).
4. Port the navigation (enter directories, parent directory).
5. Port the filter mechanism.
6. Test: every "Open" and "Save" dialog in the curated apps.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104i-toolbox-arm-dialog-manager.md` — dependency

## notes

- Standard File is one of the few Toolbox managers that's
  partially in ROM. The dialog templates are ROM resources. The
  port can read these from the emulated-ROM-bytes for the
  template definitions, then drive the dialog natively.
