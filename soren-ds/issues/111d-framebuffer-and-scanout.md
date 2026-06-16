# 111d — Framebuffer allocation and scan-out

## Current behavior

After 111c, both panels are initialized and waiting for pixel
data. After 111a/b the VOP2 controller and DSI lanes are alive.
What is missing is the actual pixel data: there are no
framebuffers allocated, and the VOP2 video output paths are not
yet configured to scan out from any specific memory region.
The panels are receiving DSI video-mode timing but no real
pixels.

## Intended behavior

Two framebuffers exist in DRAM, each sized for the panel they
back (640×480, 32 bits per pixel — about 1.2 MB per
framebuffer). Both come from the page allocator's multi-page
contiguous allocation interface (which this issue may need to
add — alloc_pages of N pages — since 108 only delivers single
pages). The VOP2's two video output ports are configured to
scan out from these framebuffers continuously, at the panel's
refresh rate.

Concretely:

- The page allocator gains a multi-page contiguous allocation
  helper. The simplest implementation is to scan the bitmap for
  a run of N consecutive zero bits. The kernel does not yet
  need an efficient version; the framebuffer allocations happen
  once per boot.
- Two framebuffer regions are allocated and zeroed. The
  bottom panel's framebuffer for VOP2's VP0, the top panel's
  for VP1.
- The VOP2 controller is configured with the framebuffer
  physical addresses, the pixel format (XRGB8888 or
  whatever the panel expects), the stride, and the scan-out
  dimensions.
- The VOP2 output paths are enabled. From this moment forward
  both panels are scanning bytes from their framebuffers and
  any write to a framebuffer pixel becomes visible at the next
  panel refresh.
- Bring-up status flows through the CDC-ACM debug stream.

After this issue closes both panels are actively displaying
the contents of their framebuffers — initially all zeros
(black) because the allocator zeroes new pages. 112 makes a
single pixel visible by writing a non-zero color value into a
specific framebuffer location.

## Suggested implementation steps

1. Extend `src/008-allocator.c` with `alloc_pages(uint32_t n)` —
   scan the bitmap for a contiguous run of N free pages, mark
   them all used, return the physical address of the first.
   Add a matching `free_pages(addr, n)`.
2. Allocate both framebuffers, zeroed. Note their physical
   addresses for the VOP2 configuration.
3. From upstream Linux's `drivers/gpu/drm/rockchip/rockchip_drm_vop2.c`,
   pull the VOP2 register layout for video output port
   configuration: framebuffer base addresses, pixel format,
   stride, output dimensions, output path enable bits.
4. Configure VP0 for the bottom panel and VP1 for the top.
5. Enable both output paths and confirm through a status read-
   back register that scan-out is active.
6. Narrate progress through CDC-ACM.

## Related documents

- `docs/005-display-and-compositor.md` — phase 6 owns the
  framebuffers this issue produces; this is the bring-up that
  hands them off.

## Blocked by

111a, 111b, 111c, 108.

## Blocks

112, 113.

## Parent

111.
