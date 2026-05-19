---
name: Toolbox disassembly and patch infrastructure
phase: 10
status: pending
blockedBy: []
---

# 1001 — Toolbox disassembly and patch infrastructure

The infrastructure for modifying the Toolbox ROM where source-level
modifications cannot reach. Disassembler integration, patch format,
build pipeline, ROM-patch loading in GSplus.

## current behavior

The Toolbox ROM is unmodified — it's whatever Apple shipped. Some
behaviors we'd want to change live entirely in ROM (Window Manager
cross-screen geometry, certain QuickDraw rasterization details).
With no infrastructure, modifying these is impractical.

## intended behavior

- A disassembler integrated into the build: `da65` or a hand-rolled
  alternative that produces commented 65C816 assembly from the
  Toolbox ROM image.
- A documented patch format: `patches/NNN-name.tbox` files
  contain byte-level patches plus a hash of the original ROM to
  verify the patch applies cleanly.
- A build step that applies all `*.tbox` patches to a copy of the
  ROM image (the original is preserved as `assets/rom/iigs.rom`;
  patched copy is `tmp/build/iigs-patched.rom`).
- GSplus loads the patched ROM at boot if available; falls back to
  the original if not.
- A patch-management tool: `manage-rom-patch.sh` lets a developer
  apply / unapply patches for inspection.

## suggested implementation steps

1. Pick a disassembler. `da65` (from cc65) is the default. Verify
   it handles the 65C816's full instruction set and the IIds
   ROM's segment layout.
2. Document the disassembly process and the resulting file layout
   (one .s file per ROM bank, perhaps).
3. Define the `.tbox` patch format. Candidate: an extended unified-
   diff-like format that operates on byte ranges with an
   ABSOLUTE-ADDRESS header, plus a SHA256 of the original ROM the
   patch applies to.
4. Implement the patch applier in Lua (`src/build/rom-patcher.lua`).
5. Update `build.sh` to run the patcher.
6. Update GSplus's ROM-loading path to prefer the patched ROM.
7. Write a tiny test patch: change a single byte in a known ROM
   location (e.g., a string we won't miss); verify it applies,
   GSplus loads it, the change is visible.

## related documents

- `docs/005-patch-conventions.md` — the patch convention this
  extends
- `docs/001-architecture-overview.md` — modification surfaces

## known design questions

- Patch chaining: when multiple `.tbox` patches modify the same
  ROM bank, they must apply in numbered order without conflict.
  The applier checks for byte-level overlap and errors out if
  conflicts exist.
- ROM version handling: if Apple released multiple ROM versions
  (ROM 01, ROM 03), each `.tbox` patch declares which ROM
  version(s) it applies to. The applier picks the right patches.

## notes

- This is the infrastructure work, not the patches themselves
  (issue 1002). Setting it up cleanly here means patches in
  issue 1002 and beyond are reliable.
