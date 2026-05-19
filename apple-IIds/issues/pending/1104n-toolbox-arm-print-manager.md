---
name: Toolbox in ARM — Print Manager
phase: 11
status: pending
blockedBy: [1104e, 1104i]
parent: 1104
---

# 1104n — Toolbox in ARM: Print Manager

ARM-assembly port of the IIds Print Manager. Manages printer
selection, page setup, and printing — though "printing" on the
RG DS is more conceptual than physical.

## current behavior

The Print Manager runs in emulation. Without a physical printer,
its outputs go to a virtual "printer" device the broker provides
(likely a print-to-PDF or print-to-file equivalent).

## intended behavior

- Native ARM implementation of the Print Manager API: `PrOpen`,
  `PrClose`, `PrintDefault`, `PrStlDialog`, `PrJobDialog`,
  `PrOpenDoc`, `PrCloseDoc`, `PrOpenPage`, `PrClosePage`.
- Output goes to a virtual printer driver. The default driver
  saves a PDF (or platform-equivalent format) to the shared
  volume. The user can transfer the file off-device later.
- Page setup and print dialogs use the Dialog Manager (1104i).

## suggested implementation steps

1. Study GS/OS Print Manager source. Skip the parts specific to
   IIds printer hardware (we have none).
2. Port the API surface.
3. Implement a "save as PDF" or "save as PostScript" virtual
   printer driver that captures QuickDraw output into a file
   format readable on modern systems.
4. Port the page setup / job dialogs.
5. Test: a paint program "Print" → resulting file on the shared
   volume.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104e-toolbox-arm-quickdraw-ii.md`,
  `issues/1104i-toolbox-arm-dialog-manager.md` — dependencies

## notes

- Lowest priority of the Toolbox sub-ports. The "printer" concept
  is anachronistic on a handheld; this is here mostly for IIds
  software compatibility.
