---
name: single screen boot
phase: 1
status: pending
blockedBy: [102]
---

# 103 — single screen boot

A single GSplus instance boots to the GS/OS Finder on one of the two
RG DS screens.

## current behavior

GSplus compiles for the RG DS (issue 102) but has not been pointed at a
panel framebuffer or fed a ROM and a boot disk.

## intended behavior

- GSplus launches at device startup.
- Its framebuffer renders onto **screen A** (the top panel by convention).
- A real Apple IIgs ROM is loaded (sourced separately, not committed to
  git). Either ROM 01 (128 KB) or ROM 03 (256 KB) — ROM 03 is preferred
  if available; document which is in use.
- A GS/OS boot disk image is mounted and the IIgs boots to the Finder.
- Screen B is blank (or shows a placeholder image — perhaps the GS/OS
  startup splash, for vibes).

## suggested implementation steps

1. Identify the Linux framebuffer / DRM device(s) for the two panels on
   the RG DS. Document in `docs/002-hardware-target.md`.
2. Patch GSplus to write its framebuffer to the chosen `/dev/fb*` or
   DRM/KMS device rather than to SDL2 backed by X11. Apply via the
   `patches/` mechanism from issue 102. The IIgs Super Hi-Res output
   should land as 2× integer-scaled 640×400 inside the 640×480 panel,
   centered with 40 px letterbox above and below (see the hardware
   target doc for full scaling rules).
3. Place the IIgs ROM at `assets/rom/iigs.rom` (gitignored). Document
   where to obtain it in `assets/rom/SOURCE.md`.
4. Place a GS/OS boot image at `assets/disks/gsos-boot.2mg` (also
   gitignored). `.2mg` is the standard IIgs disk-image format; GSplus
   reads it natively.
5. Wire the broker to launch GSplus with the ROM and disk paths.
6. Verify on the device: device powers on, screen A shows the GS/OS
   Finder, the mouse pointer responds to nothing yet (touch handling
   lands in issue 104).

## related documents

- `docs/001-architecture-overview.md` — layer 3
- `docs/002-hardware-target.md` — panel mapping, scaling rules

## notes

- The IIgs has multiple video modes (40-column text, 80-column text,
  lo-res, hi-res, double hi-res, Super Hi-Res). The framebuffer patch
  must handle all of them, scaling 2× and centering each. See the
  hardware target doc.
- ROM 01 vs ROM 03: ROM 03 was the final IIgs Toolbox release and is
  generally what stock software targets. ROM 01 is more historically
  authentic for 1986. Use ROM 03 unless something software-specific
  forces otherwise.
