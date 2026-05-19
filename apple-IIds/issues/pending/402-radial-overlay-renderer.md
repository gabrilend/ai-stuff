---
name: radial overlay renderer (on the inactive screen)
phase: 4
status: pending
blockedBy: [401]
---

# 402 — radial overlay renderer

The visual radial menu that appears when the user tilts the left
stick. Drawn by the broker on the **inactive** screen — the one not
currently receiving input — so the user can see the guide without
obscuring the screen they're typing into.

## current behavior

No overlay exists. The radial keyboard, if any, has no visual.

## intended behavior

- The overlay is a circular menu drawn as a compositor layer on top
  of whichever screen is currently inactive.
- It shows: N wedges around a center, each wedge labeled with the
  characters it contains. The currently-selected wedge (from the
  left stick) is highlighted; once the right stick (or stylus, in
  one-handed mode — issue 409) enters or hovers a wedge, that
  specific cell is further highlighted.
- The overlay does NOT touch the underlying GS/OS framebuffer. It is
  drawn by the broker as a separate layer on top of the panel.
- Fade-in over ~50 ms when the left stick exits dead zone.
- Fade-out over ~150 ms on left-stick return-to-dead-zone.
- The overlay re-renders on every frame the left stick is active to
  update highlights.
- Visual style: high-contrast, semi-transparent backdrop so
  underlying content shows through. Specific aesthetic TBD (see
  notes).

## suggested implementation steps

1. Decide which screen receives the overlay each frame: read the
   broker's "active screen" state (the inverse of last-input target;
   see issue 403). The inactive screen gets the overlay.
2. Implement the overlay compositor: write directly to the inactive
   panel's framebuffer (or DRM overlay plane if available), on top
   of whatever GSplus drew there. This requires GSplus's output to
   be readable so we can alpha-blend, or use a separate hardware
   plane.
3. Build the wedge geometry from issue 401's per-stick quantization
   settings.
4. Render the labels: each cell shows its character(s) in a bitmap
   font.
5. Animate the fade in/out.
6. Test on hardware: tilt the left stick, see the overlay appear on
   the screen you're *not* looking at.

## related documents

- `docs/003-input-system.md` — the overlay rule (inactive screen) and
  the grid layout
- `issues/401-stick-quantization.md` — provides the wedge geometry
- `issues/403-last-input-target.md` — provides the "active screen"
  signal

## known design questions

- Hardware overlay plane vs framebuffer blit? Hardware overlay is
  much faster and doesn't disturb GSplus's framebuffer at all. Check
  whether the RK3568 DRM stack exposes overlay planes; if so, use
  them. Otherwise blit.
- Visual style — defer to an assets issue. For phase 4 the placeholder
  is utilitarian: dark backdrop, light wedge borders, the active
  wedge filled. Refine in phase 5 (settings UI) or phase 8 (deeper
  GS/OS integration).
- What if both screens just took input simultaneously and there's no
  clear "inactive" screen? See issue 403 for the tie-break rule.
